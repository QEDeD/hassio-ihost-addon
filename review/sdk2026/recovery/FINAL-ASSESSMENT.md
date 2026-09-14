# Final preparation assessment — 2026-09-14

## Outcome: demonstrated recovery obstacle

The offline preparation has produced an application-only candidate, an authoritative matching rollback candidate and a current directly accessible host backup. It has NOT established a recoverable production-radio trial. Do not flash, change the bootloader, bind, erase or start the candidate on the production dongle on the strength of these checks.

## Completion audit against the requested proposal

| Requirement | Inspected evidence | Result |
|---|---|---|
|1. Rollback firmware and matched host|rollback/README.md and GBL inspection; HOST-STATE.md; BACKUP-20260914.md|Official model/CPC/baud-matched artifact obtained; exact installed firmware and complete running host-image identity unproven. Current host settings/data backed up.|
|2. Persistent state|Current backup nested members; generated NVM config/linker; SDK CPC persistent import|Host Zigbee/Thread/Matter data covered. Candidate radio key/NVM mapped. Baseline radio layout and full calibration/manufacturing-state restoration unproven.|
|3. Existing bootloader compatibility|Actual1.12.00 probe; candidate GBL tags/application properties; vendor packaging|Application-only GBL3 prepared without bootloader/SE update. Actual bootloader policy, acceptance and launch of candidate untested.|
|4. Flash/startup/downgrade|Package address comparisons; candidate startup/PSA code|Payload avoids candidate NVM. Startup/binding can write persistent radio state; old firmware behavior and downgrade compatibility unknown. No unsupported claim that storage is necessarily destroyed.|
|5. Actual package|firmware/package README, vendor parse, independent ELF/SREC comparison, repeat hash|Completed offline; no hardware acceptance implied.|
|6. Deployment/recovery sequence|INSTALLATION-PROPOSAL.md; protected host backup; peer coordination|Service order, binding constraints and stop conditions specified conditionally. Exact executable production flash/recovery commands remain deliberately incomplete because a supported radio-state recovery path is not established.|

The objective allows this demonstrated-obstacle outcome. This is preparation closeout, not upgrade completion or production approval.

## Additional evidence closing the serial-readback question

Actual probe.log shows only upload gbl, run and ebl info. Reviewed universal-silabs-flasher Gecko protocol implements those operations and firmware upload, not a flash/NVM dump. Silicon Labs standalone UART documentation describes the upload protocol. No supported readback-and-restore route through our current serial connection was found. This does not prove hidden/custom commands or physical debug access impossible. Commander debug-probe memory commands must not be presented as USB serial capabilities.

Sources:
- ../bootloader-probe/probe.log
- https://raw.githubusercontent.com/NabuCasa/universal-silabs-flasher/dev/universal_silabs_flasher/gecko_bootloader.py (reviewed2026-09-14; moving branch)
- https://docs.silabs.com/zigbee/latest/using-gecko-bootloader-with-zigbee/02-using-the-gecko-standalone-bootloaders

The full, untruncated Git tree for SONOFF flasher commit136ab2fe736a1e5e9c880c2334d2c95adf1e2f25 was inspected through GitHub API. It contains the matching compiled GBL and other model GBLs, but no .c/.h/.ld/.map/.slcp/.slcc/.elf/.out build inputs. Existing public artifact metadata does not supply the missing baseline storage facts. This scopes the negative finding to the inspected repository, not every possible source.

## Smallest next action

Request the matching firmware build/storage configuration and bootloader policy from SONOFF. No message has been sent; publication remains outside this goal. The required facts are the old NVM3 region and initialization behavior, PSA/key layout, calibration/manufacturing-token preservation, bootloader update policy and a supported state-preserving rollback procedure for SDK2026.6.1. Exact installed-image equivalence must remain an assumption unless provenance/readback establishes it.

Alternatively use a spare ZBDongle-E for a bounded hardware trial while leaving production untouched: confirm its identity/bootloader; use a disposable network; exercise candidate upload, launch, encrypted binding, reboot persistence and old-firmware rollback. This can establish hardware/software feasibility, but cannot by itself prove preservation of this production radio's existing state. Physical-debug recovery would require additional hardware/access and verification of read protection and covered regions; no unlock/erase operation is implied.

## Decision

Keep Gecko1.12.00 and existing production firmware unchanged. The9 prepared upstream contributions remain separate. All new preparation commits are local only. Host backup coverage has improved; radio recovery remains the limiting evidence gap. Further repetition of build or parser tests cannot resolve that gap.
## Independent final review
The rollback reviewer challenged the closeout separately and agreed that the permitted demonstrated-obstacle outcome is supported. The live trial remains unready: production radio state preservation/restoration, candidate hardware operation and actual restore testing remain unverified. No exact flash commands are claimed to resolve those gaps.
