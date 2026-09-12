# Optional NAT64 draft validation

This draft adds no production deployment or release-version claim. The separate
investigation compiled exact pinned vendor OTBR with NAT64/upstream DNS, passed
the native NAT64 test, and loaded it against released AMD64 libraries while
preserving CPC/Zigbee hashes (run 34698275480). That does not validate this draft's
runtime integration. Virtual-radio DNS/NAT64 baselines and cross-interface DNS
acceptance remain separate gates.

Local draft checks cover: interface/route pool conflicts (including other tables,
exact/narrower/covering routes), default-route allowance, failed inspection,
scoped IPv4 rules, partial setup rollback, duplicate reconciliation, changed
backbone, foreign rules/marks preserved, shared IPv4/IPv6 cleanup deadline, CLI
Error text despite exit zero, missing completion and timeout failure. The inherited
IPv6 mock suite also passes. These are mock/source checks, not packet tests.

The existing private otbr-agent/data/check retains its socket and REST prerequisites,
then applies NAT64/DNS configuration within an 8-second total deadline before
returning success. s6-notifyoncheck stops checking after success and starts a fresh
checker for each supervised daemon incarnation. This is startup configuration,
not a recurring Docker health probe. There is no new s6 service or dependency.
OTBR-disabled startup never invokes the CLI through this hook. A configuration
failure records a nonzero container result and requests halt. The existing finish
script runs after the agent has exited, so its translator is already gone when
firewall teardown uses the shared 4-second IPv4/IPv6 cleanup budget.

The readiness contract is documented by
[s6-notifyoncheck](https://skarnet.org/software/s6/s6-notifyoncheck.html).
The pinned vendor's [REST resource](https://github.com/SiliconLabs/simplicity_sdk/blob/da661283f301b53eec04d1016009e60bc7e34a1f/util/third_party/ot-br-posix/src/rest/resource.cpp)
calls RcpHost::Reset for DELETE /node; [RcpHost::Reset](https://github.com/SiliconLabs/simplicity_sdk/blob/da661283f301b53eec04d1016009e60bc7e34a1f/util/third_party/ot-br-posix/src/ncp/rcp_host.cpp)
reinitializes the instance within the same process. This does not launch a new
startup checker. With FEATURE_FLAGS enabled, Init omits its legacy NAT64/DNS
auto-enable block. After an intentional in-process Thread factory reset, restart
the add-on to reapply its saved NAT64/DNS option. This draft adds no reset monitor.

Still required before production readiness:

- Execute this exact readiness hook and its failure/restart paths in a released-init fixture.
- Exercise actual IPv4 packet directions, source-pool reservation, restart and
  option disable in an isolated kernel namespace (the inherited kernel suite
  validates IPv6 lifecycle, not NAT64 data-plane acceptance).
- Rebuild this exact draft and verify feature-disabled startup and pool macro.
- Resolve DNS across the actual resolver route; no binding-policy change is made.
- Validate physical shared-radio traffic and appropriate architectures. Existing
  successful Matter traffic does not establish this new IPv4 capability.
