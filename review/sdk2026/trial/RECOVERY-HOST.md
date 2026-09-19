# Recovery-only host wrapper (offline artifact)

The recovery image has the same app slug and preserves its private /data. It refuses normal startup. No production install or radio operation has been performed.

- `recover-unbind`: requires the image-owned approved serial device, 115200/no flow, compiled encryption ON, no network device or tracing, and no incomplete state import. Config rendering finishes before radio access. A durable `/data/cpc-recovery/unbind-attempt` precedes one CPCd `--conf /usr/local/etc/cpcd-recovery.conf --unbind` request, bounded to 120 seconds with process-group cleanup. Exit zero and the exact newline-terminated INFO success line are both required. Only then is `unbind-result` durably recorded. Existing attempt/result refuses every repeat. The wrapper never reads or replaces `/data/cpc/binding.key`.
- `archive-binding`: separately selected; never follows unbind automatically. Exact valid attempt/result and no import pending are required. It refuses missing/symlink/unsafe CPC directory, existing archive, or previous archival intent. A durable archive attempt precedes atomic same-filesystem rename of the entire `/data/cpc` to `/data/cpc-archive-before-rebind`, followed by fsync of `/data`. Unknown files remain intact. No new CPC directory, radio process, bind, init, export, retry, or cleanup occurs. An uncertain fsync leaves intent and evidence for explicit review.

Recovery firmware permission, independently stopped consumers, a recent protected native backup, app auto-start/watchdog settings, correct image/options transitions, and return to the intended normal radio firmware remain external procedure prerequisites. The image cannot prove which firmware is connected. “Unbound confirmed” includes the vendor already-absent-key success case; it does not claim a key was newly deleted.

Vendor evidence: CPC daemon commit `87f6dbda4eef05e4538589c195099c3daf8f6f6b`, `security/private/thread/security_thread.c` lines 59–60 skips the host binding-key loader in MODE_BINDING_UNBIND; `protocol.c` unbind response handling accepts success or not-initialized, printing the exact confirmation consumed here.

`make_recovery_context.py` reuses the normal generator's pinned helper source and verified base image. It adds only the separate entrypoint, recovery marker and recovery schema, and disables healthcheck. Normal wrapper modes remain unchanged; its process helper gains only an optional success-pattern argument with the old default retained.

Offline validation: all 32 normal tests passed after the helper change; all 23 recovery tests passed against the packaged recovery image (real candidate tempio, synthetic state, fake CPC, no radio or network). Tests cover exact arguments, state preservation, marker parsing, bounded failures, no replay, private locks, fsync failures, output suppression, distinct archival, unknown-file preservation and symlink refusal. Shared normal tests additionally cover parent SIGTERM and descendant cleanup. Real radio unbind and HA Supervisor update remain untested.

Current artifact: `local/otbr-sdk2026-recovery:0.3.2-sdk2026-recovery-unbind`, image ID `sha256:048dda7c6872f102376dbd2a83aeaa8d93baa1300b42f4ba667cbd82f05cec27`.
Context: `C:/Users/Kristoffer/Git/otbr/sdk2026-recovery-archive-context`.
Base: `sha256:eb72da990dd231d4cd30134f8af8fb162e7cca2330700635b375c99819d61aea`.
Previous local 0.3.1 recovery artifact lacks archival; use 0.3.2 for review/integration. No artifacts were published.
