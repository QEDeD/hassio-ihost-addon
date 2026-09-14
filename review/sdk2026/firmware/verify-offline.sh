#!/usr/bin/env bash
set -euo pipefail
: "${WORK:?Set the completed offline candidate directory}"
GCC=${GCC:-/opt/toolchains/gcc-arm-none-eabi}
SDK=${SDK:-/opt/silabs/sdks/simplicity_sdk_2026.6.1}
ART="$WORK/generated/cmake_gcc/build/base"
ELF="$ART/rcp-uart-802154.out"
python3 - "$WORK" <<'PY'
import pathlib, re, sys
root=pathlib.Path(sys.argv[1])
checks={
'sl_cpc_security_config.h':{'SL_CPC_SECURITY_ENABLED':'1','SL_CPC_SECURITY_BINDING_KEY_METHOD':'SL_CPC_SECURITY_BINDING_KEY_ECDH'},
'sl_cpc_drv_uart_usart_vcom_config.h':{'SL_CPC_DRV_UART_VCOM_PERIPHERAL':'USART0','SL_CPC_DRV_UART_VCOM_PERIPHERAL_NO':'0','SL_CPC_DRV_UART_VCOM_TX_PORT':'gpioPortB','SL_CPC_DRV_UART_VCOM_TX_PIN':'1','SL_CPC_DRV_UART_VCOM_RX_PORT':'gpioPortB','SL_CPC_DRV_UART_VCOM_RX_PIN':'0','SL_CPC_DRV_UART_VCOM_BAUDRATE':'115200','SL_CPC_DRV_UART_VCOM_FLOW_CONTROL_TYPE':'usartHwFlowControlNone'},
'sl_clock_manager_oscillator_config.h':{'SL_CLOCK_MANAGER_HFXO_CTUNE':'128'},
'sl_openthread_features_config.h':{'OPENTHREAD_CONFIG_MULTIPAN_RCP_ENABLE':'1','OPENTHREAD_CONFIG_MULTIPLE_STATIC_INSTANCE_ENABLE':'1'}}
lines=['OFFLINE ONLY — NOT FOR FLASHING','Generated config assertions:']
for file, settings in checks.items():
    text=(root/'generated/config'/file).read_text()
    for key, value in settings.items():
        assert re.search(r'^#define\s+'+re.escape(key)+r'\s+'+re.escape(value)+r'\s*$',text,re.M),key
        lines.append(f'{key}={value}')
(root/'evidence/config-validation.txt').write_text('\n'.join(lines)+'\n')
PY
"$GCC/bin/arm-none-eabi-nm" -C "$ELF" > "$WORK/evidence/symbols.txt"
"$GCC/bin/arm-none-eabi-size" -A "$ELF" > "$WORK/evidence/section-sizes.txt"
"$GCC/bin/arm-none-eabi-objdump" -dS "$ELF" | gzip -n > "$WORK/evidence/disassembly.txt.gz"
"$GCC/bin/arm-none-eabi-objdump" -dS --disassemble=open_endpoint.constprop.0 "$ELF" > "$WORK/evidence/endpoint-disassembly.txt"
# Record the source used for binary security interpretation; SDK files stay untouched.
mkdir -p "$WORK/evidence/vendor-security-source"
for f in cpc/src/sl_cpc_security.c cpc/src/sl_cpc.c cpc/inc/sli_cpc.h openthread/platform-abstraction/ncp/ncp_cpc.cpp platform_core/platform/common/inc/sl_status.h platform_core/platform/service/clock_manager/src/sl_clock_manager_init_hal_s2.c; do
  cp "$SDK/$f" "$WORK/evidence/vendor-security-source/"
done
(cd "$ART" && sha256sum rcp-uart-802154.*) > "$WORK/evidence/artifact-sha256.txt"
printf '%s\n' 'OFFLINE ONLY — NOT FOR FLASHING. Build and configuration assertions completed.'
