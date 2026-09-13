# NAT64 reply probe: test preparation

Status: packet preparation and Linux sender validated locally. No production
packets sent by this preparation. Not yet a ready-to-run production procedure.
Keep these tools on the integration branch; they are not app functionality.

## Purpose

Use an existing Matter-over-Thread plug to test a UDP flow through NAT64 without
re-pairing it, changing its firmware, switching its load, or knowing its fabric
credentials. A Thread device can supply the necessary outgoing IPv6 packet by
replying to a request; it need not start the application conversation.

Send a syntactically valid CASE Sigma1 with a random DestinationID that does not
match a fabric. The reference Matter implementation rejects this before Sigma2
with NoSharedTrustRoots. This is a hypothesis for the particular plug firmware,
not an established observation. A standalone acknowledgement proves less: it
shows receipt, but does not establish that Sigma1 was parsed and rejected.

## Test order and decision points

1. Read current device address, UDP port, app versions, radio health, NAT64
   state and routes. Identify the already-authorized plug by registry identity;
   do not infer identity from an address alone. Preserve current app data and
   the existing recovery procedure before any approved candidate cutover.
2. Establish a collector outside HA on the intended IPv4 backbone path. Verify
   a bounded UDP request/reply from HA first. Confirm filtering, route and
   collector port. Do not open a broad firewall rule or use HA's own address:
   that could avoid the forwarding rules under test.
3. Ordinary IPv6 control: send one Sigma1 from a real reachable IPv6 source to
   the plug. Require the correlated NoSharedTrustRoots response. Handle reliable
   message acknowledgement on the same socket; stop if Busy, unexpected status,
   health degradation, or no usable response. Do not proceed by repeatedly
   hammering a silent device. This stage needs no NAT64 enablement.
4. Following approval of the concrete candidate/NAT64 cutover, use a fresh
   request with source IPv6 equal to the actual advertised NAT64 /96 prefix
   plus the collector IPv4 address. Confirm prefix length and the exact
   translator implementation first; do not hardcode a well-known prefix.
5. Require the correlated plug response at the IPv4 collector AND capture or
   translation-table evidence of the Thread IPv6 -> translated IPv4 path.
   Record before/after counters, relevant narrow firewall counters, packet
   tuples and timestamps. Counters alone are insufficient.
6. Send the second fresh Sigma1 from the collector's SAME IPv4 socket to the
   source address/port observed in that response. Require a new correlated
   rejection from the plug. This proves reverse delivery, not just an ACK
   submission. Host MASQUERADE may change the visible source tuple.
7. If the cutover scope includes the disabled control, repeat with a fresh
   exchange/port while NAT64 is off and no alternative translator is active.
   Recheck ordinary IPv6 control. Silence alone does not prove correct NAT64
   disablement. Avoid another restart merely for redundant evidence.
8. Remove temporary sender/collector/capture files and any narrowly approved
   temporary network changes. Verify fresh Zigbee and Matter reports and
   preserve the chosen app state and current radio data. No old VM snapshot
   restore or fabric reset as routine cleanup.

Each stage is a separate decision point. Allow at most one fresh request per
stage, plus protocol-required acknowledgements; do not automatically retry.
Resolve MRP acknowledgement handling and bounded capture/collector operation
before sending to production. The injector is deliberately not a Matter client.

## Evidence boundaries

A successful test establishes this device's UDP reply path and, with stage 6,
reverse UDP delivery through the NAT64 mapping and host forwarding rules.
It does not establish TCP, DNS64, arbitrary Internet services, device-side
address synthesis, or authenticated Matter sessions over NAT64.

The pinned OpenThread translator allocates mappings for outgoing UDP, including
replies. Its ICMP handling supports outgoing echo requests rather than outgoing
echo replies; an IPv4-originated ping is not a substitute for this UDP test.

Primary references:
- [Pinned translator source](https://github.com/SiliconLabs/simplicity_sdk/blob/da661283f301b53eec04d1016009e60bc7e34a1f/util/third_party/openthread/src/core/net/nat64_translator.cpp)
- [Reference CASE handling](https://github.com/project-chip/connectedhomeip/blob/master/src/protocols/secure_channel/CASESession.cpp)
- [Reference CASE server](https://github.com/project-chip/connectedhomeip/blob/master/src/protocols/secure_channel/CASEServer.cpp)

## Tools and local verification

`python3 probe.py build NEW_DIRECTORY` requires Python cryptography and writes two
fresh Sigma1 requests plus a manifest. The private ephemeral keys are discarded;
no actual device credentials are used. Both files are Sigma1, not Sigma2.

`python3 probe.py inspect REPLY_FILE MANIFEST` checks the expected plaintext
framing, exchange, direction, destination identity and response status. A
correlated ACK is explicitly distinguished from a CASE rejection.

`inject6.c` is a Linux one-shot raw UDP sender requiring CAP_NET_RAW. Compile with:

```
cc -std=c11 -O2 -Wall -Wextra -Werror -static -o inject6 inject6.c
./inject6 --self-test
```

It changes no addresses, routes or firewall rules; rejects unsupported addresses,
invalid ports and payloads over 512 bytes; and submits exactly one packet. A
successful send is not evidence of delivery.

Local checks on 2026-09-13:
- Both requests decoded successfully using MessageCodec and TlvCaseSigma1 from
  @matter/protocol 0.17.9, independently of the Python encoder.
- Static compilation passed with warnings treated as errors.
- Checksum vectors passed for empty, odd-length and mathematical-zero cases.
- An isolated container with `--network none` received the exact UDP payload
  and source port on loopback, verifying real-kernel checksum acceptance.
- No second datagram arrived; oversized payload, multicast destination and
  source port zero were rejected.

`test_injector.py` expects `/out/inject6`; run only in the isolated Linux test
container with external networking disabled. Do not commit generated packets,
raw production captures, inventories or credentials.

Still required before live execution: reachable collector and direct-IPv6 return
path, capture placement, same-socket acknowledgement handling, current plug
endpoint confirmation, and concrete approval for candidate/NAT64 activation.