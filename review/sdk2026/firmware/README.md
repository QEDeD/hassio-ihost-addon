# OFFLINE ONLY — NOT FOR FLASHING

An encrypted multi-PAN RCP candidate was generated and compiled successfully on 2026-09-14 from the retained official Simplicity SDK 2026.6.1 vendor `openthread_app/ot-ncp/cpc/rcp-uart-802154.slcp` project. It has not been flashed, bound, or tested on hardware. Physical board identity, bootloader, storage compatibility and recovery remain unverified. No production configuration or security selection is implied.

## Clean reconstruction — current entry point

`Dockerfile.offline` and `build-clean.sh` reconstruct the firmware in a disposable build stage from the pinned builder digest below. No retained-container packages, SDK trust configuration, bind mounts or device access are used. Signed Debian package inputs come from the shared `../recipe/pin-debian-snapshot.sh` at snapshot `20260914T000000Z`; required CMake, Ninja, Python 3 and gzip packages are explicitly declared. SLC trust and its bundled Python tool path are explicitly initialized. After packages are obtained, generation, compilation and verification run with Docker `--network=none`.

Run from a Bash environment with Docker and this checkout available:

```sh
FIRMWARE_OUTPUT=/absolute/path/to/new-output BUILD_JOBS=2 bash review/sdk2026/firmware/build-clean.sh
```

The output directory must not exist. The wrapper uses `--no-cache` and creates only local artifacts, not an installed or published service. On Windows PowerShell the validated equivalent, from the repository root, was:

```powershell
docker build --platform linux/amd64 --no-cache --progress plain --file review/sdk2026/firmware/Dockerfile.offline --build-arg BUILD_JOBS=2 --output type=local,dest=review/sdk2026/firmware/candidate-clean .
```

The clean build completed successfully on 2026-09-14, including 321 compilation/link steps and generated configuration assertions. [clean-build.log](clean-build.log) records package installation, explicit SDK trust, build and artifact export. [candidate-clean/evidence/package-evidence](candidate-clean/evidence/package-evidence) records every installed package version, effective signed sources, APT configuration and InRelease hashes. Exact scripts and package setup are included in the new evidence directory. The initial retained-container result remains separately under `candidate/`.

| Result | ELF SHA-256 | Raw binary SHA-256 |
| --- | --- | --- |
| Clean digest-based build (`candidate-clean/`) | `165a4a603d42eedd346b8e5e881662d41b9689eaecc762848d86535dfe064f74` | `2bd240ec4e87fd4daf198ec983c3bcb1fbeb82a62269147d40155a4055f627f4` |
| Initial retained trial (`candidate/`) | `ecf1c76c789853e29f9e54606d8928786205a5f84030b2c35ff22ea07e3c14eb` | `3a8a51b24201f335748617123ecee0123a30065f7f2752c7387816736db7a093` |

All five clean artifact hashes were independently checked after Windows export. The clean binary's disassembly was also inspected: the unbind-denial branch, shared endpoint ID 12/flags 0 and encrypted assignment use the same addresses and behavior documented below; NVM bounds are unchanged. Hashes differ, and byte-for-byte equivalence is not claimed. This establishes repeatable generation/build from recorded obtained inputs, not hardware acceptance. The generated config, artifacts and linked evidence for this new result are all under `candidate-clean/`.

## Original retained trial: inputs and reconstruction

- Retained container: `sisdk-upgrade-trial-20260914`.
- Image ID: `sha256:aaeedf3cceb95dc15a9d3333093e76957ef20d06f94d3f7b23d5bd88d337a85d` (inspected).
- Builder provenance supplied by prior trial: NabuCasa/silabs-firmware-builder commit `c9fa1d66d0063a5f838fdc4a6e5d0c11211d1b24`. This recipe invokes SLC/CMake directly; it does not claim to have rerun that repository's builder wrapper.
- SDK: `/opt/silabs/sdks/simplicity_sdk_2026.6.1`; SLC 6.0.22; ARM GCC 14.2.Rel1 (compiler 14.2.1 20241119).
- Vendor app.c/app.h/slcp/README are copied unchanged; hashes are retained under `candidate/evidence/source-sha256.txt`.
- Provisional device: EFR32MG21A020F768IM32 / ZBDongle-E, USART0 PB1 TX / PB0 RX, 115200, no hardware flow control.
- Security component explicitly selected, `SL_CPC_SECURITY_ENABLED=1`, ECDH binding. Vendor multi-PAN and static multiple-instance configuration remain enabled.
- `SL_CLOCK_MANAGER_HFXO_CTUNE=128` is the configured fallback. The SDK can prefer DEVINFO/manufacturing calibration; physical effective tuning is not verified.

Copy both recipe scripts into the retained container, choose a fresh directory (the build refuses an existing one), then run:

```sh
WORK=/sdk2026-firmware/reproduction-01 JOBS=2 bash /sdk2026-firmware-build.sh
WORK=/sdk2026-firmware/reproduction-01 bash /sdk2026-firmware-verify.sh
```

The scripts' container names above correspond to `build-offline.sh` and `verify-offline.sh`. Export the resulting `source`, `generated/config`, `generated/autogen`, `generated/cmake_gcc/build/base`, and `evidence` directories using `docker cp`; `/repo` and `/trial` are not used. The successful build used WORK `/sdk2026-firmware/candidate-v3`.

SLC's configuration overrides do not activate the commented pin-tool assignments for a bare chip target. The recipe therefore performs six asserted replacements in the generated UART config only, preserving the vendor application and SDK sources. The unused old device-init CTUNE override is not used; this SDK project uses clock_manager. The recipe asserts the Commander post-build command is empty and provides a failing placeholder executable; no device command runs.

The original trial below is a command/input record, not evidence of bit-for-bit reproducibility across independent tool installations. Use the clean entry point above for reconstruction. Generated files retain absolute container paths. Inspect `candidate/evidence/build.log` for tool output and warnings.

## Checked result

The generated configuration assertions passed. The candidate includes ELF (`.out`), raw `.bin`, Intel HEX, S-record, map, generated configs/linker script, compressed source-interleaved disassembly and symbol listing. Artifacts are investigation outputs only. All artifact SHA-256 values are in `candidate/evidence/artifact-sha256.txt`; ELF SHA-256 is `ecf1c76c789853e29f9e54606d8928786205a5f84030b2c35ff22ea07e3c14eb`.

The release project enables LTO, which inlines the weak unbind callback into `main`; absence of a separate callback symbol is not itself proof of denial. The final binary's source-interleaved disassembly provides stronger evidence:

- Unbind handling at `0x5780–0x57aa` forms response command `0x8005`, loads status 8, and branches to the response payload store at `0x54de`. Status 8 is `SL_STATUS_PERMISSION` in the retained vendor `sl_status.h`. The linked unbind path returns denial without a key-destroy call. The vendor weak callback returns zero, and the generated project selects no recovery application.
- `NcpCPC::HandleOpenEndpoint` at `0xf37c–0xf38e` passes the shared 802.15.4 endpoint ID 12 and zero flags into `open_endpoint.constprop.0`.
- `open_endpoint.constprop.0` at `0x18392–0x1839e` sets the endpoint encrypted flag to 1 when its ID is greater than 1. ID 12 therefore uses encryption. The binary retains encrypted transmit/decrypt handling. This verifies compiled endpoint configuration, not an actual radio handshake or traffic test.
- System/security negotiation is separate from the shared application endpoint; do not describe every wire byte as encrypted.
- Linker symbols place NVM at `[0xb4000, 0xbe000)` (40 KiB) and application vectors at `0x4000`. This is candidate layout evidence only; it does not establish compatibility with the existing bootloader or installed firmware's persistent storage. The section-size report includes NOLOAD heap/NVM reservations and must not be treated as simple physical RAM use.

See compressed `candidate/evidence/disassembly.txt.gz`, `endpoint-disassembly.txt`, `symbols.txt`, `section-sizes.txt`, generated `autogen/linkerfile.ld`, and retained `vendor-security-source` for review. The validation script asserts generated values and records binary evidence; the binary control-flow interpretation above was reviewed manually.

Hardware acceptance remains outside this offline assignment: verified board/bootloader and flashing/storage plan, explicit binding, matched/mismatched key behavior, shared Thread/Zigbee traffic, power-cycle persistence, recovery and rollback.
