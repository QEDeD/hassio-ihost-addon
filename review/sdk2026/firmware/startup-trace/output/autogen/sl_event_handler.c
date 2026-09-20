extern void startup_trace_mark(unsigned char);
extern void startup_trace_cpc_ready(void);
#include "sl_event_handler.h"

#include "sl_clock_manager.h"
#include "sl_rail_util_dma.h"
#include "sl_rail_util_compatible_pa.h"
#include "sl_rail_util_pti.h"
#include "sl_rail_util_rf_path.h"
#include "sl_rail_util_rssi.h"
#include "btl_interface.h"
#include "platform-efr32.h"
#include "sl_dma_manager_instances.h"
#include "sl_cpc.h"
#include "sl_gpio.h"
#include "sl_mbedtls.h"
#include "crash_handler.h"
#include "sl_ot_init.h"
#include "psa/crypto.h"
#include "sl_se_manager.h"
#include "sli_protocol_crypto.h"
#include "nvm3_default.h"

void sli_driver_permanent_allocation(void)
{
}

void sli_service_permanent_allocation(void)
{
  sl_cpc_init_permanent_allocations();
}

void sli_stack_permanent_allocation(void)
{
}

void sli_internal_permanent_allocation(void)
{
}

void sl_platform_init(void)
{
  startup_trace_mark(0x01);
  sl_clock_manager_runtime_init();
  startup_trace_mark(0x02);
  startup_trace_mark(0x03);
  bootloader_init();
  startup_trace_mark(0x04);
  startup_trace_mark(0x05);
  sl_dma_manager_instances_init();
  startup_trace_mark(0x06);
  startup_trace_mark(0x07);
  nvm3_initDefault();
  startup_trace_mark(0x08);
}

void sli_internal_init_early(void)
{
  startup_trace_mark(0x09);
  sl_ot_crash_handler_init();
  startup_trace_mark(0x0A);
}

void sl_driver_init(void)
{
  startup_trace_mark(0x0B);
  sl_gpio_init();
  startup_trace_mark(0x0C);
}

void sl_service_init(void)
{
  startup_trace_mark(0x0D);
  sl_cpc_init();
  startup_trace_cpc_ready();
  startup_trace_mark(0x0E);
  startup_trace_mark(0x0F);
  sl_mbedtls_init();
  startup_trace_mark(0x10);
  startup_trace_mark(0x11);
  psa_crypto_init();
  startup_trace_mark(0x12);
  startup_trace_mark(0x13);
  sl_se_init();
  startup_trace_mark(0x14);
  startup_trace_mark(0x15);
  sli_protocol_crypto_init();
  startup_trace_mark(0x16);
  startup_trace_mark(0x17);
  sli_aes_seed_mask();
  startup_trace_mark(0x18);
}

void sl_stack_init(void)
{
  startup_trace_mark(0x19);
  sl_rail_util_dma_init();
  startup_trace_mark(0x1A);
  startup_trace_mark(0x1B);
  sl_rail_util_pa_init();
  startup_trace_mark(0x1C);
  startup_trace_mark(0x1D);
  sl_rail_util_pti_init();
  startup_trace_mark(0x1E);
  startup_trace_mark(0x1F);
  sl_rail_util_rf_path_init();
  startup_trace_mark(0x20);
  startup_trace_mark(0x21);
  sl_rail_util_rssi_init();
  startup_trace_mark(0x22);
  startup_trace_mark(0x23);
  sl_ot_sys_init();
  startup_trace_mark(0x24);
}

void sl_internal_app_init(void)
{
  startup_trace_mark(0x25);
  sl_ot_init();
  startup_trace_mark(0x26);
}

void sli_platform_process_action(void)
{
}

void sli_service_process_action(void)
{
  sl_cpc_process_action();
}

void sli_stack_process_action(void)
{
}

void sli_internal_app_process_action(void)
{
}

