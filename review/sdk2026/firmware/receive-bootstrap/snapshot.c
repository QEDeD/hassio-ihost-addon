/* Terminal diagnostic only. RAM metadata; no payload/stack reads or added persistence writes.
 * SysTick is dedicated to this image; normal CPC owns USART0 until takeover.
 */
#include <stdbool.h>
#include <stdint.h>
#include "em_device.h"
#include "em_cmu.h"
#include "sl_cpc.h"
#include "sli_cpc.h"
#include "sli_cpc_instance.h"
#include "snapshot.h"
#include "snapshot_fields.h"

#if SL_CPC_DEBUG_CORE_EVENT_COUNTERS != 1
#error "Terminal snapshot requires vendor CPC core counters"
#endif
#if DMA_CHAN_COUNT != 8
#error "This diagnostic was reviewed only for eight-channel EFR32MG21 LDMA"
#endif

#if !defined(_SILICON_LABS_32B_SERIES_2_CONFIG) || (_SILICON_LABS_32B_SERIES_2_CONFIG != 1)
#error "Reviewed bus-clock behavior is specific to Series2 config1 (MG21)"
#endif

#define BUILD_ID 0x52584231u
#define PERIODS 40u
#define POLL_LIMIT 100000u /* Bounded iterations, not calibrated time. */
#define ALL_DMA_CHANNELS ((1u << DMA_CHAN_COUNT) - 1u)
#define W(name) snapshot_words[POST_F_##name]

extern uint8_t read_channel;
extern uint8_t write_channel;
post_snapshot_live_t post_snapshot_live;
volatile uint32_t post_snapshot_fault;
static sli_cpc_instance_t *snapshot_instance;
static uint32_t snapshot_words[POST_WORD_COUNT];
static uint32_t core_hz_at_arm;
static uint32_t reload_at_arm;
static volatile uint32_t ticks;
static volatile bool armed;
static uint16_t output_crc;

_Static_assert(POST_WORD_COUNT <= 111u, "Wire record must remain below 1024 bytes");

static __attribute__((noreturn)) void halt_with_fault(uint32_t reason)
{
  post_snapshot_fault = reason;
  __disable_irq();
  SysTick->CTRL = 0u;
  for (;;) { __NOP(); }
}

static bool wait_uart(uint32_t mask)
{
  for (uint32_t n = 0; n < POLL_LIMIT; ++n) {
    if ((USART0->STATUS & mask) == mask) { return true; }
  }
  return false;
}

static void take_snapshot(void)
{
  /* Read masks before changing them. This snapshot is not simultaneous. */
  W(entry_basepri) = __get_BASEPRI();
  W(entry_primask) = __get_PRIMASK();
  W(entry_faultmask) = __get_FAULTMASK();
  __disable_irq();
  W(format_version) = 1u;
  W(build_id) = BUILD_ID;
  W(core_hz) = core_hz_at_arm;
  W(systick_reload) = reload_at_arm;
  W(delivered_ticks) = ticks;
  W(snapshot_valid) = 1u; /* CPU and software progress metadata present. */
  W(phase) = post_snapshot_live.phase;
  W(cpc_enter) = post_snapshot_live.cpc_enter;
  W(cpc_exit) = post_snapshot_live.cpc_exit;
  W(tasklets_done) = post_snapshot_live.tasklets_done;
  W(drivers_done) = post_snapshot_live.drivers_done;
  W(full_loop_done) = post_snapshot_live.full_loop_done;
  W(txc_enter) = post_snapshot_live.txc_enter;
  W(txc_exit) = post_snapshot_live.txc_exit;
  W(rx_callback_enter) = post_snapshot_live.rx_callback_enter;
  W(rx_callback_exit) = post_snapshot_live.rx_callback_exit;
  W(tx_ready) = post_snapshot_tx_ready(); /* Primitive local getter, no locking. */
  post_snapshot_receive_state(); /* Only fixed driver metadata; no pointer walks. */
  W(first_bad_seen) = post_snapshot_live.first_bad_seen;
  W(first_bad_header_length) = post_snapshot_live.first_bad_header_length;
  W(first_bad_driver_length) = post_snapshot_live.first_bad_driver_length;
  W(first_bad_fcs) = post_snapshot_live.first_bad_fcs;
  W(first_bad_crc) = post_snapshot_live.first_bad_crc;
  W(first_bad_control) = post_snapshot_live.first_bad_control;
  W(first_bad_uart_if) = post_snapshot_live.first_bad_uart_if;
  W(rx_header_callbacks) = post_snapshot_live.rx_header_callbacks;
  W(rx_payload_callbacks) = post_snapshot_live.rx_payload_callbacks;
  W(first_header_uart_if) = post_snapshot_live.first_header_uart_if;
  W(first_payload_uart_if) = post_snapshot_live.first_payload_uart_if;
  W(resize_calls) = post_snapshot_live.resize_calls;
  W(resize_ok) = post_snapshot_live.resize_ok;
  W(resize_already) = post_snapshot_live.resize_already;
  W(resize_fail) = post_snapshot_live.resize_fail;
  W(resize_last_requested) = post_snapshot_live.resize_last_requested;
  W(resize_last_received) = post_snapshot_live.resize_last_received;
  W(recovery_dispatches) = post_snapshot_live.recovery_dispatches;
  W(recovery_runs) = post_snapshot_live.recovery_runs;
  W(header_expected) = post_snapshot_live.header_expected;
  W(next_rx_size) = post_snapshot_live.next_rx_size;
  W(recovery_flags) = post_snapshot_live.recovery_flags;
  W(rx_link) = post_snapshot_live.rx_link;
  W(desc0_ctrl) = post_snapshot_live.desc0_ctrl;
  W(desc0_dst) = post_snapshot_live.desc0_dst;
  W(desc0_link) = post_snapshot_live.desc0_link;
  W(desc1_ctrl) = post_snapshot_live.desc1_ctrl;
  W(desc1_dst) = post_snapshot_live.desc1_dst;
  W(desc1_link) = post_snapshot_live.desc1_link;
  W(head_index) = post_snapshot_live.head_index;
  const volatile sl_cpc_core_debug_counters_t *c = &snapshot_instance->core_debug.core_counters;
  W(cpc_rxd_frame) = c->rxd_frame;
  W(cpc_rxd_valid_uframe) = c->rxd_valid_uframe;
  W(cpc_txd_completed) = c->txd_completed;
  W(cpc_driver_error) = c->driver_error;
  W(cpc_driver_packet_dropped) = c->driver_packet_dropped;
  W(cpc_invalid_header_checksum) = c->invalid_header_checksum;
  W(cpc_invalid_payload_checksum) = c->invalid_payload_checksum;
  W(snapshot_valid) |= 2u;

  W(scb_icsr) = SCB->ICSR;
  W(scb_shcsr) = SCB->SHCSR;
  W(scb_cfsr) = SCB->CFSR;
  W(scb_hfsr) = SCB->HFSR;
  W(nvic_iser0) = NVIC->ISER[0]; W(nvic_iser1) = NVIC->ISER[1];
  W(nvic_ispr0) = NVIC->ISPR[0]; W(nvic_ispr1) = NVIC->ISPR[1];
  W(nvic_iabr0) = NVIC->IABR[0]; W(nvic_iabr1) = NVIC->IABR[1];
  W(priority_uart_tx) = NVIC->IPR[USART0_TX_IRQn];
  W(priority_ldma) = NVIC->IPR[LDMA_IRQn];
  W(priority_rtcc) = NVIC->IPR[RTCC_IRQn];
  W(priority_systick) = SCB->SHPR[11];
  W(cmu_sysclkctrl) = CMU->SYSCLKCTRL;
  /* MG21 has no module bus-clock gates: vendor clock-manager HAL reports
   * enabled=true for all modules on Series2 config1. No CLKEN0 exists. */
  W(bus_clock_ungated) = 1u;
  W(snapshot_valid) |= 64u;

  { /* USART0 bus interface is ungated on this reviewed target. */
    W(usart_en) = USART0->EN; W(usart_status) = USART0->STATUS;
    W(usart_ien) = USART0->IEN; W(usart_if) = USART0->IF;
    W(usart_ctrl) = USART0->CTRL; W(usart_ctrlx) = USART0->CTRLX;
    W(usart_clkdiv) = USART0->CLKDIV;
    W(snapshot_valid) |= 4u;
  }
  { /* GPIO bus interface is ungated. */
    W(usart_routeen) = GPIO->USARTROUTE[0].ROUTEEN;
    W(usart_rxroute) = GPIO->USARTROUTE[0].RXROUTE;
    W(usart_txroute) = GPIO->USARTROUTE[0].TXROUTE;
    W(snapshot_valid) |= 8u;
  }
  W(read_channel) = read_channel; W(write_channel) = write_channel;
  { /* LDMA and LDMAXBAR bus interfaces are ungated. */
    W(ldma_en) = LDMA->EN; W(ldma_ctrl) = LDMA->CTRL;
    W(ldma_status) = LDMA->STATUS; W(ldma_ien) = LDMA->IEN;
    W(ldma_if) = LDMA->IF; W(ldma_chstatus) = LDMA->CHSTATUS;
    W(ldma_chbusy) = LDMA->CHBUSY; W(ldma_chdone) = LDMA->CHDONE;
    W(ldma_reqdis) = LDMA->REQDIS;
    W(snapshot_valid) |= 16u;
    if (read_channel < DMA_CHAN_COUNT && write_channel < DMA_CHAN_COUNT) {
      W(rx_channel_ctrl) = LDMA->CH[read_channel].CTRL;
      W(rx_request_select) = LDMAXBAR->CH[read_channel].REQSEL;
      W(rx_channel_dst) = LDMA->CH[read_channel].DST;
      W(tx_channel_ctrl) = LDMA->CH[write_channel].CTRL;
      W(tx_request_select) = LDMAXBAR->CH[write_channel].REQSEL;
      W(tx_channel_dst) = LDMA->CH[write_channel].DST;
      W(snapshot_valid) |= 32u;
    }
  }
}

static void terminal_takeover(void)
{
  /* Snapshot is already frozen. No return to CPC/radio after these writes. */
  SysTick->CTRL = 0u;
  armed = false;
  if ((W(snapshot_valid) & 16u) == 0u) { halt_with_fault(10u); }
  if ((W(snapshot_valid) & 4u) == 0u || !(W(usart_en) & USART_EN_EN)) {
    halt_with_fault(11u);
  }
  USART0->IEN = 0u;
  NVIC_DisableIRQ(USART0_TX_IRQn);
  NVIC_DisableIRQ(LDMA_IRQn);
  LDMA->IEN = 0u;
  /* Stop every channel because this application will never resume. */
  LDMA->REQDIS_SET = ALL_DMA_CHANNELS;
  LDMA->CHDIS_SET = ALL_DMA_CHANNELS;
  __DSB();
  bool idle = false;
  for (uint32_t n = 0; n < POLL_LIMIT; ++n) {
    if ((LDMA->CHBUSY & ALL_DMA_CHANNELS) == 0u
        && (LDMA->STATUS & LDMA_STATUS_ANYBUSY) == 0u) {
      idle = true; break;
    }
  }
  if (!idle) { halt_with_fault(12u); }
  W(takeover_status) = 1u;
  LDMA->EN_CLR = LDMA_EN_EN;
  __DSB();
  bool disabled = false;
  for (uint32_t n = 0; n < POLL_LIMIT; ++n) {
    if ((LDMA->EN & LDMA_EN_EN) == 0u) { disabled = true; break; }
  }
  if (!disabled) { halt_with_fault(13u); }
  W(takeover_status) |= 2u;
  USART0->CMD = USART_CMD_RXDIS;
  if (!wait_uart(USART_STATUS_TXC)) { halt_with_fault(14u); }
  W(takeover_status) |= 4u;
}

static void output_byte(uint8_t value, bool checksum)
{
  if (!wait_uart(USART_STATUS_TXBL)) { halt_with_fault(15u); }
  USART0->TXDATA = value;
  if (checksum) {
    output_crc ^= (uint16_t)value << 8;
    for (uint32_t bit = 0; bit < 8u; ++bit) {
      output_crc = (uint16_t)((output_crc & 0x8000u)
        ? ((uint32_t)output_crc << 1) ^ 0x1021u : (uint32_t)output_crc << 1);
    }
  }
}

static void output_hex(uint32_t value, uint32_t digits, bool checksum)
{
  static const char hex[] = "0123456789ABCDEF";
  for (uint32_t n = digits; n > 0u; --n) {
    output_byte((uint8_t)hex[(value >> ((n - 1u) * 4u)) & 15u], checksum);
  }
}

static __attribute__((noreturn)) void output_snapshot(void)
{
  static const char prefix[] = "@POST1:";
  output_byte('\r', false); output_byte('\n', false);
  output_crc = 0u;
  for (uint32_t n = 0; n < sizeof(prefix) - 1u; ++n) {
    output_byte((uint8_t)prefix[n], true);
  }
  output_hex(POST_WORD_COUNT, 4u, true);
  for (uint32_t n = 0; n < POST_WORD_COUNT; ++n) {
    output_byte(':', true); output_hex(snapshot_words[n], 8u, true);
  }
  uint16_t final_crc = output_crc;
  output_byte(':', false); output_hex(final_crc, 4u, false);
  output_byte('\r', false); output_byte('\n', false);
  if (!wait_uart(USART_STATUS_TXC)) { halt_with_fault(16u); }
  halt_with_fault(0u); /* Successful terminal dump; deliberately never resumes. */
}

void SysTick_Handler(void)
{
  if (!armed) { SysTick->CTRL = 0u; return; }
  ++ticks;
  if (ticks < PERIODS) { return; }
  take_snapshot();
  terminal_takeover();
  output_snapshot();
}

void post_snapshot_arm(void)
{
  /* Do not hijack a timer whose ownership differs from the reviewed image. */
  if ((SysTick->CTRL & (SysTick_CTRL_ENABLE_Msk | SysTick_CTRL_TICKINT_Msk)) != 0u) {
    post_snapshot_fault = 1u; return;
  }
  core_hz_at_arm = CMU_ClockFreqGet(cmuClock_CORE);
  uint32_t reload_ticks = core_hz_at_arm / 10u;
  if (reload_ticks == 0u || reload_ticks - 1u > SysTick_LOAD_RELOAD_Msk) {
    post_snapshot_fault = 2u; return;
  }
  snapshot_instance = sli_cpc_get_instance(SL_CPC_ENDPOINT_SYSTEM);
  if (snapshot_instance == 0) { post_snapshot_fault = 3u; return; }
  reload_at_arm = reload_ticks - 1u;
  uint32_t primask = __get_PRIMASK();
  __disable_irq();
  SysTick->CTRL = 0u;
  SCB->ICSR = SCB_ICSR_PENDSTCLR_Msk;
  /* Direct priority byte: avoid a library call/late default-priority rewrite. */
  SCB->SHPR[11] = 0u;
  SysTick->LOAD = reload_at_arm;
  SysTick->VAL = 0u;
  ticks = 0u;
  post_snapshot_live.phase = 0u;
  armed = true;
  __DSB(); __ISB();
  SysTick->CTRL = SysTick_CTRL_CLKSOURCE_Msk | SysTick_CTRL_TICKINT_Msk | SysTick_CTRL_ENABLE_Msk;
  __set_PRIMASK(primask);
}
