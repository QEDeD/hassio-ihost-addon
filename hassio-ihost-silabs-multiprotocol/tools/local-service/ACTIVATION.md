# Proposed local-service activation and current-state recovery

Status: proposed; execution not authorized. This is the maintained, public-safe
version of the operator proposal. Backup IDs, interface/address assignments,
phone/accessory identities and approved windows remain in private task context.

## Outcome and choice

Enable a usable Thread border router with the focused HAOS18 compatibility fix,
preserving existing Zigbee operation and proving communication with a real Thread
accessory. Cross-subnet commissioning and network policy belong to the networking
workstream. The radio task supplies actual OMR, backbone and return-route evidence.

A supported same-app update carrying the exact fix is preferred if available.
The September 11 expanded upstream review found no released replacement for the
focused fix. iHost publishes only master, at 5a8d7dec067f9196ada5879f31f71cbf6d595bff;
this branch contains it. Release 1.0.2's current AMD64 registry digest exactly
matches make_context.py's pinned base. Refresh availability before migration.
Do not use the old broad candidate feed or add radio firmware/build-system changes.

The proposed immediate alternative is one operator-maintained local app using
the pinned release plus five focused files. It replaces the original as sole
radio owner and keeps one persistent private volume across subsequent starts.
Original remains installed but stopped, with boot/watchdog disabled. Accepting
that local maintenance obligation is a real user decision; otherwise wait for an
appropriate upstream update. The disposable four-minute trial is not a durable
commissioning service. No parallel owner or perpetual import mechanism is needed.

## Wider upstream activity reviewed, September 11

Coverage: all published iHost branches, all nine upstream PRs in all states,
issue inventory and relevant discussions, and branch inventories for all 30
public forks returned by GitHub. Divergent fork changes affecting Multiprotocol
or OTBR were inspected. Related review inventoried seven branches in Home Assistant addons, 17 in HAOS
and four in ot-br-posix, then examined relevant branch comparisons and PRs.
This is a bounded public-source review, not a claim about private development or
hardware validation of alternatives.

- [iHost PR 78](https://github.com/iHost-Open-Source-Project/hassio-ihost-addon/pull/78),
  Arno500/master at 03598f9b9c739d0293fa434f6899c1fa1efe5f7d, is open. It directly
  removes the global and legacy FORWARD policy calls and creates Thread chains
  in both firewall modes, but bundles NAT64, TREL, DNS and build changes. No
  reviews or status checks were recorded. Its unguarded chain creation and
  teardown do not establish our stale-state, partial-failure and bounded-cleanup
  acceptance properties. It is relevant prior work, not a validated replacement.
- [iHost PR 79](https://github.com/iHost-Open-Source-Project/hassio-ihost-addon/pull/79),
  Arno500/trixie at 4c7d63cf10ed0cf70f31c64257663c3bdd8b5983, is open and upgrades
  Debian/build dependencies without repairing the service firewall lifecycle.
- Other material forks do not supply a better compatible base: juliusrickert's
  1.1.0 starts from older 1.0.0 and adds NAT64 arguments while retaining the
  firewall path; bepvte's mainline OTBR/Trixie rewrite removes CPC vendor and
  MultiPAN build flags in favor of UART, so shared-radio compatibility is not
  established. Fiveol expands privileges/disables AppArmor without a lifecycle
  fix. The skypeachblue and antoniocifu standalone wrappers default to 1.0.0.
- [Home Assistant PR 4500](https://github.com/home-assistant/addons/pull/4500)
  already merged the same global-policy removal into standalone OTBR 2.16.6,
  commit f73db363abdf89b3bc4d1479220278f6ca708e63. Its current multiprotocol source
  still contains the offending calls. Multiprotocol automatic builds were
  [disabled in PR 4555](https://github.com/home-assistant/addons/pull/4555).
  The old alternate multiprotocol SDK branch has no firewall fix.
- [Home Assistant draft PR 4803](https://github.com/home-assistant/addons/pull/4803)
  is a broader host-input/output, multicast, routing and nftables redesign.
  Maintainer discussion flags Docker/iptables interaction. Its contributor's
  multi-router failure reports are not evidence of those failures here.
  [PR 4818](https://github.com/home-assistant/addons/pull/4818) proposes newer
  standalone OTBR binaries, not a multiprotocol update.
- [OTBR PR 3325](https://github.com/openthread/ot-br-posix/pull/3325) adds an opt-in,
  default-off nftables backend; adopting it requires build/runtime changes.
  Merged [PR 3517](https://github.com/openthread/ot-br-posix/pull/3517) and
  [PR 3521](https://github.com/openthread/ot-br-posix/pull/3521) provide additional
  Docker lifecycle precedent, not a released iHost package. HAOS's native Docker
  nftables migration remains [open](https://github.com/home-assistant/operating-system/issues/4588);
  do not confuse it with the iptables-nft compatibility backend already tested.

Decision: retain the exact released iHost base and narrow lifecycle overlay.
The review corrects any implication that no overlapping unmerged work exists;
it does not justify importing the broader changes. Existing real-traffic,
current-state recovery and final firewall-policy gates remain. No source/runtime
change, new trial authority, automatic monitoring or maintainer contact follows
from this review.

## September 12 native Supervisor fixture result

The operator-approved disposable app test passed on Supervisor 2026.09.0.
A separate inert app used only synthetic data: no radio mappings, host networking,
D-Bus, elevated capabilities, discovery or Supervisor API access. Production
radio, Zigbee2MQTT and Matter services remained started at final readback.

- Complete nondefault options survived a clean stopped version update; the app
  remained stopped until explicitly started, and its evolving data survived.
- Intentional refusal before data writes produced an error state even though the
  start API returned success. A subsequent successful start proved the refused
  attempt had not advanced the synthetic history. Always verify actual state.
- Native backup and partial restore selected only the fixture, explicitly excluding
  Home Assistant and other folders/apps. Restoration recovered the backed-up
  history and options, replacing a later synthetic generation. Hash checks passed.
- The fixture, its source directory and its backup were removed and absence verified.

An inherited radio healthcheck initially caused fixture startup errors. Disabling
it with HEALTHCHECK NONE still left this fixture in startup; an explicit synthetic
state-file healthcheck resolved the test lifecycle. This is a fixture limitation,
not evidence that the production candidate has that fault. Local Docker was
unavailable; fixture write/refusal logic was tested locally in Python, and actual
build/lifecycle/backup testing ran on Supervisor.

This discharges the generic native Supervisor data/options/backup acceptance gap.
It does not validate the actual candidate's radio initialization, two-source import,
manual OTBR integration transition, code-specific recovery image, or real peers.
Restoring older radio state remains unsafe; the fixture intentionally used no radio.
The next preparation is a concrete current-state-preserving candidate handover and
recovery check, followed by separate approval for the Zigbee interruption/activation.
No radio cutover was authorized by this fixture test.

## Pre-activation gates

1. Generate fixed/recovery contexts from the reviewed source. Validate both on
   the released runtime in isolated containers with no radio, host networking or
   production secrets: package schema/labels, full s6 graph, five runtime hashes,
   entrypoint refusal, normal state-preserving restarts with stub init, and
   same-volume sentinel survival while switching code. Confirm default automatic
   attach behavior and actual observation binaries. Both images now build, full s6 graphs compile,
   installed files match and 21 tests pass on released Python 3.9.2. Stub-init
   image switching preserves evolving synthetic data/options, and local-only
   DNS-SD resolution passes through the installed observer in both images.
   Normal /init, production multicast and real radio operation remain unverified.
2. In an isolated Supervisor test environment, verify stopped-app update and
   failure handling, options persistence, complete current-state backup and
   restoration characteristics. Do not run normal /init with a radio. Source
   contracts below do not replace this acceptance gate. A pinned, isolated
   Supervisor 2026.09.0 mocked rehearsal passed 15 lifecycle/options tests.
   Docker and save_data were mocked in that earlier rehearsal. The September 12
   native fixture test above now verifies generic persistence and backup/restore;
   candidate-specific recovery and radio behavior remain separate.
3. Prepare the supported options/reconfiguration client. Full option writes,
   authentication path, explicit Z2M endpoint and existing HA OTBR integration
   reconfiguration must be verified without editing .storage directly. Existing
   SSH access is to a separate container, not a host exec shell. Do not introduce
   privileged access or export credentials just to satisfy these steps.
   Installed SSH app 10.4.0 has manager role, but its older Bashio helper puts
   credentials/body in curl arguments and trace/debug output; do not use it for
   writes. Its CLI has no options command. Prefer the existing authenticated
   admin UI (Core supervisor/api WebSocket), preserving the complete options
   object. Installed curl supports stdin configuration as a possible alternative,
   but that authenticated construction has not been tested. Core's HTTP proxy
   excludes the options path; ha-api POST /api/hassio/addons/.../options is not
   supported. A fresh admin Core supervisor/api WebSocket read now verifies
   complete installed-app options are available without the Bashio workaround.
   Supervisor version matches the pinned source; original radio app and Zigbee
   consumer are running, with OTBR disabled. Full options were retained privately.
   The native backup catalog is readable but does not establish a current backup
   or successful restoration. That September 11 read made no options write, backup or service transition. The authenticated read-path gate is discharged;
   generic native persistence/backup acceptance now passed as described above;
   current radio-state recovery remains separate.

4. Resolve the discovery observation gap in README. Collect actual SRV targets,
   ports and AAAA from the relevant links; management REST/WebSocket endpoints
   are not accessory advertisements. No arbitrary Supervisor container-exec API
   exists. Prepackaged observation uses the app's own namespace and local socket.
5. Obtain a concrete execution window only when packages, recovery, observation
   and participant details are reviewable. The historic24h testing permission
   expired; later coordination/SSH permission does not renew production authority.

## Proposed approved handover

Before interruption, confirm current owner/options/versions and two fresh
correlated physical Zigbee baselines; confirm native backup and external VM
recovery availability. Stop Z2M, then original radio service. Disable original
autostart/watchdog and take a NEW verified stopped-state native backup.

Import only newer retained Thread state from the post-trial candidate backup and
fresh Zigbee state from that new original backup. Check no newer Thread activity
has superseded the retained source. The importer now implements this two-source
transfer and refuses unsafe/interrupted imports; private hashes do not prove
currentness. The original importer cannot handle the newer image-containing
candidate archive and must not be reused unchanged.

Start the replacement first with OTBR off and explicit Z2M endpoint; require the
physical reads. From the first attempted runtime handoff onward, its volume is
authoritative for both radios. Never assume an unsuccessful startup left counters
unchanged. After privately verifying the intended Thread dataset, enable OTBR
using ordinary release startup and require attached role, fresh Zigbee reads and
unchanged global/foreign firewall state. Initial firewall=false reproduces the
reported bug and historical live trial; it is NOT accepted permanent policy.
FortiGate filtering does not replace all host/Thread ingress protections.

Observe at least ten minutes after readiness, failing earlier on a concrete
fault. At a proposed15-minute initial decision point, either prerequisites and
service tests passed or recovery starts; this is not a guarantee that recovery
will finish in15 minutes. Collect actual OMR prefix from border-routing/network
data, never from dataset mesh-local/RLOC. Collect correct-namespace host addresses,
all IPv6 routing tables/rules and return path toward the phone's selected subnet.

The current network proposal uses a local-only site ULA and selected RIO routes,
with RA default-router lifetime0. No IPv6 Internet is assumed. Therefore absence
of an IPv6 default route alone is not a failure: require the effective specific
route to the phone subnet, and the opposite route to actual OMR. Observe
forwarding, accept_ra, accept_ra_defrtr, accept_ra_rtr_pref, accept_ra_rt_info_min/max_plen,
accept_ra_pinfo and autoconf on the backbone. Linux forwarding normally disables
kernel RA acceptance unless accept_ra=2; kernel RIO acceptance additionally depends
on route-information settings. HAOS also uses NetworkManager; inspect its connection
policy and effective routes before attributing missing routes to kernel sysctls.
A sysctl value alone does not prove how the managed host processed advertisements.
Values and installed routes are evidence, not
permission to write sysctls. Do not reuse Docker ULA as a site/Thread prefix or
claim a generated site prefix is allocated. Validate actual phone route acceptance
and necessary ICMPv6 with the networking owner.

Core 2026.9.1 has no OTBR options/URL-reconfiguration flow. Supervisor discovery
identity is generated per app slug/service, so importing Thread state into a new
slug cannot retain the old integration identity. An explicitly approved transition
must remove the old OTBR entry and add the new router through supported setup.
Removal has no OTBR dataset reset/delete hook, but adding a router without an
active dataset can create/import a dataset and enable it. Automatic hassio
rediscovery runs that setup without a confirmation form. Both preparation images
therefore omit the discovery service from the s6 user bundle. Verify the intended
active dataset privately before manual integration setup; leave automatic
discovery disabled. This safeguard is verified in both compiled service bundles.
No integration flow was executed. Source:
[Core OTBR flow](https://github.com/home-assistant/core/blob/2026.9.1/homeassistant/components/otbr/config_flow.py),
[removal behavior](https://github.com/home-assistant/core/blob/2026.9.1/homeassistant/components/otbr/__init__.py),
[Supervisor identity](https://github.com/home-assistant/supervisor/blob/2026.09.0/supervisor/discovery/__init__.py).

After separate network approval and acceptance, commission the confirmed Thread
accessory with the confirmed phone on its chosen IoT SSID. Require actual remote
Thread communication and Matter operation alongside Zigbee; historical leader/
broadcast activity with zero peers is insufficient. A controlled same-app restart
must recover both before auto-start/ongoing operation is accepted. Whether a
successful candidate remains running and the final host firewall mode must be
explicitly agreed. Do not move the phone or backbone as an implicit workaround.

## Recovery, verified source contracts

Supervisor version verified for this installation:2026.09.0. Its
[pinned lifecycle code](https://github.com/home-assistant/supervisor/blob/2026.09.0/supervisor/apps/app.py#L971)
shows update builds/pulls before stopping; rebuild removes container/image before
building. Rebuild's finally block attempts startup when entry state was started,
even after failure. Neither promises automatic working-image rollback. Restoring
an old native backup replaces current data and is not code-only recovery.

Preferred recovery after ANY new-app radio execution is to stop Z2M, disable OTBR
in the SAME app, preserve its latest state in a verified native backup, then
restart its unchanged released Zigbee binaries against current /data. Keep the
original app stopped. If the new app never attempted radio initialization, the
original with unchanged state/settings can instead be resumed. A failed import
alone does not transfer ownership.

Exact Supervisor preparation/recovery API sequence, NOT execution authority:

1. GET `/addons/<slug>/info`; retain current full options privately.
2. POST `/addons/<slug>/options` with the FULL existing `options` dictionary,
   changing `otbr_enable` to false, plus top-level `boot: manual`,
   `watchdog: false`, `auto_update: false`. This saves without restarting;
   options writes replace, rather than merge, the dictionary.
3. Stop consumers and POST `/addons/<slug>/stop`; verify stopped. Take/verify a
   native current-state backup before code changes where possible. If current
   state cannot be retained, stop and escalate rather than restore stale state.
4. For an unavoidable code change, keep the same local app slug and source
   directory, stage the reviewed recovery context, reload the store, and prefer
   a distinct recovery package version through
   POST `/store/addons/<slug>/update` with `backup:false, background:false`.
   Existing options/data persist; recovery entrypoint refuses OTBR enabled.
   Same-version rebuild is possible but removes the current image first and
   therefore is not the preferred recovery path. Prebuilding on Desktop is not
   proof the recovery image is installed/available on HA.
5. Verify version, stopped state, complete options and current private data before
   explicitly starting. No uninstall/remove-config and no restoration of older
   state. A native backup of latest data remains a recovery aid, not proof peer
   counters can be rewound.

[Manager](https://github.com/home-assistant/supervisor/blob/2026.09.0/supervisor/apps/manager.py#L250)
requires different installed/store versions for update and matching versions for
rebuild; force does not bypass that check. [Options API](https://github.com/home-assistant/supervisor/blob/2026.09.0/supervisor/api/apps.py#L307),
[store API](https://github.com/home-assistant/supervisor/blob/2026.09.0/supervisor/api/store.py#L62)
and [persistent data](https://github.com/home-assistant/supervisor/blob/2026.09.0/supervisor/apps/data.py#L53)
support the sequence. Exact installed CLI flags and authenticated invocation are
still prerequisites; there is no arbitrary image-version rollback/exec endpoint.

Require successful baseline Zigbee reads and a five-minute follow-up. One extra
same-app restart may be included in explicit approval; September8 showed recovery
after one extra restart but did not isolate the cause or prove counter-safe
rollback for every device. If it fails, retain state/evidence and escalate. Do not
flash, reset, re-pair, restore an old VM snapshot or switch to the stale original.
Later migration back to the original needs its own current-state transfer plan.

## Readiness, authority and effort

Current state: package/importer/observations implemented locally; both images build,
s6 graphs compile and 21 tests pass under released Python 3.9.2. Synthetic
same-volume image switching and installed local-only DNS-SD checks pass; 15 mocked
Supervisor lifecycle/options tests pass. Generic native Supervisor persistence/backup integration passed the September 12
fixture test. Actual radio options/integration transition, candidate recovery, normal
radio startup and real-peer behavior remain unverified. No production radio
configuration was changed; the disposable Supervisor fixture was removed. The proposal is maintained here; private operational mappings
remain outside Git. Approval for peer coordination only permits sharing this work.

A future approval request must name the exact package/window, temporary Zigbee
outage, stopped backup/two-source import, sole-owner and endpoint changes, Thread
activation, observation, current-state-preserving recovery and permitted restart,
including state/counter uncertainty and whether to leave the service running.
Network changes, commissioning/actuation, firmware and snapshot restoration are
not silently bundled. Do not ask for execution approval while hard gates remain.

Planning range before implementation was2â€“4h agent effort plus20â€“60min overlapping
local build/test runtime; the Docker startup blocker is now resolved. Native
Supervisor recovery integration and control readiness dominate remaining uncertainty. Human decision/approval10â€“20min and physical
commissioning5â€“15min are separate from an initial30â€“45min live observation/recovery
budget. The September 12 fixture now discharges generic native persistence/backup testing;
remaining candidate-specific recovery and radio validation determine further effort. Stop/reassess if reliable recovery requires
privileged machinery disproportionate to this fix.

References: [HA app persistence/configuration](https://developers.home-assistant.io/docs/apps/configuration/),
[local app testing](https://developers.home-assistant.io/docs/apps/testing/),
[Linux IPv6 sysctls](https://www.kernel.org/doc/html/latest/networking/ip-sysctl.html),
[upstream release configuration](https://github.com/iHost-Open-Source-Project/hassio-ihost-addon/blob/master/hassio-ihost-silabs-multiprotocol/config.yaml).
