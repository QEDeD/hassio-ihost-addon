#!/usr/bin/env bash
set -euo pipefail
: "${WORK:?}"
GCC=${GCC:-/opt/toolchains/gcc-arm-none-eabi}
ART="$WORK/generated/cmake_gcc/build/base"
ELF="$ART/cpc_secondary_vcom_security_device_recovery.out"
"$GCC/bin/arm-none-eabi-nm" -C "$ELF" > "$WORK/evidence/symbols.txt"
"$GCC/bin/arm-none-eabi-size" -A "$ELF" > "$WORK/evidence/section-sizes.txt"
"$GCC/bin/arm-none-eabi-objdump" -d "$ELF" | gzip -n > "$WORK/evidence/disassembly.txt.gz"
for symbol in cpc_app_init sl_cpc_security_on_unbind_request sl_cpc_security_unbind sli_cpc_security_process psa_destroy_persistent_key psa_its_remove; do
  "$GCC/bin/arm-none-eabi-objdump" -d --disassemble="$symbol" "$ELF" > "$WORK/evidence/$symbol-disassembly.txt"
done
python3 - "$WORK" <<'PY'
import pathlib,re,sys,json
p=pathlib.Path(sys.argv[1]); cfg=p/'generated/config'
def value(file,name):
    m=re.search(r'^#define\s+'+name+r'\s+([^\n]+)',(cfg/file).read_text(),re.M)
    assert m,name
    return m.group(1).strip().strip('()')
expected={
 'sl_cpc_security_config.h':{'SL_CPC_SECURITY_ENABLED':'1','SL_CPC_SECURITY_BINDING_KEY_METHOD':'SL_CPC_SECURITY_BINDING_KEY_ECDH'},
 'sl_cpc_drv_uart_usart_vcom_config.h':{'SL_CPC_DRV_UART_VCOM_PERIPHERAL':'USART0','SL_CPC_DRV_UART_VCOM_TX_PORT':'gpioPortB','SL_CPC_DRV_UART_VCOM_TX_PIN':'1','SL_CPC_DRV_UART_VCOM_RX_PORT':'gpioPortB','SL_CPC_DRV_UART_VCOM_RX_PIN':'0','SL_CPC_DRV_UART_VCOM_BAUDRATE':'115200','SL_CPC_DRV_UART_VCOM_FLOW_CONTROL_TYPE':'usartHwFlowControlNone'},
 'sl_clock_manager_oscillator_config.h':{'SL_CLOCK_MANAGER_HFXO_CTUNE':'128'},
 'nvm3_default_config.h':{'NVM3_DEFAULT_NVM_SIZE':'40960'},
 'psa_crypto_config.h':{'SL_PSA_ITS_USER_MAX_FILES':'128','SL_PSA_ITS_SUPPORT_V3_DRIVER':'1','SL_PSA_ITS_SUPPORT_V2_DRIVER':'0','SL_PSA_ITS_SUPPORT_V1_DRIVER':'0'}}
for file,defs in expected.items():
    for key,want in defs.items(): assert value(file,key)==want,(key,value(file,key),want)
auto=(p/'generated/autogen/sli_psa_config_autogen.h').read_text()
assert '#define SL_PSA_ITS_MAX_FILES (1 + SL_PSA_ITS_USER_MAX_FILES)' in auto, auto
sym=(p/'evidence/symbols.txt').read_text()
assert re.search(r'^00004000 \w __Vectors$',sym,re.M),'application origin'
assert re.search(r'^000b4000 \w __nvm3Base$',sym,re.M),'NVM base'
cat=(p/'generated/autogen/sl_component_catalog.h').read_text()
assert 'SL_CATALOG_GECKO_BOOTLOADER_INTERFACE_PRESENT' in cat
assert 'SL_CATALOG_OPENTHREAD' not in cat and 'SL_CATALOG_ZIGBEE' not in cat
source=(p/'source/cpc_app.c').read_text()
assert 'sl_cpc_security_unbind();' not in source
assert 'return SL_CPC_SECURITY_OK_TO_UNBIND;' in source
report={'configuration':expected,'psa_total_files':129,'application_origin':'0x4000','nvm_base':'0xb4000','nvm_size':40960,'network_stacks_absent':True,'automatic_unbind_removed':True,'remote_unbind_intentionally_permitted':True}
(p/'evidence/config-validation.json').write_text(json.dumps(report,indent=2)+'\n')
PY
(cd "$ART" && sha256sum cpc_secondary_vcom_security_device_recovery.*) > "$WORK/evidence/artifact-sha256.txt"
