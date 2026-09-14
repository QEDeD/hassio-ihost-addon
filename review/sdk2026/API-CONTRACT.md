# HA / SDK REST API contract assessment

Date: 2026-09-14. Scope: source comparison for the isolated SiSDK2026.6.1 candidate. No production access or runtime tests.

## Result

The inspected SDK source supports the factory-reset and JSON casing contracts used by HA Core 2026.9.2 with python-otbr-api 2.10.0. No need was demonstrated to port the legacy active/pending dataset DELETE patch or add a casing patch for this HA version. This is a source finding, not integration-test success or production acceptance.

## Evidence boundary

The HomeAssistant repository's docs/designs/2026-09-13-thread-plug-validation.md records Core 2026.9.2 observed September 13. The parent retrieved the official manifest pinning python-otbr-api==2.10.0. This review read exact client 2.10.0 and HA 2026.9.2 sources, not HA dev. Live installed package contents were not independently inspected.

[HA manifest](https://github.com/home-assistant/core/blob/2026.9.2/homeassistant/components/otbr/manifest.json)

SDK sources were read in container sisdk-upgrade-trial-20260914 under /opt/silabs/sdks/simplicity_sdk_2026.6.1/openthread_stack/util/third_party/ot-br-posix. That subtree has no Git metadata: this review does not independently establish pristine archive identity or rule out preceding candidate edits. Conclusions do not use the lost /tmp bind-mount copy.

## Reset

SDK src/rest/rest_web_server.cpp:140 registers DELETE /node. DeleteNodeInfo at lines 271–291 calls ThreadHelper::Detach, otInstanceErasePersistentInfo, and mHost.Reset in order. Success returns 200; detach failure returns 409 and erase failure 500.

HA's factory_reset invokes the client reset first; only FactoryResetNotSupportedError triggers active-dataset deletion. HA then fetches the border-agent ID and updates entry identity, so verification must include that immediate subsequent ID read. [HA reset wrapper](https://github.com/home-assistant/core/blob/2026.9.2/homeassistant/components/otbr/util.py#L79)

HA create-network disables Thread, resets, creates a dataset and enables Thread. Set-network writes TLVs after disabling Thread. Set-channel creates a pending dataset, but HA rejects that operation in multiprotocol mode. These inspected paths do not independently require dataset DELETE. [HA websocket operations](https://github.com/home-assistant/core/blob/2026.9.2/homeassistant/components/otbr/websocket_api.py)

The SDK registers GET/PUT/OPTIONS but no DELETE for either dataset resource (rest_web_server.cpp:152–157). Direct library delete_active_dataset/delete_pending_dataset calls therefore remain an unsupported API surface. Do not claim every library method is implemented. Port deletion only if a separately required caller is established; deletion has narrower semantics than persistent reset.

## Casing and client contract

Client 2.10.0 probes GET /api/actions before its first operation: 200 selects camelCase, 404 selects legacy PascalCase, and other statuses fail detection. Reset accepts exactly 200; only 405 becomes FactoryResetNotSupportedError. Reads normalize legacy keys recursively, while writes use the detected format. [Exact client implementation](https://github.com/home-assistant-libs/python-otbr-api/blob/2.10.0/python_otbr_api/__init__.py)

SDK rest_web_server.cpp:168 registers GET /api/actions. ApiActionsGetHandler accepts the ordinary Accept: */* header and returns 200. Verify this through the final candidate HTTP route: middleware blocking the probe would break discovery even if dataset endpoints work.

SDK json.cpp:1130–1205 serializes active/pending datasets in camelCase, including pskc, extPanId, activeDataset, pendingTimestamp and delay. Timestamp fields at line 272 and security-policy fields at lines 313–364 match the client models, including routers and the unusual spelling tobleLink. SDK dataset parsing uses case-sensitive lookups. No mismatch was found in these inspected fields. [Exact client models](https://github.com/home-assistant-libs/python-otbr-api/blob/2.10.0/python_otbr_api/models.py)

## Minimum offline verification

1. Run the exact client against a disposable SDK simulation/server through the candidate HTTP route. Check default GET /api/actions returns 200 and selects camelCase. Verify border-agent ID, extended address, firmware version, JSON/TLV dataset reads and absent-dataset 204 responses.
2. With synthetic datasets, verify partial active creation and TLV replacement while disabled; compare resulting datasets. Exercise nested timestamp/security-policy round trips and pending creation where supported by the simulated stack.
3. Exercise HA's disable/reset/read-ID/create/enable sequence. Assert DELETE /node returns 200, datasets are absent after reset and no dataset DELETE occurs. Include reset from an already-disabled state, HA's normal create-network sequence. Cover detach/erase failures with mocks if necessary.
4. Separate mocked client tests from SDK execution: mocks cannot establish reset survival or subsequent request success. Simulator success does not establish real RCP/CPC behavior.

## Tests to reuse

- [Client test_init.py](https://github.com/home-assistant-libs/python-otbr-api/blob/2.10.0/tests/test_init.py): detection, one-time probing, camelCase reads/writes and PascalCase stragglers.
- [Client test_init_legacy.py](https://github.com/home-assistant-libs/python-otbr-api/blob/2.10.0/tests/test_init_legacy.py): reset success/unsupported/unexpected-status, datasets, TLVs, IDs and errors. Adapt relevant cases to SDK detection/fixtures; legacy mocks do not test the new server.
- [HA test_util.py](https://github.com/home-assistant/core/blob/2026.9.2/tests/components/otbr/test_util.py): reset, unsupported fallback and failures. [HA test_websocket_api.py](https://github.com/home-assistant/core/blob/2026.9.2/tests/components/otbr/test_websocket_api.py): create/set network and multiprotocol restriction.
- SDK tests/rest/test_rest.py and test-rest-server provide a simulated ot-rcp harness and basic node/diagnostic HTTP checks. The inspected Python test does not cover dataset creation/deletion or reset. tests/restjsonapi includes actions collection tests. Reuse these harnesses and add the focused missing sequence.

## Checks actually performed

Read-only inspection of tagged upstream source/test names and SDK source/routes/test harness. This worker ran no unit tests, simulated HTTP tests, installation, build or production calls. Only this report was written. The offline tests above remain required; parent workers may provide separate execution evidence.

## Executed follow-up
See api-tests/README.md, results.json and server.log: the actual SDK REST server passed eight grouped checks with python-otbr-api2.10.0, including HA disable/reset/immediate ID read and active/pending datasets. No SDK REST source changes were needed. Current live HA Core was confirmed read-only as 2026.9.2 on 2026-09-14. This closes the earlier unexecuted REST-contract gap for these sequences, not CPC/multipan or physical network behavior.
