# Hardware-test and rollback runbook

## Scope and stop conditions

This runbook tests the fork-only AMD64 Silicon Labs candidate built from broad
canonical head `186eac8354fdcab9c224ec840989da1fd86af882`.

> [!CAUTION]
> Do not start the candidate without a current backup, recorded original
> options, and a rehearsed rollback. Never run it at the same time as another
> process that owns the MG21, CPC, `wpan0`, or OTBR host-network state.

Stop and roll back immediately if any of the following occurs:

- the candidate enters a restart loop;
- the radio, Zigbee network, Thread network, or Home Assistant becomes
  unavailable beyond the agreed downtime;
- the host IPv4 or IPv6 `FORWARD` policy changes;
- owned chains, jumps, or ipsets duplicate or remain after a clean stop;
- an unexpected radio/OTBR ownership conflict appears;
- the exact image or environment cannot be confirmed; or
- recovery access or backup readiness is lost.

A pass from this runbook may be reported only as:

> The required issue #83 firewall/lifecycle matrix passed on the recorded hardware for canonical source 186eac8354fdcab9c224ec840989da1fd86af882.

That scoped result does not constitute complete broad-head hardware acceptance
and does not validate a future scope-specific upstream head.

## 1. Complete the private pre-test record

Record the following outside this public repository. Redact secrets from any
shared evidence.

1. Output or UI values for:
   - `ha info`
   - `ha os info`
   - `ha supervisor info`
   - `ha core info`
2. Home Assistant OS, Supervisor, Core, Docker, machine, and architecture.
3. MG21 model, exact Multi-PAN firmware build, local device path or network
   endpoint, baud rate, and flow control.
4. Original Silicon add-on repository, add-on ID, version, hostname, boot
   setting, and every installed option.
5. Every radio consumer:
   - Zigbee2MQTT or ZHA and its current TCP/serial endpoint;
   - the Home Assistant OpenThread/OTBR integration;
   - Matter Server or other Thread consumers;
   - standalone OTBR, multiprotocol, flasher, or diagnostic processes.
6. Thread dataset status and a simple known-good Zigbee test device/action.
7. Maximum acceptable downtime, rollback trigger, and local recovery access.

The candidate repository has a different repository-prefixed add-on ID,
hostname, and `/data` area from the original add-on. Preserve the original
installation and data. Record the candidate hostname after installation so a
Zigbee consumer can temporarily use:

```text
tcp://CANDIDATE-HOSTNAME:9999
```

## 2. Backup and rollback readiness

1. Create a current Home Assistant backup that includes Home Assistant and the
   original radio add-on.
2. Record the backup identifier, completion time, scope, storage location, and
   restore method.
3. Confirm the backup job completed successfully and the backup is visible at
   its intended storage location.
4. Export or copy the original add-on options privately.
5. Record the original Zigbee and OTBR consumer endpoints.
6. Confirm the original add-on remains installed and can be restarted without
   reinstalling it.
7. Confirm local console or equivalent recovery access is available if the
   network path fails.
8. Review the quick rollback at the end of this document before proceeding.

Do not continue if any item is incomplete.

## 3. Capture the clean host baseline

Use an approved HAOS host shell or equivalent diagnostic method. Merely
entering another add-on's container may show the wrong network namespace.
Record commands, timestamps, and complete output.

Capture at least:

```sh
date -Is
ip -details link show
ip -6 route show
iptables -S FORWARD
ip6tables -S FORWARD
ip6tables-save
ipset list -n
```

Record the first policy token from both `iptables -S FORWARD` and
`ip6tables -S FORWARD`. Those host-wide policies must be identical before,
during, and after every candidate transition.

The candidate owns only these named IPv6 objects:

```text
OTBR_FORWARD_INGRESS
OTBR_FORWARD_EGRESS
otbr-ingress-deny-src
otbr-ingress-deny-src-swap
otbr-ingress-allow-dst
otbr-ingress-allow-dst-swap
```

Before the test, establish whether any of them already exist. Do not delete
anything merely because its name matches. First identify the active owner. If
another owner or `wpan0` exists, stop that owner and recapture the baseline.

## 4. Install without starting

1. Confirm the package is public and the provenance record contains the
   anonymous pull result, remote manifest digest, config digest, and published
   branch SHA.
2. Add this exact repository URL:

   ```text
   https://github.com/QEDeD/hassio-ihost-addon#codex/otbr-candidate-feed
   ```

3. Refresh the store.
4. Verify that this feed exposes only
   **TEST/EXPERIMENTAL — Silicon Labs Multiprotocol (186eac8)**.
5. Verify `stage: experimental`, version `1.0.2`, and architecture `amd64`.
6. Install the candidate, but leave it stopped and disable Start on boot until
   the initial checks pass.
7. Record its add-on ID and hostname.

## 5. Transfer control of the radio safely

1. Stop or disable Zigbee consumers that continuously reconnect while the
   endpoint is changing.
2. Stop the existing Silicon multiprotocol add-on.
3. Stop standalone OTBR and every other process that can own the same MG21,
   CPC endpoint, `wpan0`, or OTBR firewall state.
4. Confirm all previous owners are stopped.
5. Confirm the original add-on remains installed and its data is untouched.
6. Recapture `wpan0`, the two `FORWARD` policies, owned chains/jumps, and owned
   ipsets.

Do not start the candidate until the old radio/OTBR owner has stopped.

## 6. Test issue #83 first: firewall disabled

Copy the original radio settings, then explicitly configure:

```yaml
otbr_enable: true
otbr_firewall: false
```

Keep the recorded device or `network_device`, baud rate, flow control,
backbone interface, and log level appropriate for the MG21 environment.

Start the candidate once. For at least ten minutes:

1. Watch the add-on state and complete log.
2. Confirm it remains running without a service or container restart loop.
3. Confirm the log does **not** contain the issue #83 failure:

   ```text
   ip6tables v1.8.7 (legacy): can't initialize ip6tables table `filter'
   Table does not exist (do you need to insmod?)
   otbr-agent ended with exit code 3
   ```

4. Confirm the log reports OTBR startup and successful discovery, including:

   ```text
   OTBR ingress filtering is disabled; allowing scoped Thread forwarding.
   Starting otbr-agent...
   Successfully sent discovery information to Home Assistant.
   ```

5. Verify the OTBR REST API responds on port `8081`. For example, from an
   authorized client that can reach HAOS:

   ```sh
   curl -fsS http://HAOS-IP:8081/node
   ```

6. Verify Home Assistant receives or retains OTBR discovery and can reach the
   border router through the OpenThread integration.
7. Point the recorded Zigbee consumer temporarily at the candidate hostname
   on TCP port `9999`, then start or re-enable that consumer.
8. Verify Zigbee continuity with both:
   - consumer/coordinator health; and
   - a known-good existing device report plus a command round trip.
9. Capture host netfilter state. Require:
   - unchanged IPv4 and IPv6 `FORWARD` policies;
   - exactly one `wpan0` egress jump to `OTBR_FORWARD_INGRESS`;
   - exactly one `wpan0` ingress jump to `OTBR_FORWARD_EGRESS`;
   - no duplicate owned chains or ipsets; and
   - no reference to `ip6tables-legacy` in the candidate failure path.

Any failure is a rollback trigger. Preserve logs and state; do not contact
upstream or post issue comments as part of this runbook.

## 7. Required lifecycle matrix

Complete the firewall-disabled row first. Then repeat with
`otbr_firewall: true`. For every cell, record timestamps, logs, REST/discovery,
Zigbee checks, both `FORWARD` policies, owned jump counts, owned chain counts,
and owned ipset names.

| Mode | Start | Add-on restart | Clean stop | Full HAOS reboot |
| --- | --- | --- | --- | --- |
| `otbr_firewall: false` | Required issue #83 first test | Required | Required | Required |
| `otbr_firewall: true` | Required | Required | Required | Required |

### Checks while running

In both firewall modes:

- the candidate remains running;
- OTBR REST and Home Assistant discovery work;
- Zigbee remains continuous;
- host IPv4 and IPv6 `FORWARD` policies equal the baseline;
- each owned chain, jump, and ipset exists at most once; and
- a restart never accumulates duplicate state.

With the firewall enabled, confirm the ingress chain contains the intended
deny/allow filtering rules. With it disabled, confirm scoped forwarding rules
exist without the ingress deny/allow filters. Do not require or permit a
host-wide `FORWARD` policy change in either mode.

### Checks after every clean stop

After the candidate reaches stopped state:

- the two candidate-owned chains are absent;
- both `wpan0` jumps to those chains are absent;
- all four candidate-owned ipsets are absent;
- `wpan0` is no longer owned by the stopped candidate;
- IPv4 and IPv6 `FORWARD` policies still equal the baseline; and
- no cleanup timeout, incomplete teardown, or restart loop is present.

### Checks after every reboot

Before rebooting:

1. Ensure the original radio/OTBR add-on is stopped and not set to start
   concurrently.
2. Select only the candidate as the intended owner for the reboot cell.
3. Preserve the pre-reboot state capture.

After HAOS returns:

- confirm the recorded HAOS boot completed normally;
- confirm only the intended candidate owns the radio and OTBR state;
- repeat REST, discovery, Zigbee, policy, chain, jump, and ipset checks;
- perform a clean candidate stop and verify complete teardown; and
- restore the intended Start on boot setting before the next matrix cell.

Two full reboots are required: one with each firewall mode.

## 8. OTBR disable/re-enable check

After the required matrix:

1. Start from a clean stopped state.
2. Set `otbr_enable: false` and start the candidate.
3. Verify Zigbee on port `9999` remains usable while OTBR REST/discovery is
   absent.
4. Verify no candidate-owned OTBR chains, jumps, ipsets, or `wpan0` remain.
5. Stop the candidate, restore `otbr_enable: true`, and repeat the
   firewall-disabled start/stop smoke test.

Do not deliberately start a second OTBR owner during this test.

## 9. Evidence and pass criteria

A complete result records:

- canonical source SHA and candidate branch SHA;
- registry manifest/platform and image configuration digests;
- HAOS, Supervisor, Core, machine, and architecture;
- MG21 firmware, connection, and radio options;
- original and candidate add-on IDs/hostnames;
- radio consumers and temporary endpoint changes;
- backup identifier and rollback readiness;
- logs for each lifecycle transition;
- REST/discovery and Zigbee results;
- before/during/after IPv4 and IPv6 `FORWARD` policies;
- before/during/after owned chains, jumps, and ipsets; and
- start, restart, stop, and reboot results in both firewall modes.

Pass only if every required check succeeds without manual netfilter repair.
Clearly label the result:

```text
The required issue #83 firewall/lifecycle matrix passed on the recorded hardware for canonical source 186eac8354fdcab9c224ec840989da1fd86af882.
```

This is not complete broad-head hardware acceptance. Complete broad-head
hardware acceptance additionally requires these remaining
[`RELEASE.md`](./hassio-ihost-silabs-multiprotocol/RELEASE.md) gates:

- local serial and TCP `network_device` coverage;
- multi-interface/backbone routing;
- 24-hour concurrent Zigbee/Thread load;
- RCP reset/link-interruption and source-match recovery; and
- two-owner Silicon/standalone contention testing.

It does not validate any future scope-specific upstream head.

## 10. Quick rollback to the original add-on

1. Stop the candidate immediately.
2. Disable its Start on boot setting.
3. Wait for stopped state and capture its final log.
4. Verify the candidate-owned chains, jumps, ipsets, and `wpan0` state are
   gone and both host `FORWARD` policies still equal the baseline.
5. If cleanup is incomplete, do not delete unfamiliar host rules manually.
   Keep the candidate disabled and perform the pre-agreed safe HAOS reboot
   before restarting the original owner.
6. Restore the original add-on's recorded options and Start on boot setting.
7. Start the original add-on only after the candidate is stopped and no other
   radio/OTBR owner is active.
8. Restore the Zigbee consumer's original hostname/endpoint and re-enable it.
9. Verify the original add-on, Zigbee coordinator, known-good device, OTBR
   integration, and Thread consumers return to their recorded baseline.
10. Keep the candidate repository installed only while evidence is being
    collected; remove it later if desired, after rollback is confirmed.
11. Restore the recorded backup only if the original installation or data was
    changed and ordinary restart/endpoint restoration does not recover it.

The rollback is complete only when the original add-on and consumers are
healthy, the original endpoint is restored, no candidate-owned network state
remains, and the host `FORWARD` policies match the pre-test baseline.
