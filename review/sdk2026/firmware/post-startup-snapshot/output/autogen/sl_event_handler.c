#include "snapshot.h"
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
  sl_clock_manager_runtime_init();
  bootloader_init();
  sl_dma_manager_instances_init();
  nvm3_initDefault();
}

void sli_internal_init_early(void)
{
  sl_ot_crash_handler_init();
}

void sl_driver_init(void)
{
  sl_gpio_init();
}

void sl_service_init(void)
{
  sl_cpc_init();
  sl_mbedtls_init();
  psa_crypto_init();
  sl_se_init();
  sli_protocol_crypto_init();
  sli_aes_seed_mask();
}

void sl_stack_init(void)
{
  sl_rail_util_dma_init();
  sl_rail_util_pa_init();
  sl_rail_util_pti_init();
  sl_rail_util_rf_path_init();
  sl_rail_util_rssi_init();
  sl_ot_sys_init();
}

void sl_internal_app_init(void)
{
  sl_ot_init();
}

void sli_platform_process_action(void)
{
}

void sli_service_process_action(void)
{
  post_snapshot_live.phase = 1u;
  post_snapshot_live.cpc_enter++;
  sl_cpc_process_action();
  post_snapshot_live.cpc_exit++;
  post_snapshot_live.phase = 2u;
}

void sli_stack_process_action(void)
{
}

void sli_internal_app_process_action(void)
{
}

