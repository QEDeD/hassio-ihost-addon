# CPC binding-key recovery application — offline qualification

Built and packaged on 2026-09-19. This is a separate, temporary recovery application for a **candidate-created CPC binding whose host key was lost**. It was not flashed or exercised on a radio. It does not establish that the old radio firmware can boot safely after candidate PSA storage changes. Production use still needs the exact bounded recovery branch approved in [the trial decision table](../../recovery/TRIAL-STATE-TRANSITIONS.md).

The application comes from SDK2026.6.1 `cpc_app/cpc_secondary_vcom_security_device_recovery`. [The source patch](explicit-unbind-only.patch) removes its automatic boot-time unbind; the final `cpc_app_init` is a single return instruction. The sample's remote-unbind callback intentionally remains permissive. A second [project patch](explicit-uart.slcp.patch) selects the same USART provider as the normal candidate. Build configuration selects the existing MG21 target, bootloader interface, UART pins and storage settings. Normal firmware is unchanged.

## Exact retained artifacts

| Item | Identity / result |
|---|---|
| Recovery application GBL | [`package/cpc-recovery-sdk2026-application-only.gbl`](package/cpc-recovery-sdk2026-application-only.gbl) |
| GBL SHA256 | `22c4d75097b5cda0e8d60634cc1753d9615069398055b81b8c5a219e64f49897` |
| ELF SHA256 | `780ad48b11ecd28c71e5443b8de704946b040388cde7d9de5eac354877986099` |
| Linked origin / touched 8 KiB pages | `0x4000` / `[0x4000,0x14000)` |
| Application properties | Generic MCU type `0x10`, version 1, unsigned; no SE bit or dependency tag |
| Persistent storage | NVM3 `[0xb4000,0xbe000)`, 40960 bytes; ITS V3, V1/V2 off; total files `1 + 128 = 129` |
| Target / UART | `EFR32MG21A020F768IM32`, USART0, TX PB1, RX PB0, 115200, no flow control, HFXO CTUNE 128 |
| Builder | `ghcr.io/nabucasa/silabs-firmware-builder@sha256:aaeedf3cceb95dc15a9d3333093e76957ef20d06f94d3f7b23d5bd88d337a85d` |
| Packaging tool | Simplicity Commander `1v25p0b1995`, retained official CLI archive used offline |

The independent [package validation](package/independent-validation.json) found exact ELF/SREC/GBL payload equality, valid GBL3 tags and CRC, and no bootloader, Secure Engine, NVM or USERDATA payload. It proves artifact content, not bootloader acceptance or interruption safety on this device. The artifact's smaller application footprint and generic MCU application type are expected for the vendor recovery sample.

## Checked scope of storage changes

[Storage comparison](evidence/storage-comparison.json) confirms the generated NVM3 config is byte-identical to the normal candidate. PSA config differs only by parentheses around `128`; normalized defines, CPC security config and generated total ITS capacity match. Platform initialization is identical. Recovery service initialization is the same candidate prefix: CPC, mbedTLS, PSA crypto and SE manager. Network-only initialization is absent. The generated catalog contains no Zigbee, Thread or RAIL stack.

The final [unbind disassembly](evidence/sl_cpc_security_unbind-disassembly.txt) uses key `0x4200` for presence, deletion and absence checks. `erase_binding_key` was inlined into this function. The [request handler](evidence/sli_cpc_security_process-disassembly.txt) contains the allow-magic checks, unbind call and permission-denied branch; `on_unbind_cmd` was inlined there. The [recovery callback](evidence/sl_cpc_security_on_unbind_request-disassembly.txt) returns the allow magic intentionally. There is no linked erase-all symbol or observer-registration function. The selected PSA/ITS path resolves the key UID to one NVM3 object and deletes it, including lookup/tombstone bookkeeping. [Source hashes and host commit](evidence/source-provenance.json) identify the inspected implementations without copying entire vendor libraries.

This is a **logical one-key deletion**, not a promise that only one physical flash word changes. NVM3 startup/repacking and ITS bookkeeping can write storage. Matching source, configuration and initialization supports the candidate-created-key recovery route; no hardware snapshot, power-loss test or proof of every unrelated radio value surviving exists. Corrupt/inaccessible ITS, an unknown baseline binding format and an unreachable bootloader remain unsupported. Do not erase, reformat, migrate drivers or weaken errors to continue.

## Explicit host operation required

After the separately approved recovery-only application upload, with all normal radio/network services stopped, run the stock CPCd binary directly **once**:

```sh
/usr/local/bin/cpcd --conf /PRIVATE/RECOVERY/cpcd.conf --unbind
```

This command was not executed against a device. `/PRIVATE/RECOVERY` and the serial target must be resolved by the parent operation plan. Use CPCd 4.9.1 commit `87f6dbda4eef05e4538589c195099c3daf8f6f6b`, already retained in the candidate host. The private configuration must select the exact approved `uart_device_file` and contain:

```yaml
instance_name: cpc_recovery
bus_type: UART
uart_device_baud: 115200
uart_hardflow: false
bootloader_recovery_pins_enabled: false
disable_encryption: false
trace_level: info
trace_to_file: false
trace_to_syslog: false
```

Run in the reviewed isolated maintenance process/container context, with no TCP bridge or network clients and no competing serial owner. Any configured binding-file path must be private; explicit unbind mode does not read, replace or generate that file. Do not start the normal app graph: its normal missing-key guard appropriately prevents ordinary encrypted startup, whereas the audited `--unbind` mode deliberately skips key loading and ECDH keypair creation. No second bind, normal-daemon probe or new protocol is needed to observe the unbind result.

| Observed stock CPCd result | Interpretation / next action |
|---|---|
| `Unbind successful...`, exit 0 without already-unbound warning | Secondary reported removal succeeded and its storage absence check passed. |
| `The secondary was already not bound`, then success, exit 0 | Secondary reported no binding key in the matched backend. Preserve this distinction. |
| Permission denial, storage/transport failure, timeout or missing affirmative completion | Unconfirmed recovery. Stop and retain protected evidence; no retry or fallback is implied. |

The command intentionally deletes CPC key material. `PROP_SECURITY_STATE` is only session state and is insufficient as a bound/unbound probe. Do not enable frame/debug tracing or expose key material while collecting the stock exit status and informational result.

After either affirmative result, return immediately to the exact approved normal candidate application. Only then perform a separately approved single ECDH bind into a fresh protected destination, preserve its matching key, and reconnect before starting the existing networks. Preserve the failed original key evidence. If return upload or binding fails, leave services stopped and escalate that observed state. The recovery application permits unauthenticated local unbind by design and must not remain deployed for normal use. No production step is authorized by this document.

## Reproduction and retained evidence

`build.sh` / `Dockerfile.offline` use the existing pinned builder and Debian snapshot helper, with `RUN --network=none` for generation and compilation. A new output directory is required. `verify-offline.sh` checks configuration, symbols and final disassembly; `compare-storage.py OUTPUT ../candidate-clean` checks the retained normal candidate comparison. `build-package.sh` reuses Commander GBL3 creation/parsing and refuses an existing packaging work directory; it pins the expected ELF above. `verify-package.py` independently verifies the resulting package. No flashing or erase command is part of these scripts.

Completed build output, raw vendor sample copies and bulky debugging material remain under ignored `output/`; no rebuild was needed during closeout. The final GBL, small generated initialization/catalog evidence, source/patch hashes, symbols and selected disassembly are retained for review. Empty outputs for inlined functions were removed; their containing functions are recorded instead. Build and package validation passed. Static source/binary inspection was performed; affirmative/negative response paths have not been exercised on hardware. No production access, binding, key deletion or publication occurred.
