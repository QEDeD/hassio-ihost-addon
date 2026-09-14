Current closeout (2026-09-14): see review/sdk2026/recovery/FINAL-ASSESSMENT.md and BACKUP-20260914.md. A new current host backup closes the earlier missing backup coverage; production radio recovery and candidate hardware acceptance remain unverified.

# Current host state and backup coverage

Read-only inspection: 2026-09-14. No backup, restart, configuration change, secret export, Docker/SSH installation, radio operation or live write was performed. Only metadata, filenames, archive member listings and explicitly selected non-secret configuration fields were returned. Raw backup/state contents were not copied into this repository.

## Result

A fresh matched recovery point is not yet established. Existing evidence identifies the focused app's historical Thread/Zigbee host-state paths, current Z2M/HA Thread files, and working Supervisor backup commands. It does not establish the currently running focused image's immutable ID, current private app-data contents, current Matter fabric files, a matching CPC binding key, or radio nonvolatile-state rollback compatibility.

A particularly important gap: the latest paired focused/Z2M app backup does not contain Z2M's actual /config/zigbee2mqtt data. Its Z2M member contains only data/options.json and an empty config/ directory. App-only coverage must not be described as a matched coordinator-and-network recovery point.

## Access and currently running versions

The installed versioned `ha-unlock --check-access` succeeded interactively in Ubuntu WSL, including HA API and scoped Git read checks. The checkout-bound `scripts/ha-unlock` initially refused the standalone helper layout; no installer or access configuration was changed. Subsequent inspection used repository scripts/ha-ssh and the existing ha CLI.

- local_codex_ihost_otbr_focused: 0.2.3-ordered, started.
- 45df7312_zigbee2mqtt: 2.14.1-1, started; data_path explicitly /config/zigbee2mqtt.
- core_matter_server: 9.2.0, started.

The SSH management app has neither Docker nor Python available; the host Supervisor data root is not exposed. Its /data is the SSH app's own data, not the focused/Matter app volume. /addon_configs/core_matter_server and /addon_configs/45df7312_zigbee2mqtt exist but are empty. No host SSH route was established.

## Image identity

Live focused config.json declares ghcr.io/qeded/otbr-integration-test-amd64 with version 0.2.3-ordered. App-info does not return an image/digest field. The local Dockerfile and build-manifest record base image ghcr.io/ihost-open-source-project/hassio-ihost-silabs-multiprotocol-amd64@sha256:f69bd95b16c23c018351b55659e3767f6573edf8f87061c58d1e610a2ce8ccef plus local overlays. That is a base identity, not proof of the running complete image digest. Docker container/image inspection or another authoritative installed-image record remains necessary to pin exact host rollback bytes.

## State paths and coverage actually observed

| State | Evidence | Remaining limitation |
|---|---|---|
| Focused Thread settings | Existing backup 524be610 contains data/thread/ with one .data file, directory0700, file0600 root-owned | Historical focused0.2.1-baseline snapshot; current0.2.3 private volume not visible |
| Focused Zigbee host tokens | Same archive contains data/zigbeed/host_token.nvm, directory0700, file0600, 6395 bytes | Current contents/format compatibility not established |
| Focused startup/import state | Same archive contains data/local-radio-started, data/.local-state.lock, data/local-state-import.json and data/options.json, all0600 | Must preserve app data as a coherent set; do not restore only one token file |
| CPC binding key | No binding-key/CPC directory entry in that historical focused archive | Does not prove current key absence; current private volume inaccessible. Candidate expects /data/cpc/binding.key, but no matching provisioned key was established |
| Z2M state | Current /config/zigbee2mqtt/configuration.yaml, database.db, state.json, coordinator_backup.json all exist, root-owned0644. Coordinator backup781 bytes; database43960 bytes at inspection | Contents deliberately unread; backup freshness/coordinator format not validated. These files are outside the observed app-only archive |
| HA Thread integration | Current /config/.storage/thread.datasets exists root-owned0644,674 bytes; core.config_entries also exists | Preserve full HA config storage; standalone dataset file is not a complete HA restore |
| Matter fabric | core_matter_server9.2.0 is started, but its private data volume is not visible through the SSH app | No current fabric file listing or current fabric backup established |

App /data is documented persistent storage, but the actual host bind-source paths were not observable here. Do not invent or operate on presumed /mnt/data/supervisor/addons/data paths. [HA app storage contract](https://developers.home-assistant.io/docs/apps/configuration/)

## Existing backups

Supervisor lists28 backups. Newest is slug524be610, 2026-09-13T14:37:23Z, partial, unprotected, compressed, /backup/524be610.tar (20480 bytes). Metadata names focused0.2.1-baseline and Z2M2.14.1-1 only, with no folders or HA component. The outer archive has those two app members and backup.json. Nested archive listing established the state coverage above without printing contents. This backup does not cover current focused0.2.3, HA Thread or Matter fabric; Z2M network data is also absent.

Newest full backup is slug79b31d0f, 2026-04-04T14:41:24Z, /backup/79b31d0f.tar (81571840 bytes), unprotected. Metadata includes HA2026.4.1, Matter8.3.0, Z2M2.9.2-1 and the older iHost multiprotocol1.0.0 app. It is not a matched current recovery point. A separate VM-backup arrangement is recorded in the repository, but was not inspected here.

## Concrete supported commands, not executed

Live CLI help verified these command forms:

```sh
# Create a new full Supervisor backup (all components); a live write requiring authorization.
ha backups new --name 'SDK2026 matched pre-change recovery'

# Inspect resulting metadata; safe read-only.
ha backups info NEW_BACKUP_SLUG --raw-json

# Whole-system restoration to that point; disruptive, requires separate authorization.
ha backups restore NEW_BACKUP_SLUG

# Narrow app restoration is supported, but does not restore HA/Z2M config storage.
ha backups restore NEW_BACKUP_SLUG --app local_codex_ihost_otbr_focused --app 45df7312_zigbee2mqtt --app core_matter_server --homeassistant=false
```

A full backup is the supported route to include HA config (therefore the observed Z2M directory and HA Thread storage) together with private app data. Its resulting archive must be checked for those actual members and the Matter app, and retained securely outside this repo. The command alone does not prove synchronized radio/host state, successful restore, retained container-image bytes or compatible downgrade. Stop/backup ordering and radio rollback remain decisions for the separate recovery proposal, not actions authorized by this inspection.

The available access is sufficient to prepare a concrete backup plan, but not to certify safe firmware downgrade or claim an existing matched recovery set.
