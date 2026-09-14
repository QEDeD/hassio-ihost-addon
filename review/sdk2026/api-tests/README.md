# Actual SDK REST simulation results

2026-09-14: PASS, all eight grouped assertions in results.json. This is a real compiled SDK otbr-agent serving HTTP, connected by HDLC forkpty to a compiled OpenThread simulated RCP, tested with the published python-otbr-api 2.10.0 package. No fake HTTP server was used.

## Verified behavior

- Default GET /api/actions returns 200 and the exact client selects camelCase.
- Border-agent ID, extended address and firmware-version reads work.
- HA's disable/reset/immediate ID-read sequence works, with absent active JSON, active TLV and pending TLV datasets returning the expected empty result.
- Partial camelCase active dataset creation generates a complete dataset with nested timestamp/security policy and key fields.
- Enable followed by active TLV read works.
- Disabled TLV replacement yields identical TLVs and equivalent parsed JSON.
- Nested pending dataset creation and direct camelCase JSON / client TLV reads work.
- Final disable/reset clears active and pending datasets, with no dataset DELETE request.

results.json records all successful HTTP method/path/status observations. server.log is the actual SDK server/RCP log. Generated keys belong only to this synthetic isolated network. The script terminates the server after the assertions, including on failure.

## Build and isolation

build-simulation.py creates separate /sdk2026-api-tests/agent-build and rcp-build directories in retained builder sisdk-upgrade-trial-20260914. It reuses OT/OTBR settings from the existing native product cache and builds with two jobs. Differences: HDLC ON, vendor CPC bus OFF, multipan OFF, Release build, BUILD_TESTING OFF. The separate RCP uses the same SDK OpenThread source with OT_PLATFORM=simulation and Thread 1.4. Saved CMake caches show exact effective settings. sha256.txt identifies binaries and REST source files.

Runtime container sdk2026-api-simulation uses the same pinned builder base image, network none, NET_ADMIN and only /dev/net/tun. There are no physical USB devices, host networking, mounts or production endpoints. It was stopped after collecting evidence and is retained for reproduction. The original builder remains untouched outside /sdk2026-api-tests.

Python and its standard library were copied into /sdk2026-api-tests/python-runtime because the base image lacks Python; package dependencies were installed into /sdk2026-api-tests/python only. Required protobuf/netfilter/expat libraries were copied into runtime-libs. client-requirements.txt records exact installed dependencies; these transitive versions are not claimed to match HA's environment. The target OTBR client version is exactly 2.10.0.

## Re-run retained simulator

From PowerShell:

```powershell
docker start sdk2026-api-simulation
docker exec --env PYTHONHOME=/sdk2026-api-tests/python-runtime --env PYTHONPATH=/sdk2026-api-tests/python --env LD_LIBRARY_PATH=/sdk2026-api-tests/runtime-libs sdk2026-api-simulation /sdk2026-api-tests/python-runtime/bin/python3 /sdk2026-api-tests/test-sdk-api.py
docker stop sdk2026-api-simulation
```

The test resets its synthetic datasets before creating test state and terminates the agent afterward. Binary/runtime transfer archives were removed from this review directory to avoid committing generated dependencies; runtime files remain in the stopped container and builder. Build logs and scripts are retained here.

## Limits

This verifies the actual SDK REST contract over simulated serial RCP, not the final add-on image, full HA process, real radio, CPC, concurrent multipan, network attachment convergence, multicast discovery over a physical network, NAT64 or production delivery. The HA sequence is reproduced through the exact client, rather than importing HA's Python wrapper. Error-injection paths (detach/erase failure) and legacy deletion fallback were not exercised; source review covers expected statuses.

Two setup attempts failed before HTTP testing: first the base runtime had no Python, then the agent required explicit vendor/model arguments. Local runtime staging and test-only vendor/model arguments resolved these; final results.json and server.log contain the completed passing run. No SDK source changes were needed.
