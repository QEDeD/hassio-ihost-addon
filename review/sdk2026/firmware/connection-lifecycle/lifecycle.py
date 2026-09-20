"""Bounded, version-query-only observation using the pinned flasher transport.
No serial owner is opened by the launch adapter. Run only in an approved window.
"""
import asyncio
import hashlib
import importlib.metadata
import json
import logging
from pathlib import Path
import struct
import time

from universal_silabs_flasher import cpc, cpc_types as t, gecko_bootloader as g

LOG = logging.getLogger("cpc_lifecycle")
EARLY_SECONDS = 0.25
LATE_SECONDS = 30.0
QUERY_TIMEOUT = 1.0
GECKO_HASH = "0bf3416d42ec8bd658cdf892e5b83ee2eccac3cfd69836b82a8b70b9a872b9ee"
CPC_HASH = "6629d5e610c1ef8663b468973d1f2bdcaadca4a6936a90fc25ee2187e20d7689"


def event(kind, **fields):
    LOG.info("LIFECYCLE %s", json.dumps(dict(event=kind, monotonic=time.monotonic(), **fields), sort_keys=True))


def verify_sources():
    if importlib.metadata.version("universal-silabs-flasher") != "1.1.0":
        raise RuntimeError("Requires reviewed flasher 1.1.0")
    for module, expected in [(g, GECKO_HASH), (cpc, CPC_HASH)]:
        if hashlib.sha256(Path(module.__file__).read_bytes()).hexdigest() != expected:
            raise RuntimeError("Pinned flasher source differs")
    if g.RUN_APPLICATION_DELAY != 2.0:
        raise RuntimeError("Unexpected launch timeout modification")


class ObservationError(RuntimeError):
    pass


class CheckedCPC(cpc.CPCProtocol):
    """Vendor parser plus strict version-reply qualification."""
    def __init__(self):
        super().__init__()
        self.rx_bytes = 0
        self.frame_count = 0
        self.failure = None
        self.expected_close = False

    def data_received(self, data):
        self.rx_bytes += len(data)
        if self.failure is not None:
            return
        try:
            super().data_received(data)
        except Exception as exc:
            self.fail("parser_error:" + type(exc).__name__)

    def fail(self, reason):
        if self.failure is None:
            self.failure = reason
            event("observation_error", reason=reason)
        for future in self._pending_frames.values():
            if not future.done():
                future.cancel()

    def connection_lost(self, exc):
        super().connection_lost(exc)
        if not self.expected_close:
            self.fail("transport_lost")

    def frame_received(self, frame):
        self.frame_count += 1
        sub = frame.payload
        valid = (
            frame.endpoint == t.EndpointId.SYSTEM
            and frame.unnumbered_type() == t.UnnumberedFrameType.POLL_FINAL
            and isinstance(sub, cpc.UnnumberedFrame)
            and sub.command_id == t.UnnumberedFrameCommandId.PROP_VALUE_IS
            and isinstance(sub.payload, cpc.PropertyCommand)
            and sub.payload.property_id == t.PropertyId.SECONDARY_CPC_VERSION
            and len(sub.payload.value) == 12
        )
        if valid:
            super().frame_received(frame)  # vendor correlates sequence, ignores stale replies
        else:
            event("non_version_frame", endpoint=int(frame.endpoint))


async def query(protocol, phase):
    if protocol.failure is not None:
        raise ObservationError(protocol.failure)
    before = protocol.rx_bytes
    seq = protocol._command_seq
    event("query_begin", phase=phase, sequence=seq)
    try:
        frame = await protocol.send_unnumbered_frame(
            t.UnnumberedFrameCommandId.PROP_VALUE_GET,
            cpc.PropertyCommand(t.PropertyId.SECONDARY_CPC_VERSION, b""),
            retries=1, timeout=QUERY_TIMEOUT, retry_delay=0.1,
        )
    except asyncio.CancelledError:
        if protocol.failure is not None:
            raise ObservationError(protocol.failure) from None
        raise
    except TimeoutError:
        if protocol.failure is not None:
            raise ObservationError(protocol.failure) from None
        result = dict(phase=phase, sequence=seq, result="timeout", rx_bytes=protocol.rx_bytes-before)
    else:
        if protocol.failure is not None:
            raise ObservationError(protocol.failure)
        version = ".".join(map(str, struct.unpack("<III", frame.payload.payload.value)))
        result = dict(phase=phase, sequence=seq, result="reply", version=version, rx_bytes=protocol.rx_bytes-before)
    event("query_end", **result)
    return result


def install_launch_observation():
    verify_sources()
    cls = g.GeckoBootloaderProtocol
    if getattr(cls, "_lifecycle_installed", False):
        raise RuntimeError("Lifecycle adapter already installed")
    original_run, original_rx, original_lost = cls.run_firmware, cls.data_received, cls.connection_lost

    def receive(self, data):
        original_rx(self, data)  # preserve bootloader-menu failure detection
        observer = getattr(self, "_lifecycle_observer", None)
        if observer is not None:
            observer.data_received(data)

    def lost(self, exc):
        original_lost(self, exc)
        observer = getattr(self, "_lifecycle_observer", None)
        if observer is not None:
            observer.connection_lost(exc)

    async def run(self):
        # Only the launch following a successful upload; prior discovery stays untouched.
        if self._upload_status != "complete":
            return await original_run(self)
        if getattr(self, "_lifecycle_ran", False):
            raise RuntimeError("Refusing duplicate diagnostic launch")
        self._lifecycle_ran = True
        observer = CheckedCPC()
        observer._transport = self._transport  # same writer; never connect another reader
        self._lifecycle_observer = observer
        started = time.monotonic()
        event("launch_observation_begin", expected_baudrate=115200, expected_xonxoff=False, expected_rtscts=False)

        async def observations():
            results = []
            for delay, phase in [(EARLY_SECONDS, "early"), (LATE_SECONDS, "pre_close")]:
                await asyncio.sleep(max(0, started + delay - time.monotonic()))
                if self._transport is None:
                    raise ConnectionError("Launch connection lost")
                if self._state_machine.state == g.State.IN_MENU:
                    raise g.NoFirmwareError("Bootloader menu returned")
                results.append(await query(observer, phase))
            if self._state_machine.state == g.State.IN_MENU:
                raise g.NoFirmwareError("Bootloader menu returned")
            self._lifecycle_results = results
            event("launch_observation_complete", results=results)

        tasks = [asyncio.create_task(original_run(self)), asyncio.create_task(observations())]
        try:
            async with asyncio.timeout(36):
                await asyncio.gather(*tasks)
        except asyncio.CancelledError:
            if self._transport is None:
                raise ConnectionError("Launch connection lost") from None
            raise
        finally:
            for task in tasks:
                task.cancel()
            await asyncio.gather(*tasks, return_exceptions=True)
            self._lifecycle_observer = None

    cls.run_firmware, cls.data_received, cls.connection_lost = run, receive, lost
    cls._lifecycle_installed = True
    return original_run, original_rx, original_lost


async def probe_reopened(device):
    from universal_silabs_flasher.common import connect_protocol
    verify_sources()
    # Run as a separate process only after the flash CLI has exited and released the port.
    async with connect_protocol(device, 115200, CheckedCPC) as protocol:
        try:
            protocol._command_seq = 2  # do not accept a delayed early/pre-close response
            return await query(protocol, "reopened")
        finally:
            protocol.expected_close = True
