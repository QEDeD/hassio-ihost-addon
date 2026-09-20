# Independent full-functional trial review — September20

Fresh-context GPT-6 Astra/high reviewer review_full_functional_trial inspected the successor, historical recovery procedure, actual binding wrapper and recovery build/link evidence without live calls or mutations.

Result: reasonable after two corrections, both incorporated before execution:
1. Exclude R1 completely. Recovery22c4 build applies explicit-unbind/UART patches only, with linked stock sl_cpc_drv_uart.c.obj and restart_dma0x5b88 (map4718–4720). Exact small-image physical failure is untested, but it retains the suspect implementation and is not a dependable optional branch.
2. Explicit post-binding terminal fallback: stop, preserve latest whole stores/CPC independently, common prepare while stopped, original4.6.0 firmware and0.2.3 host once, saved run options, fresh identity/traffic verification. No R1/rebind/marker deletion/candidate retry.

Review confirmed no additional host-wrapper blocker: incomplete binding guards normal run/repeat attempt. Keep encryption evidence plus bidirectional traffic, durable key/markers, actual store selection, coherent backup claims, identities/restart/policies. Prebinding recovery success does not demonstrate old-radio compatibility with candidate PSA storage; this accepted hardware uncertainty remains. Do not redo completed offline tests to substitute for hardware evidence.
