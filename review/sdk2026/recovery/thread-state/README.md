# Thread host-state compatibility — 2026-09-19

## Result

Actual vendor POSIX settings implementations passed synthetic old → new → old → new reads and writes. All ten test records retained exact bytes, and a record first written by the new implementation survived a later old-implementation rewrite. The serialized NetworkInfo, ParentInfo and ChildInfo classes are unchanged in the compared source. This supports reusing the latest compatible Thread store during recovery; it does not prove live attachment, radio identity, firmware downgrade, or security-counter behavior on hardware.

No production Thread data, keys or radio were used. Results are in `results.json`; the narrowly scoped test is `run-settings-cross-version.py`.

## Exact inputs and scope

Baseline is SDK 2024.12.1-0, commit `da661283f301b53eec04d1016009e60bc7e34a1f`, using `util/third_party/openthread/src/posix/platform/settings.cpp` and its `settings.hpp`. Sources were obtained from the vendor repository, for example:
https://github.com/SiliconLabs/simplicity_sdk/blob/da661283f301b53eec04d1016009e60bc7e34a1f/util/third_party/openthread/src/posix/platform/settings.cpp

Candidate source is the pinned SDK 2026.6.1 in retained `sisdk-upgrade-trial-20260914`, `openthread_stack/util/third_party/openthread`. The copied `settings.cpp` and `settings_file.cpp` were byte-compared with `/sdk2026-native/ot-br-posix/third_party/openthread/repo/src/posix/platform/` and match. Results record source SHA-256 hashes.

The test compiles both unmodified storage implementations with the retained candidate POSIX compiler definitions and current SDK common/public headers. The baseline private settings header is overlaid for its internal function declarations. Only settings path, logging/exit-message stubs, dry-run query and a deterministic synthetic radio EUI are supplied by the harness. Assertions are enabled. This is a cross-version storage test, not execution of the complete old image or network stack. Opaque fixture values are not valid operational datasets and are never sent to a radio.

The isolated container `sdk2026-thread-state-20260919` has network disabled and no production mounts or devices. It derives from the retained build snapshot `sha256:f877330a2f4b8f0d497e28f9e0a4f76ba63466438d0b8aaef9da8d202b6a3ecd`. Public sources, compiler tree and synthetic state remain under `/thread-state-review`; run `python3 /thread-state-review/run-settings-cross-version.py` inside that isolated container to reproduce. The script replaces only its own synthetic store files.

## State and counters

- Both file backends serialize native-endian uint16 key + uint16 length + value. This evidence applies to the current AMD64 host, not cross-endian portability.
- Existing network-info fields retain their packed order and little-endian accessors: role, mode, RLOC16, key sequence, MLE/MAC frame counters, previous partition, extended address, mesh-local IID and Thread version. Parent/child structures also retain their representation.
- Both old and new `Mle::Restore()` restore key sequence and saved MLE/MAC counters before the Thread-version reattach check. Both `Mle::Store()` save counters plus `mStoreFrameCounterAhead`. Candidate KeyManager calls Store when its current counter reaches the stored threshold. Do not reinterpret this as permission to restore an arbitrarily old file: the saved margin can already have been consumed by subsequent operation.
- Both derive the normal settings basename from radio EUI64 and PORT_OFFSET. Candidate additionally supports an explicit filename. The current startup script supplies no filename override. An unexpected EUI change may select an empty store and must stop the trial before normal network operation.
- Candidate adds a TCAT commissioner-certificate setting; that is not a change to existing network-info layout. Generic settings I/O preserves unknown keys in the tested rewrite path.
- Candidate storage uses fsync of the parent directory after rename, an additional persistence safeguard visible in source. No crash/power-loss test or quantified reliability improvement is claimed.

## Recovery implication

Keep an immutable, fresh pre-trial copy. The candidate operates on a separate copy. If it has transmitted, capture its latest stopped state before recovery. Prefer carrying forward the latest compatible full Thread store to the old host rather than rewinding to the pre-trial snapshot. Validate expected filename, network identity/dataset and store integrity privately; never print keys.

This route still depends on Zigbee token/counter compatibility, effective radio identity, CPC persistent-key behavior and old firmware startup after candidate binding. A matching file representation cannot resolve those hardware questions. Re-importing only the active dataset or restoring an older VM/app snapshot is not an adequate general rollback procedure.
