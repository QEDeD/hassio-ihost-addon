# CPC connection-lifecycle observation

Prepared for one separately approved diagnostic window. No new firmware is built. Reuse the original full application-only GBL and mandatory original4.6.0 rollback. Production stays on its restored original software during preparation.

`capture-launch.py` wraps the existing flasher1.1.0 CLI. Only the RUN after a successful upload is extended. Earlier discovery launches, XMODEM, reset selection and flash error handling remain vendor code. It tees received bytes to a separate vendor CPC parser while preserving the bootloader parser and uses the same physical transport for writes; it opens no additional reader/connection.

- Query SECONDARY_CPC_VERSION at about0.25s and30s from RUN, each at most two attempts with1s response timeout and0.1s retry delay. Original2s bootloader-menu detection runs concurrently. Total launch observation bound36s; there is no new outer timeout on an active upload.
- Only CRC-valid system endpoint PROP_VALUE_IS replies for that version, with matching sequence and12byte value, count as success. Sequences0 and1 distinguish phases. Unsolicited reset notifications, wrong properties/endpoints, corrupt frames and stale replies cannot establish success.
- After capture CLI exits and releases the port, `probe-reopened.py USB_BY_ID` opens one fresh115200 connection through the existing vendor helper and queries sequence2. It cannot flash, reset, set properties or bind. Do not run it in parallel with capture or an app.
- Source hashes pin gecko_bootloader.py and cpc.py; package version1.1.0 and unmodified2s launch default are checked before work. Reuse the complete known wheel bundle (including serialx1.10.0). This is a local diagnostic adapter, not an upstream API change.
- DEBUG logs include arbitrary raw data and firmware upload bytes; keep them private. `LIFECYCLE` records provide phase/monotonic time, reply/timeout and byte counts. Expected settings in the marker are declarative; verify actual115200/no-flow settings and DTR/RTS operations in transport logs. Software settings do not measure pin voltages.
- Capture CLI exit0 means upload/observation completed, not that queries answered. Inspect both query_end results and launch_observation_complete. Reopened helper exits1 on timeout. Any missing completion/returned menu/lost connection is an incomplete observation, not evidence about firmware alone.

Tests use the actual pinned vendor classes with simulated transport, including split valid replies, real request bytes, wrong/stale/CRC-corrupt replies, silent bounds, discovery launch preservation, duplicate launch refusal, returned menu, disconnect and cancellation. They cannot prove physical transport timing. Full procedure: ../../CONNECTION-LIFECYCLE-TRIAL-20260920.md.
