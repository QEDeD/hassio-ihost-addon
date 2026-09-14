# Functional state map — 2026-09-14

Purpose: preserve existing networks without re-pairing. This replaces the assumption that every radio flash byte must be restored. Paths below are relative to SDK2026.6.1 at /opt/silabs/sdks/simplicity_sdk_2026.6.1.

| Consequential state | Existing implementation and recovery source | Remaining check / consequence |
|---|---|---|
| Zigbee membership, keys and counters | zigbee/stack/platform/sl_zigbee_token_host.c stores dynamic tokens in host_token.nvm; zigbee/stack/config/token-stack.h defines keys/network/trust-center/counters. Current backup includes host token file plus Z2M config/database/coordinator backup. | Compatible token interpretation and counter continuity needed. Never assume restoring an arbitrarily old backup is safe merely because the format matches. |
| Zigbee identity | zigbee/stack/platform/zigbee_token_interface.c:115–145 has zigbeed restored-EUI64 token support. | Establish actual candidate/baseline use before claiming coordinator identity preservation. |
| Thread membership and counters | openthread_stack/util/third_party/openthread/src/core/common/settings.hpp defines datasets/network-info/key sequences/MAC+MLE counters and other settings; POSIX settings.cpp uses host file store. Backup includes whole focused Thread store and HA Thread integration. | Preserve full store, not only active dataset. |
| Effective radio identity | openthread/platform-abstraction/efr32/radio_interface.cpp:813–839 reads USERDATA custom EUI64 at offset2 when custom support enabled, else SYSTEM_GetUnique(). POSIX settings.cpp:85–105 derives file basename from EUI64 unless override. | Changed effective EUI64 may select another Thread settings file. Preserve or deliberately account for it; a directory backup alone is insufficient. |
| Volatile radio MAC state | radio_spinel.cpp:890–929,2152–2193 restores PAN/address/channel/keys/frame counters from host after RCP reset. | Reconstructible from host under supported reset behavior; not proof of arbitrary firmware downgrade or old-backup counter rollback. |
| CPC binding | cpc/src/sl_cpc_security.c persists PSA key0x4200; session keys separately volatile. Candidate requires matching host key. Retained plaintext host sets disable_encryption:true. | Transport binding is distinct from network membership. Preserve new key for candidate; old plaintext host does not require it. Old radio startup's treatment of newer storage remains unverified. |
| Radio calibration | platform_core/platform/service/device_init/src/sl_device_init_hfxo_s2.c:35–73 reads DEVINFO when available, then manufacturing CTUNE at0x0FE00100, then configuration fallback. | Parent inspected exact source; application GBL does not write these addresses. Confirm selected build/config and avoid treating this source read path as exhaustive proof of all calibration behavior. |
| Matter fabrics and HA/Z2M user state | Backupfeec49c2 has controller/fabric files, HA storage, Z2M configuration/database and supported app data. | Backup coverage verified; actual restore not exercised. No evidence that these fabrics reside in multipan RCP. |

## Concrete token format check

SDK sl_zigbee_token_host.c:498–509 refuses version1 when VERSION=2 and resets on other version mismatches. The format is the first byte. Read ONLY that non-secret byte from the current backup using documented HA SSH access:

    tar -xOf /backup/feec49c2.tar local_codex_ihost_otbr_focused.tar.gz | tar -xzOf - data/zigbeed/host_token.nvm | od -An -tu1 -N1

Observed2. No key values were output or copied into the repository; no production file was modified. This rules out the explicit v1 refusal for this backup. It does not prove full token schema, secure-key storage or downgrade compatibility. SDK token-stack.h warns that secure-key configurations can use PSA; actual build selection still needs checking.

## Reused mechanisms and next checks

Reuse vendor host token/Thread settings handling, retained tested baseline image (REUSE-FINDINGS.md), current Supervisor backup and vendor cpcd binding. No custom dump protocol, migration framework or bootloader upgrade is justified by these findings.

Next consequential checks: actual candidate secure-key/token configuration; matching baseline identity/host-format behavior; physical acceptance and encrypted persistence as trial criteria. A spare experiment is useful only for identified hardware/runtime uncertainty; production preservation is judged by effective identities, compatible stores/counters, calibration and transport recovery rather than exact flash equality.

Vendor cpcd help from isolated final image confirms proposed binding form cpcd --conf CONFIG --bind ecdh --key KEYFILE. This is syntax evidence only. No binding command executed. Missing/wrong key recovery must not silently generate/rebind/erase; existing fail-closed host preflight remains in scope.

Source analysis was performed by the reused SDK worker; parent independently inspected radio EUI and HFXO initialization, token-version rejection, and the saved backup's format byte. No production restart/reset/flash/binding or publication occurred.