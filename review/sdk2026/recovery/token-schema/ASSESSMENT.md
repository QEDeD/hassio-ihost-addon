Current result (2026-09-19): [RESULT-20260919.md](./RESULT-20260919.md) records exact-image descriptor extraction, metadata-only baseline comparison, a reproduced default-offset migration defect and the tested candidate SDK correction. The assessment below is the earlier source-only state.

# Actual generated zigbeed token compatibility assessment

Read-only assessment of retained /sdk2026-recipe-zigbeed and SDK2026.6.1 source. No production file, key, live service, token migration or radio was accessed. The supplied baseline token header is already known to be version2; this assessment did not re-read it.

## Resolved: candidate does not select Zigbee Secure Vault storage

/sdk2026-recipe-zigbeed/autogen/sl_component_catalog.h selects SL_CATALOG_ZIGBEE_CLASSIC_KEY_STORAGE_PRESENT, SL_CATALOG_ZIGBEE_AES_SOFTWARE_PRESENT and SL_CATALOG_ZIGBEE_STACK_UNIX_PRESENT, and does not select SL_CATALOG_ZIGBEE_SECURE_KEY_STORAGE_PRESENT.

The generated zigbeed.project.mak defines ZIGBEE_STACK_ON_HOST=1 (line71), includes sl_zigbee_legacy_token_host.c (1488), sl_zigbee_token_host.c (1509), sl_zigbee_token_defines.c (1502) and zigbee-security-manager-no-vault.c (1586). In SDK zigbee/stack/security/zigbee-security-manager-no-vault.c:113–134 network keys are read/written through COMMON_TOKEN_STACK_KEYS / ALTERNATE_KEY. The host backend maps these dynamic tokens to host_token.nvm. Generic radio PSA migration warnings therefore do not describe the candidate Zigbee network-key storage choice. CPC binding-key PSA persistence is a separate transport concern.

## Actual version2 loader rules

SDK root: /opt/silabs/sdks/simplicity_sdk_2026.6.1.

zigbee/stack/platform/sl_zigbee_token_host.c:

- VERSION2 at line33; the verified baseline v2 header avoids the explicit v1 refusal at498–499.
- Opens the file read/write and creates it if missing (around463); startup is not a read-only compatibility probe.
- copyNvm at399–438 matches token ID, counter flag and element size. If the counter flag or element size differs, existing values are reset to defaults. The diagnostic is behind host-token debug printing.
- Existing tokens not currently registered are re-registered from persisted descriptors at542–550, preserving unknown nonempty tokens.
- Array counts may differ: copies the smaller count at592–607; expansion defaults extra slots at612–618. Shrink loses excess entries from the rewritten file.
- After parsing, it truncates/resizes and rewrites the token file at569–619. Same file-format version is not a guarantee of identical token semantics or lossless migration.

These are concrete loader behaviors, not evidence that any network-critical token actually differs between the supplied baseline and candidate. No such metadata comparison has yet run.

## Why nm/readelf alone cannot supply the initialized schema

zigbee/stack/platform/sl_zigbee_token.c:228–235 defines tokenNvm3Keys, tokenIsCnt, tokenIsIdx, tokenSize and tokenArraySize as NULL pointers, and token count as0. The descriptors are allocated and registered dynamically. There is no complete initialized static table to export directly from the on-disk ELF.

sl_zigbee_token_defines.c:34 onward, halStackInitTokens, registers app and stack tokens. Array counts at125–150 use runtime sl_zigbee_get_binding_table_size, sl_zigbee_get_child_table_size and sl_zigbee_get_key_table_size; green-power and multi-PAN registrations are conditional later in the function. Generated project definitions specify CHILD_TABLE_SIZE64 and MULTI_NETWORK_STRIPPED1, but those do not establish every runtime table count after application/EZSP configuration.

The normal app path invokes otSysInit with a radio URL (/sdk2026-recipe-zigbeed/app.c:305–318). No existing token-only validator was found in the inspected vendor test paths. A normal daemon invocation with an absent radio is therefore not an established migration test.

## Strongest next check

Obtain the candidate's initialized descriptor list through a narrowly isolated token-initialization-only extractor using the actual generated configuration and vendor registration routines, without opening host_token.nvm or initializing a radio. Emit only ID, counter flag, element size and array count. Compare that with privately parsed descriptors from the already-retained v2 backup, prioritizing network keys, trust center/key tables, node identity, restored EUI64, and counters. This can identify exactly which records would default or truncate under the real loader.

This extractor has not been built here: dynamic registration and application-controlled counts require a small runtime entry point, rather than trustworthy output from static-symbol inspection alone. No new migration framework is warranted. A later loader execution must use a disposable synthetic state file or separately authorized private copy, never the only recovery copy; preserve the baseline image/state independently for rollback.

## Qualification of likelihood

The actual classic-storage selection and already-v2 baseline remove two previously theoretical concerns. They increase confidence that a host-side functional recovery is plausible. They do not justify a numerical success probability: network-critical descriptor equality and real restored-network operation remain unchecked. The concrete avoidable risk is allowing the candidate to rewrite the only baseline host-token copy.
