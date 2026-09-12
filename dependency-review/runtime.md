> Source-review snapshot. The later test results and current remaining gates are
> recorded in [plan-and-results.md](plan-and-results.md); pending-test language
> below describes the state when this specialist review was written.

# Trixie runtime dependency impact review — 2026-09-12

The complete AMD64 build and loader inventory passed at 77287ce in [CI34707535921](https://github.com/QEDeD/hassio-ihost-addon/actions/runs/34707535921). No runtime incompatibility is demonstrated by that result. The most useful next evidence is actual upgraded s6/network-tool execution and a small socat client-family comparison. No application source change is justified by this review alone.

Evidence: trixie-upgrade-analysis-20260912.md, trixie-image-inventories-34707535921.json, trixie-installed-package-diff-34707535921.csv, and trixie-audit-34707535921.log in this directory; source inspected in trixie-investigation, readiness-ready and nat64-ready. No production, image execution, CI dispatch or source edits were performed in this review. Parent is independently preparing upgraded fixture runs; their results are pending and are not claimed here.

## Prioritized findings

### 1. s6 lifecycle must be exercised with the actual upgraded base

Measured s6-overlay 3.1.6.2 → 3.2.3.0, s6 2.12.0.2 → 2.15.0.0, s6-rc 0.5.4.2 → 0.6.1.0. App run scripts depend on s6-notifyoncheck, finish arguments, service readiness dependencies and the container exitcode/halt path. Overlay 3.2 removed its default startup timeout; effective HA image S6_CMD_WAIT_FOR_SERVICES_MAXTIME must therefore be recorded rather than inferred from upstream defaults. [Official release notes](https://github.com/just-containers/s6-overlay/releases/tag/v3.2.0.0).

Reuse test-otbr-s6.sh for original status, cleanup failure, bounded stall and timeout-finish behavior, and test-zigbeed-readiness.sh for listener ownership and fail/recover transitions. Both fixture Dockerfiles currently name /package/admin/s6-overlay-3.1.6.2 explicitly; merely swapping FROM is invalid. Preserve real upgraded /init and /run lifecycle while adapting that fixture path. Their stripped Supervisor hooks deliberately exclude full app service graph/configuration acceptance. A passing stub daemon is not a CPC/OTBR startup proof.

### 2. socat has a concrete address-family change worth comparing, not an established regression

Measured 1.7.4.1-3 → 1.8.0.3-1+deb13u1. Generic tcp:${network_device} in socat-cpcd-tcp/run now encounters the documented global IPv4 preference introduced in 1.8.0.1. Compare IPv4, IPv6 literal and IPv6-only name behavior before deciding whether an explicit family option is necessary. The old TCP-LISTEN already documented IPv4 default: do not misreport the new default as proven loss of dual-stack Zigbee listening. [Trixie manual](https://manpages.debian.org/trixie/socat/socat.1.en.html), [Bullseye manual](https://manpages.debian.org/bullseye/socat/socat.1.en.html).

Other mapped changes: 1.8 enables reuseaddr by default, but the production listener already requests it; this adds no demonstrated benefit. Default logging includes warnings and -d now exposes notices, so more bridge logs need not imply new failure. The changed -T0 interpretation does not apply because production does not set -T. PTY/raw/echo/link/ignoreeof and TCP fork options remain documented. Existing readiness tests prove passive listener ownership, not serial byte transfer or remote CPC reconnect.

Minimal isolated probes, suggested only (run in each exact image with --network none, no host mounts/devices/privilege; loopback remains usable):

```sh
# Substitute an inert echo endpoint for the serial endpoint only.
socat TCP-LISTEN:19999,reuseaddr,fork EXEC:/bin/cat > /tmp/listener.log 2>&1 &
listener=$!
# Before any client assertion, boundedly require ss output containing pid=$listener.
ss -H -ltnp 'sport = :19999'
timeout 3s sh -c 'printf "ipv4\n" | socat -T1 - TCP:127.0.0.1:19999'
# Record exit/output for comparison; do not assume old generic listener serves IPv6.
timeout 3s sh -c 'printf "ipv6\n" | socat -T1 - TCP6:[::1]:19999'
kill "$listener"; wait "$listener" || true

# Explicit IPv6 echo server is prerequisite to the generic client comparison.
socat TCP6-LISTEN:19998,bind=[::1],ipv6only=1,reuseaddr,fork EXEC:/bin/cat > /tmp/ipv6.log 2>&1 &
listener=$!
ss -H -ltnp 'sport = :19998'
timeout 3s sh -c 'printf "control\n" | socat -T1 - TCP6:[::1]:19998'
timeout 3s sh -c 'printf "generic\n" | socat -T1 - TCP:[::1]:19998'
kill "$listener"; wait "$listener" || true
```

Harness must poll ss/PID with a 3-second deadline, require exact echoed payload for positive cases and trap cleanup. If explicit TCP6 fails, report unsupported fixture IPv6 rather than a generic-client regression. Add an IPv6-only name via temporary container-local hosts entry if literal behavior matches. Test the production PTY-to-TCP command next only if these results differ; inert endpoints cannot establish radio protocol compatibility. Do not impose -0/-6 on production without observing and deciding the required behavior.

### 3. Firewall tools changed; backend did not

Measured iproute2 5.10.0-4 → 6.15.0-1, iptables 1.8.7-1 → 1.8.11-2, ipset 7.10-1 → 7.22-1+b1. Actual logs explicitly show nf_tables for both old and new iptables/ip6tables. Therefore this is not evidence of a legacy-to-nft migration.

Run existing test-otbr-firewall-kernel.sh against upgraded utilities: real set matches, scoped chain insertion/removal, duplicates, lock contention and foreign-rule preservation are meaningful. Existing tests/kernel/Dockerfile uses Bookworm, so its previous pass is not the Trixie gate. Add only the direct PR79 lookup check `ip -6 route show table openthread` in an isolated network namespace: it must recognize table 88 through /etc/iproute2/rt_tables.d/openthread.conf rather than error on the name. Empty output is valid. The [Trixie ip-route manual](https://manpages.debian.org/trixie/iproute2/ip-route.8.en.html) documents named tables. For optional NAT64, reuse pool/all-table conflict and synthetic packet fixtures separately; baseline PR79 built with those features off.

Kernel behavior remains supplied by the host. A GitHub runner pass does not establish HAOS kernel modules/features. No blanket conntrack flush or rules on host interfaces is appropriate.

### 4. AMD64 ABI risk is narrowed; ARM32 remains independent

Measured glibc 2.31-13+deb11u13 → 2.41-12+deb13u4 and libstdc++ 10.2.1-6 → 14.2.0-19. All five application executables were rebuilt and resolve their libraries. This addresses the immediate copied-binary/missing-library concern. Versioned C++ libraries preserve older symbol interfaces but newer-built binaries need not run on older libraries; retain complete-image rollback, not mixing native files between releases. [GCC ABI guidance](https://gcc.gnu.org/onlinedocs/libstdc++/manual/abi.html).

ldd does not prove lazy function binding, initialization, IPC or protocol behavior. Small no-radio CLI/version and isolated web-request checks in the built image provide better next evidence than another package list. ARMv7 must separately measure time_t and compile flags across CPC/generated Zigbee/OTBR: Debian t64 library package names do not prove custom source compilation used a consistent time ABI. Do not generalize AMD64 results to ARM. [Debian release issues](https://www.debian.org/releases/trixie/release-notes/issues.en.html).

### 5. Bashio/curl/jq need configuration-path checks, not feature adoption

Measured curl 7.74.0-1.3+deb11u15 → 8.14.1-2+deb13u4; jq 1.6-2.1 → 1.7.1-6+deb13u3; Bash 5.1 → 5.2. Bashio 0.17.0 → 0.17.5 is HA base source attribution: BASHIO_VERSION=0.1.0 in both images is not a valid release measurement.

The app obtains options, port mapping and primary interface through Bashio, constructs JSON for config/discovery, and logs from these paths. Official Bashio 0.17.2–0.17.4 notes change stdout/parent-stdout logging and fix log initialization. This can affect captured command output/error diagnostics. 0.17.5 fixes plural bashio::addons(), which is not the singular bashio::addon.port() interface used here; avoid assuming every release fix applies. [Release notes](https://github.com/hassio-addons/bashio/releases).

Existing firewall mocks replace Bashio functions, so their success does not validate new Bashio/curl/jq error handling. Minimal additional cases with actual installed Bashio and inert local API responses: valid primary interface, no primary, missing option versus false/zero, malformed JSON, HTTP error and refused connection. Assert stdout remains only the returned value, errors remain visible, and the caller takes its documented failure/fallback branch. No live Supervisor request is needed. Preserve existing error-response cases where available rather than write another framework.

Local read-only check: jq-1.7 selected eth1 from the exact `first(.interfaces[] | select (.primary == true)) .interface` filter with mixed primary entries. This supports syntax only and is not the target Debian 1.7.1 binary. [jq 1.7 manual](https://jqlang.org/manual/v1.7/). No used jq expression was found requiring new semantics. Curl package change alone establishes no need to change options or weaken certificate verification.

Netcat is OpenBSD in both installed inventories (1.217-3 → 1.229-1); PR79 removes ambiguity in package selection rather than introducing a new implementation. Its -z/-w interface remains documented. Test the exact REST readiness invocation against local open/closed ports, with an external timeout because baseline data/check lacks its own -w. [Trixie nc manual](https://manpages.debian.org/trixie/netcat-openbsd/nc.1.en.html).

## Stopping point

No demonstrated Trixie defect warrants source edits yet. Prioritize actual upgraded lifecycle/kernel fixtures already being prepared, the small socat family comparison, and real Bashio error-path output checks. After isolated application and architecture checks, physical shared-radio startup/restart/coexistence remains a separate acceptance gate. This review neither runs nor waives it.