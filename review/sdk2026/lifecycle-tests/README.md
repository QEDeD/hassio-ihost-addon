# Real-s6 CPC key-failure lifecycle validation

The fixture runs the candidate image's actual /init, s6-supervise, CPC config generator, CPC run, CPC finish and readiness FD. It uses network none, no devices, and synthetic options/key data. Bashio's existing local configuration cache supplies options without Supervisor. The fixture excludes the Supervisor banner and OTBR/socat enable hooks and narrows the user bundle to CPC plus its config dependency. No shutdown/control binary is replaced.

## Discovered failures

Image 074fd67d58a890895675180a7b7ce2f4b4f3dccaade7f0ba86fbac9744fe50a0: the key preflight fails before /dev/shm/cpcd exists. The original finish script's unguarded rm aborts under Bashio errexit before requesting container halt. Both missing/malformed fixtures repeat nine preflight refusals during an eight-second observation window and remain running. The test then stops them. This establishes a retry loop in that window, not an indefinitely observed lifetime.

Image 367c32916fe8c8d27c48709e81340974d41b9f511716611a49beff226a8f874b guards cleanup, but halt alone still leaves s6-rc waiting for startup readiness while s6-supervise restarts the service. Both cases again repeat nine times in eight seconds. See baseline-074fd/ and final-367c3/.

A fixture-only probe adds exit 125 after halt in the existing fatal nonzero/non256 branch. Both cases then refuse exactly once and exit container status 1, without key mutation, key-marker logging, or a CPC daemon start. See probe-exit125-lf/. This uses the documented s6 permanent-startup-failure mechanism: finish exit125 prevents restart and emits the failure notification needed by readiness waiters. [s6-supervise documentation](https://skarnet.org/software/s6/s6-supervise.html)

The candidate runtime/cpcd-finish now carries that narrow fix. Normal exit and signal-exit branches are unchanged. Final assembled-image results must be recorded separately below.

## Reproduction

Run run-lifecycle.ps1 -Image IMAGE_TAG. The script resolves the image ID once, tests missing/malformed keys in separate network-isolated containers, captures logs/status/hash evidence, and stops retained fixtures. A pass requires container exit nonzero, one preflight refusal, no synthetic-key marker in logs, no CPC start log, and unchanged key existence/content hash. Optional FinishOverride is for explicit fixture-only hypotheses; final-image acceptance must omit it.

## Limits

No physical radio/CPC session, actual Supervisor, final product-wide service startup, or production provisioning is tested. The original Supervisor-less attempt failed in config generation before preflight; supervisor-unavailable.log is retained and is not counted as key lifecycle evidence. probe-exit125/ failed due to CRLF in the temporary shell override; probe-exit125-lf/ is the corrected hypothesis run. No key-parser unit suite was duplicated.

## Final assembled image: PASS

Final image sha256:7f6104879bfe004823b03c3db5ba67d90ea1366d854372bba1732baa1e250f6b passed both cases without a finish override. Each logged exactly one preflight refusal, then exited status 1. Missing-key absence and malformed-key SHA256 were unchanged; neither synthetic key contents nor a CPC daemon start appeared in logs. Results: final-permanent-failure-fixed/results.json and per-case logs/state. Rebuild evidence: ../evidence/full-image-permanent-failure-fixed.log.

Direct invocations of that final image's finish script with arguments 0 0 and 256 15 both returned status 0 under S6_KEEP_ENV=1. This checks the preserved normal/signal finish branches; it is not a full healthy-radio shutdown test. The actual real-s6 failure tests use no finish override and no replacement shutdown machinery.
