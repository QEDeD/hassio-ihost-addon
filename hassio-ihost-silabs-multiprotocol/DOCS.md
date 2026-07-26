# Home Assistant Add-on: Silicon Labs Multiprotocol

## Prerequisites
This addon is compatible with SONOFF dongles utilizing Silicon Labs chips, such as the
ZBDongle-E (EFR32MG21).Before using this add-on, you must first flash the MultiPAN firmware 
via [SONOFF Dongle Flasher][sonoff-dongle-flasher]. Another option is flashing firmware 
via [SONOFF Dongle Flasher Add-on][dongle-flasher-addon].

[![Open your Home Assistant instance and show the dashboard of an add-on.](https://my.home-assistant.io/badges/supervisor_addon.svg)](https://my.home-assistant.io/redirect/supervisor_addon/?addon=81bc2df9_sonoff_dongle_flasher_for_ihost&repository_url=https%3A%2F%2Fgithub.com%2FiHost-Open-Source-Project%2Fhassio-ihost-addon)

## Maintenance status

Home Assistant upstream has deprecated multiprotocol setups that share one
radio. This downstream iHost fork continues to support that configuration, but
dedicated Zigbee and Thread radios are recommended for new installations.
Back up Home Assistant and test the migration and rollback path before changing
an existing radio setup.

## Installation

Follow these steps to get the add-on installed on your system:

1. Add Silicon Labs Multiprotocol Add-on to Repositories
      - Go to the Add-on Store → Click the More button (⋮) in the upper-right corner → Select Repositories
        Paste the following URL:https://github.com/iHost-Open-Source-Project/hassio-ihost-addon
      - Or, simply click the button below to add it automatically:

      [![Open your Home Assistant instance and show the add add-on repository dialog with a specific repository URL pre-filled.](https://my.home-assistant.io/badges/supervisor_add_addon_repository.svg)](https://my.home-assistant.io/redirect/supervisor_add_addon_repository/?repository_url=https%3A%2F%2Fgithub.com%2FiHost-Open-Source-Project%2Fhassio-ihost-addon)
      
      ![](https://raw.githubusercontent.com/iHost-Open-Source-Project/hassio-ihost-addon/master/hassio-ihost-silabs-multiprotocol/images/description-picture_1.png)

2. Install Silicon Labs Multiprotocol(Mod) Add-on
      - Search for Silicon Labs Multiprotocol(Mod) Add-on in the Add-ons Store.
      - Click "Install" button.  
      - Wait for the installation to complete

## How to use

The add-on needs a Silicon Labs based wireless module accessible through a 
serial port (like ZBDongle-E,iHost MG21 chip or most USB based wireless adapters).

Once the firmware is loaded follow the following steps:

1. Select the correct local `device`, or configure `network_device` for a
   socket-connected radio, in the add-on configuration tab and press `Save`.
2. Start the add-on.

**NOTE:** the Web frontend is only accessible when OpenThread is enabled (see below).

![](https://raw.githubusercontent.com/iHost-Open-Source-Project/hassio-ihost-addon/master/hassio-ihost-silabs-multiprotocol/images/description-picture_2.png)

### Zigbee

The add-on exposes Zigbee over TCP port 9999. Use a ZHA or Zigbee2MQTT version
that supports the EZSP version provided by the installed MultiPAN firmware.
The example below uses Zigbee2MQTT.

To use Zigbee with Z2M configure the Integration as follows:

1. Remember/copy the hostname of the add-on (e.g. c617dadc-hassio-ihost-silabs-multiprotocol).
2. Open the Zigbee2MQTT add-on → Configuration page.
3. Configure the device's serial port path, baudrate, adapter type under serial.

      ```yaml
      adapter: ember
      port: tcp://c617dadc-hassio-ihost-silabs-multiprotocol:9999
      baudrate: 115200

      ```

4. click "SAVE" button. 
5. After completing the configuration,start the Zigbee2MQTT add-on. Wait for about two minutes,
 then you can click to enter the Web UI Console to add and manage devices.

![](https://raw.githubusercontent.com/iHost-Open-Source-Project/hassio-ihost-addon/master/hassio-ihost-silabs-multiprotocol/images/description-picture_3.png)

![](https://raw.githubusercontent.com/iHost-Open-Source-Project/hassio-ihost-addon/master/hassio-ihost-silabs-multiprotocol/images/description-picture_4.png)
### OpenThread

At this point OpenThread support is experimental. This add-on makes your Home
Assistant installation an OpenThread Border Router (OTBR). A basic integration
for Home Assistant Core named `otbr` is currently in the making.

To use the OTBR enable it in the Configuration tab and restart the add-on. Home
Assistant should discover the OpenThread border router automatically and
configure it as necessary.

#### Firewall behavior

The `otbr_firewall` option controls OTBR ingress filtering. It does not control
whether the add-on configures IPv6 forwarding rules:

- When enabled, the add-on applies OTBR's ingress deny and allow rules.
- When disabled, the add-on permits forwarding into and out of `wpan0` without
  applying those ingress filters.

In both modes, the add-on creates interface-scoped OTBR chains and the ipsets
required by the compiled OTBR agent. It does not change the host-wide IPv6
`FORWARD` policy. IPv6 forwarding must be enabled on the Home Assistant host.
Only one OTBR implementation should manage `wpan0` and the globally named OTBR
chains and ipsets at a time.

Use `backbone_interface` to select the host interface used for backbone routing
on multi-NIC or VLAN systems. When it is unset, the add-on uses the primary
interface reported by Supervisor. Startup fails with a clear error if no
primary interface is reported or the selected interface does not exist; the
add-on does not silently guess `eth0`.

Before startup reconciliation, the add-on refuses to clean or replace firewall
state if `wpan0` already exists, or if network interfaces cannot be inspected.
When OTBR is disabled, it logs a warning and skips cleanup under the same
conditions so Zigbee can continue starting. This conservative guard avoids
removing globally named rules from an active standalone OTBR. Because those
rules do not record which add-on created them, an orphaned `wpan0` can also
prevent automatic cleanup; stop every OTBR implementation before manually
removing stale state or restarting the host.

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
| device             | Serial service where the Silicon Labs radio is attached; required unless `network_device` is set |
| baudrate           | Serial port baudrate (depends on firmware)   |
| flow_control       | If hardware flow control should be enabled (depends on firmware) |
| backbone_interface | Optional host interface for backbone routing; defaults to the Supervisor primary interface |
| network_device     | Host and port where CPC daemon can find the Silicon Labs radio (takes precedence over device) |
| cpcd_trace         | Co-Processor Communication tracing. High-volume tracing can materially degrade performance and stability; leave disabled except while troubleshooting |
| otbr_enable        | Enable OpenThread BorderRouter                         |
| otbr_log_level     | Set the log level of the OpenThread BorderRouter Agent     |
| otbr_firewall      | Apply OTBR ingress filtering; scoped `wpan0` forwarding remains enabled when disabled |

## Architecture

The add-on runs several service internally. This architecture diagram shows what
the add-on currently implements.

![](https://raw.githubusercontent.com/iHost-Open-Source-Project/hassio-ihost-addon/master/hassio-ihost-silabs-multiprotocol/images/architecture.png)

## Support

Got questions?

You have several options to get them answered:

- The [The SONOFF Dongle Website][discord].
- Join the [Reddit subreddit][reddit] in [/r/sonoffdongle][reddit]

In case you've found a bug, please [open an issue on our GitHub][issue].

[discord]: https://dongle.sonoff.tech
[reddit]: https://www.reddit.com/r/sonoffdongle
[issue]: https://github.com/iHost-Open-Source-Project/hassio-ihost-addon/issues
[sonoff-dongle-flasher]: https://dongle.sonoff.tech/sonoff-dongle-flasher
[dongle-flasher-addon]: https://github.com/iHost-Open-Source-Project/hassio-ihost-addon/blob/master/hassio-ihost-sonoff-dongle-flasher/DOCS.md
