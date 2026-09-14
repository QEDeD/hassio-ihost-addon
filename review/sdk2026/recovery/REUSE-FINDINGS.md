# Reuse findings for functional recovery — 2026-09-14

The new assessment targets restoring the existing networks without re-pairing, not reproducing every old radio byte. These findings supersede the broad earlier statement that only the baseline host's base image is identified.

## Complete retained host image

Existing INTEGRATION.md already records the exact published, production-tested0.2.3-ordered wrapper from product sourceaca557b6eb851af109a2708f55b5b2668314818f:

- Registry: ghcr.io/qeded/otbr-integration-test-amd64
- OCI index: sha256:0224cb183592e0e83aac35ce9ed6f350654537b73b73c03b0ebb74a1f972b107
- AMD64 manifest: sha256:3214cb9e1e42f8da631134f4177779ea9acd366273c00c901affab65efb9a4df

Local Docker image inspection confirms that exact index is retained under0.2.3-ordered. It can be reused; no replacement baseline build is needed. Prior integration evidence records its physical operation. A fresh digest inspection of the running HA container remains unavailable, so this is a retained tested rollback host, not a new proof of live byte identity.

An isolated --network none container with /bin/sh entrypoint (no device mappings or production volumes) confirmed:

- CPCd4.6.1.0, commita15eb6b608497535dd1c3d9bd8871f6a4865c443.
- /usr/local/share/cpcd.conf sets disable_encryption:true. Its binding_key_file:/etc/binding-key.key setting is not proof that a key exists or is needed in this plaintext mode.
- cpcd-config-up renders UART device/baud/flow options into /usr/local/etc/cpcd.conf.
- zigbeed run creates/uses /data/zigbeed as working directory.
- OTBR run persists settings under /data/thread through /var/lib/thread.

The current Supervisor backupfeec49c2 preserves those host state directories and actual Z2M/HA/Matter configuration. Use BACKUP-20260914.md for exact scope and limitations. Reusing this tested host and backup narrows the unresolved question to radio state and compatibility, not reconstructing an unknown host environment.

No production operations, image publication or firmware changes were performed for these checks. Isolated inspection containers removed themselves on exit.