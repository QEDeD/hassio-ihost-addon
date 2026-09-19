#include "sl_event_handler.h"

#include "sl_clock_manager.h"
#include "btl_interface.h"
#include "sl_dma_manager_instances.h"
#include "sl_cpc.h"
#include "sl_gpio.h"
#include "sl_mbedtls.h"
#include "psa/crypto.h"
#include "sl_se_manager.h"
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
}

void sl_stack_init(void)
{
}

void sl_internal_app_init(void)
{
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

