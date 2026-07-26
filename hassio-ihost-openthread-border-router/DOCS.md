# Home Assistant Add-on: OpenThread Border Router

## Installation

Follow these steps to get the add-on installed on your system:

1. Navigate in your Home Assistant frontend to **Settings** -> **Add-ons, Backup & Supervisor** -> **Add-on Store**.
2. Click on the top right menu and "Repository"
3. Add `https://github.com/iHost-Open-Source-Project/hassio-ihost-addon`
   as the add-on repository.
4. Find the "OpenThread Border Router" add-on and click it.
5. Click on the "INSTALL" button.

## How to use

You will need a 802.15.4 capable radio supported by OpenThread. Home Assistant
Yellow as well as Home Assistant SkyConnect/Connect ZBT-1 are both capable to run
OpenThread. This add-on automatically installs the necessary firmware on these systems.

If you are using Home Assistant Yellow, choose `/dev/ttyAMA1` as device.

### Radio serial compatibility

The default hardware-flow-control setting remains enabled for compatibility
with radios that require RTS/CTS. Two supported MG21 configurations are known
exceptions:

| Radio and firmware | Device | Baud rate | Hardware flow control |
|---|---|---:|---|
| iHost built-in MG21 | `/dev/ttyS4` | `460800` | **Disabled** |
| SONOFF ZBDongle-E with the bundled `zbdonglee-460800` OT RCP firmware | Select its detected serial device | `460800` | **Disabled** |
| nRF54L15 RCP using compatible nRF Connect SDK firmware | Select its detected serial device | `1000000` when specified by that firmware | Follow the firmware documentation |
| Other radio or replacement RCP firmware | Select its detected serial device | Follow the firmware documentation | Follow the firmware documentation |

An incorrect baud rate or flow-control mode can look like an OTBR startup,
reset, or radio-communication failure. After changing a radio or its firmware,
confirm both settings against that exact firmware and validate repeated add-on
starts and Thread attachment on the target hardware.

![](https://raw.githubusercontent.com/iHost-Open-Source-Project/hassio-ihost-addon/master/hassio-ihost-openthread-border-router/images/otbr_configuration.png)

### Alternative radios

The website [openthread.io maintains a list of supported platforms][openthread-platforms]
lists other Thread capable radios. A well documented Radio for development is the
Nordic Semiconductor [nRF52840 Dongle][nordic-nrf52840-dongle]. The Dongle needs
a recent version of the OpenThread RCP firmware.
[This article][nordic-nrf52840-dongle-install] outlines the steps to install the
RCP firmware for the nRF52840 Dongle.

Once the firmware is loaded follow the following steps:

1. Select the correct `device` in the add-on configuration tab and press `Save`.
2. Start the add-on.

### OpenThread Border Router

This add-on makes your Home Assistant installation an OpenThread Border Router
(OTBR). The border router can be used to comission Matter devices which connect
through Thread. Home Assistant Core will automatically detect this add-on and
create a new integration named "Open Thread Border Router". With Home Assistant
Core 2023.3 and newer the OTBR will get configured automatically. The Thread
integration allows to inspect the network configuration.

### Firewall and NAT64 behavior

The `firewall` option controls OTBR ingress filtering. It does not control
whether the add-on configures IPv6 forwarding rules:

- When enabled, the add-on applies OTBR's ingress deny and allow rules.
- When disabled, the add-on permits forwarding into and out of `wpan0` without
  applying those ingress filters.

In both modes, the add-on creates interface-scoped OTBR chains and the ipsets
required by the compiled OTBR agent. It does not change the host-wide IPv6
`FORWARD` policy. IPv6 forwarding must be enabled on the Home Assistant host.

When `nat64` is enabled, the add-on marks traffic originating on `wpan0`,
masquerades only that marked traffic, and permits it to leave through the
selected backbone interface. Return traffic is accepted only for established
or related connections. NAT64 does not add unrestricted forwarding rules for
all traffic on the backbone interface.

Use `backbone_interface` to select the host interface that carries backbone and
NAT64 traffic on multi-NIC or VLAN systems. When it is unset, the add-on uses
the primary interface reported by Supervisor. Startup fails with a clear error
if no primary interface is reported or the selected interface does not exist;
the add-on does not silently guess `eth0`.

During an upgrade from version 2.13.0, the add-on removes legacy unrestricted
NAT64 rules only when their OTBR signature identifies a complete ingress and
egress pair for one backbone interface. Incomplete or ambiguous host firewall
rules are preserved and startup stops for manual review instead of deleting
rules that may belong to another service.

If the log reports that legacy NAT64 cleanup is blocked, inspect the following
from a trusted shell in the host network namespace with `NET_ADMIN` access:

```text
iptables -t filter -S FORWARD
iptables -t mangle -S PREROUTING
iptables -t nat -S POSTROUTING
```

Do not flush `FORWARD` or remove every matching rule. The historical add-on
signature consists of one `-i <interface> -j ACCEPT` and one
`-o <same-interface> -j ACCEPT` rule, together with the `wpan0` MARK and matching
MASQUERADE rules. When there are extra interfaces or only half of that pair,
capture the three listings above and establish rule ownership before changing
host firewall state.

Only one OTBR implementation should manage `wpan0` and the globally named OTBR
chains and ipsets at a time.

### Web interface (advanced)

There is also a web interface provided by the OTBR. However, the web
interface has caveats (e.g. forming a network does not generate an off-mesh
routable IPv6 prefix which causes changing IPv6 addressing on first add-on
restart). It is still possible to enable the web interface for debugging
purpose. Make sure to expose both the Web UI port and REST API port (the
latter needs to be on port 8081) on the host interface. To do so, click on
"Show disabled ports" and enter a port (e.g. 8080) in the OpenThread Web UI
and 8081 in the OpenThread REST API port field).

## Configuration

Add-on configuration:

| Configuration      | Description                                            |
|--------------------|--------------------------------------------------------|
| device             | Local serial port for the OpenThread RCP; optional when `network_device` is set |
| baudrate           | Serial port baudrate (depends on firmware)   |
| flow_control       | If hardware flow control should be enabled (depends on firmware) |
| backbone_interface | Optional host interface for backbone routing and NAT64; defaults to the Supervisor primary interface |
| autoflash_firmware | Automatically install/update firmware (Home Assistant SkyConnect/Yellow) |
| otbr_log_level     | Set the log level of the OpenThread BorderRouter Agent     |
| firewall           | Apply OTBR ingress filtering; scoped `wpan0` forwarding remains enabled when disabled |
| nat64              | Permit marked Thread-originated IPv4 flows and established return traffic |
| network_device     | IP address and port to connect to a network-based RCP (see below) |

> [!WARNING]
> The OTBR expects the RCP connected radio to be on a reliable link such as
> UART or SPI. Using TCP/IP to reach a remote RCP radio breaks this assumption.
> If the TCP/IP connection fails, the OTBR will not shutdown cleanly and leave
> stale routes in your network. This will lead to Thread devices to be
> potentially unreachable for up to 30 minutes (route lifetime) even when other
> routers are available.
>
> The RCP protocol is not designed to be transferred over an IP network: It is
> a timing-sensitive protocol. You might experience Thread issues if your
> network link has excessive latencies. As Thread is networking capable,
> running a Thread border router on the system the RCP radio is plugged in is
> recommended.

> [!NOTE]
> `network_device` takes precedence when both RCP fields are set. A dummy local
> serial device is not required; startup fails only when both `device` and
> `network_device` are empty.

## Support

Got questions?

You have several options to get them answered:

- The [Home Assistant Discord Chat Server][discord].
- The Home Assistant [Community Forum][forum].
- Join the [Reddit subreddit][reddit] in [/r/homeassistant][reddit]

In case you've found a bug, please [open an issue on our GitHub][issue].

[discord]: https://discord.gg/c5DvZ4e
[forum]: https://community.home-assistant.io
[reddit]: https://reddit.com/r/homeassistant
[issue]: https://github.com/iHost-Open-Source-Project/hassio-ihost-addon/issues
[openthread-platforms]: https://openthread.io/platforms
[nordic-nrf52840-dongle]: https://www.nordicsemi.com/Products/Development-hardware/nrf52840-dongle
[nordic-nrf52840-dongle-install]: https://docs.nordicsemi.com/bundle/ncs-latest/page/nrf/protocols/thread/tools.html#configuring_a_radio_co-processor
