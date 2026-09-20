# SDK 2026.6.1 ZBDongle-E startup: upstream evidence

Research date: 2026-09-20. Scope: read-only public vendor/source research and local build-record reading. No hardware access, builds, flashing, binding or production changes. The observed candidate nonresponse and successful SONOFF CPC 4.6.0 recovery were supplied by the parent investigation and were not independently reproduced here.

## Result

No inspected primary source establishes Gecko bootloader 1.12.0 as the cause or establishes a newer minimum bootloader for this application. No published SDK 2026.6.1 MG21 initial-CPC-startup failure matching the observation was found. This is a bounded negative search result, not proof of compatibility or absence of defects.

The strongest reusable board recipe agrees with the candidate's UART assignment and nominal CTUNE. Current vendor startup changes give specific functions to inspect, but the documented fixes are already in 2026.6.1. The next useful work is source/binary startup-path verification and observation of the failure boundary, rather than an unsupported bootloader upgrade.

## Confirmed vendor facts and their scope

1. [CPC 4.9.1 release notes, SDK 2026.6.1](https://docs.silabs.com/sisdk-release-notes/2026.6.1/sisdk-platform-release-notes/sisdk-plat-cpc-release-notes) list no known issues. Listed fixes concern multithread endpoint state and SPI project compilation. These do not describe a bare-metal UART startup failure.

2. [Platform MCU 6.1.1 release notes](https://docs.silabs.com/sisdk-release-notes/2026.6.1/sisdk-platform-release-notes/sisdk-plat-mcu-release-notes) identify two relevant historical initialization defects: ID 1665977, fixed in 6.1.1, arranges interrupts/NVIC before HFXO device initialization; ID 1589194, fixed in 6.1.0, adds atomic protection around Clock Manager SE calls to avoid executing `sli_se_execute_and_wait()` before `sl_se_init()`. 6.1.0 also adds a reset-handler assembly trampoline before C runtime initialization. These justify checking retained source and linked initialization order. They do not establish that either defect remains present in this candidate.

3. [OpenThread multiprotocol 3.1.1 release notes](https://docs.silabs.com/sisdk-release-notes/2026.6.1/sisdk-ot-release-notes/sisdk-ot-multiprotocol-release-notes) retain issue 1209958: MG21/MG24 Zigbee+Thread+BLE RCP can stop under continuous concurrent three-stack traffic after roughly two hours. That trigger is materially different from initial CPC version silence with no host stack started. The MG24 HCI reconnect fix 1639647 concerns the combined NCP/RCP/BLE app, not evidence for this candidate's failure.

4. [OpenThread 3.1.1 summary](https://docs.silabs.com/sisdk-release-notes/2026.6.1/sisdk-ot-release-notes/) imposes 128 KB RAM for `ot-ncp-ftd-cpc` and `ot-ncp-mtd-cpc`. Do not incorrectly transfer this requirement to the separate `rcp-uart-802154` project. The new combined NCP/RCP/BLE examples also require 128 KB, but are distinct projects.

5. [Gecko Platform 4.2.2.0 vendor notes, pages 12–13](https://www.silabs.com/documents/public/release-notes/gecko-platform-release-notes-4.2.2.0.pdf) specify SE 1.2.14 for xG21 **TrustZone Secure Key Library**, not every application. They separately recommend SE >=1.2.10 for xG21A Curve25519 users (or explicitly adding the software Curve25519 component). These are feature-specific requirements. Candidate selection of CPC ECDH security alone does not establish use of TZ SKL, Curve25519, or an unmet version requirement. Actual SE version and exact crypto paths remain unknown.

6. [Series 2 security documentation, Bluetooth 10.1.0](https://docs.silabs.com/bluetooth/10.1.0/iot-endpoint-security-fundamentals/11-series-2-device-security-features) distinguishes SE firmware from the Gecko bootloader, and reports different shipped SE versions by silicon revision. Gecko bootloader 1.12.0 is not an SE version measurement. The general recommendation to keep SE firmware current is not proof that old SE firmware causes this specific startup failure.

7. [Bootloader 3.3.1 notes](https://docs.silabs.com/sisdk-release-notes/2026.6.1/sisdk-platform-release-notes/sisdk-plat-bootloader-release-notes) contain image-validation, LTO and TrustZone metadata fixes, but no minimum Gecko bootloader requirement for MG21 `rcp-uart-802154`. Do not read the SDK's included bootloader version as an application runtime minimum.

## Reusable source recipes

The historical darkxst builder has a board-specific multipan recipe and released ZBDongle-E binaries. Public `main` tree resolved to `d3f417f250b3f9d52fa797c3a5b2ad74d926e693` during this inspection:

- [ZBDongleE manifest](https://github.com/darkxst/silabs-firmware-builder/blob/d3f417f250b3f9d52fa797c3a5b2ad74d926e693/manifests/zbdonglee.json): exact device `EFR32MG21A020F768IM32`; CTUNE 128 via old `SL_DEVICE_INIT_HFXO_CTUNE`; CPC no hardware flow control.
- [CPC pin patch](https://github.com/darkxst/silabs-firmware-builder/blob/d3f417f250b3f9d52fa797c3a5b2ad74d926e693/RCPMultiPAN/ZBDongleE/0001-config-configure-cpc-usart-vcom-B1B0.patch): USART0, TX PB1, RX PB0.
- [Released historical binaries](https://github.com/darkxst/silabs-firmware-builder/tree/d3f417f250b3f9d52fa797c3a5b2ad74d926e693/firmware_builds/zbdonglee) include multipan 4.2.2–4.4.5 variants. These establish an existing recipe, not independent hardware verification of any selected artifact in this investigation.

Local `firmware/build-offline.sh` matches the device and UART pins/flow, and intentionally changes to the new Clock Manager CTUNE configuration. That is reassuring at the nominal board-config level, but does not verify effective oscillator calibration, clock selection, power state or startup order.

The pinned [NabuCasa builder tree](https://github.com/NabuCasa/silabs-firmware-builder/tree/c9fa1d66d0063a5f838fdc4a6e5d0c11211d1b24/manifests/nabucasa) contains Nabu Casa board manifests, not a ZBDongle-E multipan manifest. Its container/tool provenance therefore must not be described as a known-working board recipe for this candidate.

## Narrow next checks (proposals, not executed)

- Verify generated/linked Clock Manager, HFXO, SE and CPC initialization paths include the documented fixes, then determine whether execution reaches CPC RX initialization and its event loop.
- Keep SE-version investigation conditional on the actual crypto commands used during startup. Do not infer the version from the bootloader banner or attempt a speculative SE update.
- Treat the historical board recipe as a comparison source, not proof of SDK2026 runtime compatibility. Preserve the successful official SONOFF fallback while investigating the application failure boundary.

## Follow-up: clock differences and application type

The parent reports binary comparison finds rollback fallback CTUNE 140 and SYSCLK HFXO, versus candidate fallback 128 and SYSCLK HFRCODPLL. Both prefer stored calibration. These remain supplied comparison observations, not findings independently disassembled here.

- SONOFF's [official NCP7.4.4 board README](https://github.com/itead/Sonoff_Zigbee_Dongle_Firmware/blob/master/Dongle-E/NCP_7.4.4/README.md) documents CTUNE 140 and TX PB1 for tested ZBDongle-E hardware. Thus the observed 140 has vendor corroboration; historical community 128 is a real different setting. This is an NCP recipe, not direct proof of intended SDK2026 CPC configuration.
- The pinned [SkyConnect SDK2026.6.1 manifest](https://github.com/NabuCasa/silabs-firmware-builder/blob/c9fa1d66d0063a5f838fdc4a6e5d0c11211d1b24/manifests/nabucasa/skyconnect/skyconnect_openthread_rcp.yaml) and [base RCP project](https://github.com/NabuCasa/silabs-firmware-builder/blob/c9fa1d66d0063a5f838fdc4a6e5d0c11211d1b24/src/openthread_rcp/openthread_rcp.slcp) use `clock_manager` without a SYSCLK or CTUNE override in those two files. SkyConnect has a different MG21 flash size and pinout. This gives no SONOFF-specific support for changing SYSCLK.
- No current vendor SDK ZBDongle-E board component or source-level SONOFF SDK2026 multipan recipe was established. The public historical Simplicity SDK 2025.6 tree search also returned no sonoff/zbdongle path, but this is not a complete SDK2026 component inventory.
- [Vendor application properties documentation](https://docs.silabs.com/mcu-bootloader/2.5.2/gecko-bootloader-api/application-properties) defines 0x2 as Thread and 0x20 as Bluetooth application. Therefore 0x22 is their combination; it is not a CPC-encryption flag or a newer minimum-bootloader indicator. No documented standard policy making 0x2 unbootable was found. Exact installed bootloader policy is not established by this search.


Vendor [Platform 6.0 Clock Manager configuration guide](https://docs.silabs.com/gecko-platform/6.0.0/platform-service-clock-manager-developer-guide/clock-manager-configuration) says default-HF AUTO selects HFXO when RAIL is present, and SYSCLK follows default-HF unless overridden (including execution modes). This generic guide does not establish the actual MG21 generated/linked setting; the reported HFRCODPLL difference warrants checking device-specific source resolution.
