# CPC security assessment — provisional

Encrypted CPC remains the preferred target under evaluation, not an adopted or deployed configuration. Existing unencrypted host/radio pair is the comparison baseline. Both firmware modes previously compiled; no binding/handshake evidence survives as a live test because none was performed.

## Source-backed host behavior
CPCd 4.9.1 supports ECDH, plaintext and custom binding; vendor recommends ECDH. Its exchange is anonymous, so provisioning requires a physically trusted connection. Existing binding blocks new binding. Remote unbind is denied by default unless firmware explicitly authorizes it.

The v4.9.1 key loader creates a random 128-bit key when its configured key file cannot be opened, including normal startup. Files are created with mode 0600. Malformed-length diagnostics can disclose file content. Therefore the app should check the expected persistent key exists, is readable and correctly formatted without logging its contents before starting CPCd. Never automatically replace keys, rebind, unbind or disable encryption to repair startup. Security-endpoint/session initialization failures terminate CPCd; whole service behavior still needs tests.

Sources reviewed by worker:
- https://github.com/SiliconLabs/cpc-daemon/blob/v4.9.1/readme.md#encrypted-serial-link
- https://github.com/SiliconLabs/cpc-daemon/blob/v4.9.1/security/private/keys/keys.c
- https://github.com/SiliconLabs/cpc-daemon/blob/v4.9.1/security/private/thread/security_thread.c
- https://github.com/SiliconLabs/cpc-daemon/blob/v4.9.1/security/private/protocol/protocol.c

## Remaining verification
Actual SDK 2026.6.1 source was read on 2026-09-14 from container `sisdk-upgrade-trial-20260914`, rooted at `/opt/silabs/sdks/simplicity_sdk_2026.6.1`. The package uses `cpc/`, not the older `platform/service/cpc/` path. This verifies library behavior, not hardware persistence or the final generated RCP configuration:

- `cpc/src/sl_cpc_security.c:206` checks persistent storage for the binding key at initialization and marks the device bound when present.
- `cpc/src/sl_cpc_security.c:856-906` rejects replacing an existing binding, assigns the binding key a fixed PSA ID, and imports it with `PSA_KEY_LIFETIME_PERSISTENT` and `PSA_KEY_LOCATION_LOCAL_STORAGE` at lines 878-880. Session keys are separately volatile at line 1086.
- `cpc/src/sl_cpc_security.c:270-274` supplies the weak unbind callback returning zero (deny). Lines 743-765 authorize unbinding only when the callback returns the expected magic value. Lines 914-932 destroy the persistent key and verify its removal.
- `cpc/config/sl_cpc_security_config.h:38-49` defaults to security enabled and ECDH binding. These are SDK defaults, not proof of generated candidate settings.
- `cpc/src/sl_cpc.c:2651-2665` starts system and security endpoints without encryption; other endpoints default to encrypted unless their creation flags include `SL_CPC_ENDPOINT_FLAG_DISABLE_ENCRYPTION`. Therefore global security enablement does not prove that every application endpoint is encrypted.
- SDK recovery examples explicitly override the weak unbind callback: `cpc_app/cpc_secondary_vcom_security_device_recovery/cpc_app.c:40` and the corresponding SPI recovery example. Their presence does not prove either override is linked into the candidate RCP.

The subsequent standard-project inspection below resolves the vendor application endpoint flags and unbind implementation at source level. Still verify generated candidate configuration and final linked symbols, and confirm storage backend/layout and flashing procedure before claiming upgrade/downgrade preservation.

Configure key in private persistent app storage; verify backup coverage and permissions. Restoring matching key should reconnect to same bound dongle; lost/mismatched key needs explicit recovery. Firmware upgrade/downgrade preservation depends on flash procedure and storage compatibility, unproven by compilation. Retain key even for intentional unencrypted rollback.

Offline tests: missing/unreadable/malformed key, no secret-bearing diagnostics, no automatic fallback or binding, service failure propagation. Hardware tests: explicit one-time binding, matched host/radio handshake, restart/power-cycle, backup/restore, interrupted binding and wrong-key recovery, firmware upgrade/downgrade and network preservation.

Recommend preserving default-denied remote unbind and preparing a separate recovery procedure; don't add a new physical-unbind firmware feature without demonstrated need. No final security selection, live action or publication.


## Standard multi-PAN RCP project: source-level conclusion

The standard encrypted RCP can retain default-denied remote unbinding and encrypt the shared Thread/Zigbee radio transport without custom firmware source changes. This is a source-level conclusion for the vendor project with the encrypted security component selected; it is not a new build or hardware result, nor a final security selection.

Evidence inspected in the actual SDK archive:

- `openthread_app/ot-ncp/cpc/rcp-uart-802154.slcp` selects `ot_ncp_cpc`, enables multi-PAN RCP and multiple static instances, and does not select security-none or override the security defaults. Its `README-MP-RCP.md:1-5` describes concurrent host OpenThread and Zigbee stacks using this RCP.
- `openthread/component/ot_ncp_cpc.slcc` requires `cpc_secondary` and supplies `openthread/platform-abstraction/ncp/ncp_cpc.cpp`. `cpc/component/cpc_secondary.slcc` requires and recommends `cpc_security_secondary`; the security-enabled configuration defaults already recorded above apply when that provider is selected. Generated dependency resolution must still be checked for the candidate.
- `openthread/platform-abstraction/ncp/ncp_cpc.cpp:58-103` constructs the multi-instance NCP over a single CPC transport. At line 126 it opens `SL_CPC_ENDPOINT_15_4` with flags `0`, not the encryption-disable flag. `cpc/inc/sli_cpc.h:260` assigns this endpoint ID 12. Combined with `cpc/src/sl_cpc.c:2651-2665`, the shared radio endpoint is encrypted when CPC endpoint security is enabled. Thread and Zigbee do not require separate firmware CPC encryption settings in this project.
- The vendor application `openthread_app/ot-ncp/cpc/app.c` has no unbind override. An SDK-wide C/C++ source search found strong definitions only in the Connect NCP interface and three separate CPC example applications, none selected by this OpenThread/Zigbee RCP project. The standard project therefore retains the weak deny callback in `cpc/src/sl_cpc_security.c:270-274`; no custom callback is needed to deny remote unbinding.

This removes the need to design a custom unbind feature or modify endpoint flags for the encrypted candidate. Preserve the standard deny policy and prepare an explicit recovery procedure. Remaining validation is generated configuration/link verification, host preflight and key persistence, then authorized hardware binding, traffic, recovery and rollback tests. System/security negotiation traffic is separate from the encrypted application endpoint; do not describe the entire wire stream as encrypted.

## Compiled firmware follow-up
The subsequent firmware/candidate evidence verifies generated security=1/ECDH, linked encrypted shared endpoint ID12 and default-denied unbind control flow; see firmware/README.md. Parent independently checked the ELF hash. This supersedes earlier statements that generated/link verification remains unperformed. Clean-container reproduction, actual binding, physical storage compatibility, persistence and recovery remain open.
