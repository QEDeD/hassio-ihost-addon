/* Diagnostic only: no payload/key output, no use after application startup.
 * UART setup follows Silicon Labs sl_cpc_drv_uart.c (Zlib licensed SDK).
 * This is local instrumentation, not vendor firmware or a production fix.
 */
#include <stdbool.h>
#include <stdint.h>
#include "em_device.h"
#include "sl_clock_manager.h"
#include "sl_device_peripheral.h"
#include "sl_gpio.h"
#include "sl_hal_gpio.h"
#include "sl_hal_usart.h"
#include "sl_hal_ldma.h"
#include "sl_cpc_drv_uart_config.h"

extern uint8_t write_channel; /* Exact SDK CPC driver; valid only after init. */
static bool trace_active;
static bool cpc_initialized;
volatile uint32_t startup_trace_fault;
#define TRACE_POLL_LIMIT 100000u /* Iterations, NOT a calibrated duration. */

static bool wait_status(uint32_t bit)
{
  for (uint32_t n = 0; n < TRACE_POLL_LIMIT; ++n) {
    if ((USART0->STATUS & bit) != 0) { return true; }
  }
  return false;
}

/* Never continue with an undrained raw transfer or fake CPC TX completion.
 * An instrumentation failure is a terminal diagnostic outcome, not evidence
 * of a vendor startup fault. No reset, erase or storage write is performed.
 */
static void trace_fail(uint32_t why)
{
  startup_trace_fault = why;
  trace_active = false;
  USART0->IEN_CLR = USART_IEN_TXC;
  NVIC_DisableIRQ(USART0_TX_IRQn);
  USART0->CMD = USART_CMD_TXDIS | USART_CMD_CLEARTX;
  for (;;) { __NOP(); }
}

void startup_trace_mark(uint8_t marker)
{
  if (!trace_active) { return; }
  uint32_t primask = __get_PRIMASK();
  __disable_irq();
  if (cpc_initialized && (write_channel >= DMA_CHAN_COUNT
      || sl_hal_ldma_channel_is_enabled(LDMA, write_channel)
      || sl_hal_ldma_channel_is_active(LDMA, write_channel))) {
    trace_fail(1);
  }
  /* An existing pending TX interrupt is not ours to consume. */
  if (NVIC_GetPendingIRQ(USART0_TX_IRQn)) { trace_fail(2); }
  uint32_t ien = USART0->IEN;
  USART0->IEN_CLR = USART_IEN_TXC;
  static const char hex[] = "0123456789ABCDEF";
  const char frame[] = {'\r', '\n', '@', 'S', hex[marker >> 4], hex[marker & 15], '\r', '\n'};
  for (unsigned n = 0; n < sizeof frame; ++n) {
    if (!wait_status(USART_STATUS_TXBL)) { trace_fail(3); }
    USART0->TXDATA = (uint8_t)frame[n];
  }
  if (!wait_status(USART_STATUS_TXC)) { trace_fail(4); }
  USART0->IF_CLR = USART_IF_TXC;
  NVIC_ClearPendingIRQ(USART0_TX_IRQn);
  USART0->IEN = ien;
  __set_PRIMASK(primask);
}

void startup_trace_cpc_ready(void) { cpc_initialized = true; }
void startup_trace_finish(void)
{
  startup_trace_mark(0xFF);
  trace_active = false; /* Permanent handoff before any process_action. */
}

void app_init_early(void)
{
  uint32_t hz;
  sl_hal_usart_async_init_t cfg = SL_HAL_USART_INIT_ASYNC_DEFAULT;
  if (sl_clock_manager_enable_bus_clock(SL_BUS_CLOCK_USART0) != SL_STATUS_OK
      || sl_clock_manager_enable_bus_clock(SL_BUS_CLOCK_GPIO) != SL_STATUS_OK) {
    /* No UART register access on a failed clock enable. */
    startup_trace_fault = 5;
    for (;;) { __NOP(); }
  }
  sl_clock_branch_t branch = sl_device_peripheral_get_clock_branch(SL_PERIPHERAL_USART0);
  if (sl_clock_manager_get_clock_branch_frequency(branch, &hz) != SL_STATUS_OK || !hz) {
    trace_fail(6);
  }
  cfg.hw_flow_control = SL_HAL_USART_HW_FLOW_CONTROL_NONE;
  cfg.clock_div = sl_hal_usart_async_calculate_clock_div(hz, 115200, cfg.oversampling);
  sl_hal_gpio_set_pin_mode(&(sl_gpio_t){ .port = SL_CPC_DRV_UART_TX_PORT,
    .pin = SL_CPC_DRV_UART_TX_PIN }, SL_GPIO_MODE_PUSH_PULL, true);
  sl_hal_usart_init_async(USART0, &cfg);
  GPIO->USARTROUTE[0].TXROUTE =
    (SL_CPC_DRV_UART_TX_PORT << _GPIO_USART_TXROUTE_PORT_SHIFT)
    | (SL_CPC_DRV_UART_TX_PIN << _GPIO_USART_TXROUTE_PIN_SHIFT);
  GPIO->USARTROUTE_SET[0].ROUTEEN = GPIO_USART_ROUTEEN_TXPEN;
  sl_hal_usart_enable(USART0);
  sl_hal_usart_enable_tx(USART0);
  trace_active = true;
  startup_trace_mark(0x00);
}
