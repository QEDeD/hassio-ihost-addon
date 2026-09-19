# CPC binding-key format compatibility — 2026-09-19

The candidate startup preflight rejected the key format produced by its own pinned CPC4.9.1 ECDH binding implementation. This was found by reading the actual vendor writer/reader while preparing the binding procedure, before any production binding.

At CPC commit `87f6dbda4eef05e4538589c195099c3daf8f6f6b`, `security/private/keys/keys.c:414–416` writes 32 hexadecimal bytes followed by one NUL byte. The reader at lines546–568 uses getline/strlen, optionally strips one LF or CR, then requires 32 hexadecimal characters. Source: https://github.com/SiliconLabs/cpc-daemon/blob/87f6dbda4eef05e4538589c195099c3daf8f6f6b/security/private/keys/keys.c

The corrected preflight accepts exactly 32 hexadecimal bytes, optionally followed by ONE NUL, LF or CR. It does not normalize or rewrite a key. Embedded NUL, repeated terminators, CRLF, trailing data and truncated keys remain rejected. Existing ownership, permissions, file-type and symlink checks remain.

## Verification

- Positive/negative 20-case suite passes in a disconnected container based on image `f13e3adaea844f48f9e62b78ef92571a2c2b6790b3bc9da9799098638bf2e115`, with only the two changed Python scripts copied in. Exit 0; valid and invalid key bytes unchanged; missing file not created; key material absent from diagnostics.
- Negative control: new tests against that image's old preflight exit 1 on the terminal-NUL fixture. This confirms the suite detects the real format mismatch.
- Containers `sdk2026-key-format-20260919` and `sdk2026-key-format-old-20260919` are stopped. Only synthetic keys were used; no radio, network or production mount.
- This source fix must be included in the next candidate image. It does not establish a completed ECDH exchange or encrypted physical endpoint operation.

To reproduce offline in a Linux container, put the adjacent checker and test script in the same directory and run `python3 test-key-preflight.py`. No external Python packages are needed. The Linux permission/FIFO checks are intentional.
