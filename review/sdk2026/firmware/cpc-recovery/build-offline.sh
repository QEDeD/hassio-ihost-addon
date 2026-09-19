#!/usr/bin/env bash
# OFFLINE ONLY — NOT FOR FLASHING. RECOVERY ONLY. Permits explicit CPC unbind; no automatic deletion.
set -euo pipefail
SDK=${SDK:-/opt/silabs/sdks/simplicity_sdk_2026.6.1}
WORK=${WORK:-/sdk2026-cpc-recovery}
GCC=${GCC:-/opt/toolchains/gcc-arm-none-eabi}
# Never reuse generated state or modify the SDK tree.
if [[ -e "$WORK" ]]; then echo "Refusing existing WORK directory: $WORK" >&2; exit 2; fi
mkdir -p "$WORK/source" "$WORK/evidence"
exec > >(tee "$WORK/evidence/build.log") 2>&1
printf '%s\n' 'OFFLINE ONLY — NOT FOR FLASHING'
slc --version
slc signature trust --sdk="$SDK"
"$GCC/bin/arm-none-eabi-gcc" --version
for file in app.c app.h cpc_app.c cpc_app.h cpc_secondary_vcom_security_device_recovery.slcp readme.md; do
  cp "$SDK/cpc_app/cpc_secondary_vcom_security_device_recovery/$file" "$WORK/source/$file"
done
sha256sum "$WORK/source/"* > "$WORK/evidence/source-sha256.txt"
patch --batch --fuzz=0 -d "$WORK/source" -p1 < /firmware/explicit-unbind-only.patch
patch --batch --fuzz=0 -d "$WORK/source" -p1 < /firmware/explicit-uart.slcp.patch
sha256sum "$WORK/source/"* > "$WORK/evidence/patched-source-sha256.txt"
slc generate --no-daemon --tool-path=/opt/silabs/python \
  -s "$SDK" -p "$WORK/source/cpc_secondary_vcom_security_device_recovery.slcp" \
  -d "$WORK/generated" -o cmake --with EFR32MG21A020F768IM32,cpc_security_secondary,bootloader_interface \
  --configuration 'SL_CPC_SECURITY_ENABLED:1,SL_CPC_SECURITY_BINDING_KEY_METHOD:SL_CPC_SECURITY_BINDING_KEY_ECDH,SL_CPC_DRV_UART_VCOM_BAUDRATE:115200,SL_CPC_DRV_UART_VCOM_FLOW_CONTROL_TYPE:usartHwFlowControlNone,SL_CPC_DRV_UART_VCOM_PERIPHERAL:USART0,SL_CPC_DRV_UART_VCOM_PERIPHERAL_NO:0,SL_CPC_DRV_UART_VCOM_TX_PORT:gpioPortB,SL_CPC_DRV_UART_VCOM_TX_PIN:1,SL_CPC_DRV_UART_VCOM_RX_PORT:gpioPortB,SL_CPC_DRV_UART_VCOM_RX_PIN:0,SL_CLOCK_MANAGER_HFXO_CTUNE:128,NVM3_DEFAULT_NVM_SIZE:40960,SL_PSA_ITS_USER_MAX_FILES:128,SL_PSA_ITS_SUPPORT_V3_DRIVER:1,SL_PSA_ITS_SUPPORT_V2_DRIVER:0,SL_PSA_ITS_SUPPORT_V1_DRIVER:0'

# SLC configuration overrides do not activate commented pin-tool definitions.
# Apply the narrowly scoped provisional pin assignment to generated config only.
python3 - "$WORK/generated/config/sl_cpc_drv_uart_usart_vcom_config.h" <<'PY'
import pathlib, re, sys
p = pathlib.Path(sys.argv[1])
s = p.read_text()
s = s.replace('#warning "CPC USART peripheral not configured"', '// Offline provisional ZBDongle-E assignment; NOT FOR FLASHING.')
for name, value in {'PERIPHERAL': 'USART0', 'PERIPHERAL_NO': '0', 'TX_PORT': 'gpioPortB', 'TX_PIN': '1', 'RX_PORT': 'gpioPortB', 'RX_PIN': '0'}.items():
    s, n = re.subn(r'^// #define SL_CPC_DRV_UART_VCOM_' + name + r'\s+\S+.*$', '#define SL_CPC_DRV_UART_VCOM_' + name + ' ' + value, s, flags=re.M)
    assert n == 1, (name, n)
p.write_text(s)
PY
export ARM_GCC_DIR="$GCC" NINJA_EXE_PATH=/usr/bin/ninja
# No Commander pipeline is selected. Fail rather than execute one if that changes.
grep -qx 'set(post_build_command )' "$WORK/generated/cmake_gcc/cpc_secondary_vcom_security_device_recovery.cmake"
export POST_BUILD_EXE=/usr/bin/false
cd "$WORK/generated/cmake_gcc"
cmake --preset project
cmake --build --preset default_config --parallel "${JOBS:-2}"
