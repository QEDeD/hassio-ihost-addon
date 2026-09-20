# Connection-lifecycle test result — September20,2026

The authorized existing full SDK firmware was uploaded once, observed, and replaced once with original4.6.0. Original app0.2.3-ordered and Zigbee2MQTT are running; identities/state, representative Zigbee/Matter responses and cleanup pass. Recovery closeout completed13:11:04UTC after325seconds observation, with no newly unavailable Zigbee/Matter devices. No binding, unbind, candidate host, network/channel command, erase, bootloader/SE change or additional diagnostic cycle occurred.

## Diagnostic result

A valid unsolicited CPC startup notification arrived about62ms after RUN. The first version request was sent at0.251s on the same still-open connection. Its retry also received no bytes. Queries at30.028s and after reopening likewise received zero bytes, each with its bounded native retry. The adapter completed both launch phases; the reopened probe exited1 for timeout. No parser-error, unexpected disconnect or returned-bootloader-menu failure was reported. Raw transport logs remain private and their hashes are recorded in the sanitized evidence.

| Phase | Request sequence | Result |
| --- | ---: | --- |
| Early, same launch connection |0|Two requests; zero response bytes|
| At30seconds, same connection |1|Two requests; zero response bytes|
| After close/reopen |2|Two requests; zero response bytes|

Closing/reopening is therefore **not a necessary trigger** for this observed failure. Nor does a30second idle delay explain its onset: the first request at250ms was already unanswered. This does not prove an earlier request could never succeed, identify where execution stopped, or rule out additional serial-transition effects. One startup transmission still does not establish that RX works, TX completion was handled, or CPC processing continues. The next useful diagnostic distinguishes those paths; repeating this lifecycle or component-only matrix would add downtime without answering a new question.

## Recovery

First writer stop13:00:11UTC. Coherent stopped archives, including actual Z2M/HA storage and Matter/radio state, independently copied and verified13:00:42. Core/Matter restarted13:01:06. Old4.6.0 control passed both version queries13:01:24. Candidate upload/capture13:01:37–13:02:45; reopened query13:03:02–04. Latest stopped radio archive was independently copied; all7 regular files match the initial archive exactly. A local filter initially assumed /data/ rather than data/ paths; correcting only that filter verified equality, without another backup/flash.

Mandatory rollback began13:03:37, aboutT+3m26, and completed13:04:34. Restored4.6.0 control passed both queries13:05:03. Original radio/Z2M restarted13:05:29/38; original policies restored13:05:38. Radio-service interruption was about5m27s. No stale host state was restored.

The non-actuating Zigbee read returned currentLevel1 at13:06:13; ALPSTUGA Identify returned Success(0)13:06:14. Changing Matter measurements resumed. Coordinator identity, PAN/extended PAN, key, channel25 and HA Thread dataset match the fresh stopped backup. Original app versions/options/boot/watchdog/update policies match. Temporary runtime removed13:08:22, all113 original package versions restored.

One previously intermittent stue_vaeg_spisebord bulb was already offline before this test and is included in the baseline. The final recovery snapshot has one newly unavailable entity: binary_sensor.rikkes_iphone_camera_motion, registry platform mobile_app. Its cause is not established; it is not a newly unavailable radio device. It remained unavailable at closeout; do not claim all HA entities match baseline. Restored radio logs retain startup mDNS/fragment-reassembly warnings and Z2M pings to unavailable devices; reviewed Matter logs contained no warning/error lines. No repeated new radio failure was observed during the bounded interval.

## Preparation deviation and prevention

Before any radio stop, staging mistakenly passed the entire cached APK bundle, upgrading libcrypto3/libssl3/xz-libs in Terminal & SSH. The original-version assertion caught this. A standard SSH-app restart restored its original image and all113 exact package versions, verified12:57:49; Core/radio/Z2M/Matter stayed running. The HA API proxy restart attempt returned401 without mutation; the supported Supervisor CLI restart succeeded, with expected SSH disconnect.

Corrected staging selected **only package names absent from `apk info`**, installed those11 APK files under the temporary virtual group, and verified every original name/version remained present before proceeding. Never glob the whole cached APK directory: some bundled dependencies are newer than the installed SSH image. The installation log and pre/post inventories remain private. Use the demonstrated missing-package filter and fail before any service window if existing versions change.

A local WSL search command also failed because shell quoting treated regex alternatives as commands; a local shutdown invocation was rejected for missing interactive authentication. It did not reach PVE or HA. Subsequent record inspection used literal-path Python reads. Do not pass regex alternation through the Windows-to-WSL shell boundary without argument-safe handling.

## Evidence and authority

Sanitized evidence: evidence/connection-lifecycle-result-20260920.json. Private authoritative events/logs/backups: /home/wsluser/.local/share/ha-recovery/sdk2026-lifecycle-20260920; HA /share/codex-sdk2026-lifecycle-20260920. Adapter preparation/review remains at5a91600; firmware artifact unchanged. This exact trial has been executed once and must not be replayed after compression. Operator clarified current3hour permission covers HA configuration and firmware testing; retain15:21UTC end and existing recovery exclusions. Further work must answer a new question and remain within actual authority; no speculative repeat or unlimited recovery.
