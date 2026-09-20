import asyncio
import dataclasses
import struct
import unittest
from unittest.mock import patch

import lifecycle as m
from universal_silabs_flasher import cpc, cpc_types as t, gecko_bootloader as g

STARTUP = bytes.fromhex("14000e00c0114f060008000000000078000000c386")
MENU = b"\r\nGecko Bootloader v1.12.00\r\n1. upload gbl\r\n2. run\r\n3. ebl info\r\nBL > "


def reply(request, *, seq=None, prop=None, endpoint=None):
    frame, rest = cpc.CPCTransportFrame.deserialize(request)
    assert not rest
    sub = dataclasses.replace(frame.payload,
        command_id=t.UnnumberedFrameCommandId.PROP_VALUE_IS,
        command_seq=frame.payload.command_seq if seq is None else type(frame.payload.command_seq)(seq),
        payload=cpc.PropertyCommand(prop or t.PropertyId.SECONDARY_CPC_VERSION, struct.pack("<III",4,9,1)))
    return dataclasses.replace(frame, payload=sub, endpoint=frame.endpoint if endpoint is None else endpoint).serialize()


class Wire:
    def __init__(self, receiver, mode="reply"):
        self.receiver, self.mode, self.writes = receiver, mode, []
    def write(self, data):
        data = bytes(data)
        self.writes.append(data)
        loop = asyncio.get_running_loop()
        if data == b"2":
            loop.call_later(.001, self.receiver.data_received, MENU if self.mode == "menu" else STARTUP)
        elif data.startswith(b"\x14") and self.mode == "reply":
            data = reply(data)
            loop.call_later(.001, self.receiver.data_received, data[:6])
            loop.call_later(.002, self.receiver.data_received, data[6:])


class Tests(unittest.IsolatedAsyncioTestCase):
    def setUp(self):
        self.original_run, self.original_rx, self.original_lost = m.install_launch_observation()
        self.patches = [patch.object(g,"RUN_APPLICATION_DELAY",.03), patch.object(m,"EARLY_SECONDS",.005), patch.object(m,"LATE_SECONDS",.05), patch.object(m,"QUERY_TIMEOUT",.01)]
        for p in self.patches: p.start()
    def tearDown(self):
        for p in reversed(self.patches): p.stop()
        g.GeckoBootloaderProtocol.run_firmware = self.original_run
        g.GeckoBootloaderProtocol.data_received = self.original_rx
        g.GeckoBootloaderProtocol.connection_lost = self.original_lost
        del g.GeckoBootloaderProtocol._lifecycle_installed
    def protocol(self, mode="reply", uploaded=True):
        p = g.GeckoBootloaderProtocol()
        p._state_machine.state = g.State.IN_MENU
        p._upload_status = "complete" if uploaded else None
        p._transport = Wire(p, mode)
        return p
    async def test_same_wire_split_replies_and_distinct_sequences(self):
        p = self.protocol()
        await p.run_firmware()
        self.assertEqual([r["result"] for r in p._lifecycle_results], ["reply","reply"])
        self.assertEqual([r["sequence"] for r in p._lifecycle_results], [0,1])
        self.assertEqual(len(p._transport.writes),3) # one RUN and two GETs; no resets or SETs
        self.assertEqual(p._transport.writes[1].hex(),"14000a00c455d30200040003000000db12")
        with self.assertRaisesRegex(RuntimeError,"duplicate"): await p.run_firmware()
    async def test_silent_device_bounded_and_no_startup_false_positive(self):
        p = self.protocol("silence")
        await p.run_firmware()
        self.assertEqual([r["result"] for r in p._lifecycle_results], ["timeout","timeout"])
        self.assertEqual(len(p._transport.writes),5) # two attempts per phase
        self.assertIsNone(p._lifecycle_observer)
    async def test_returned_menu_aborts_without_queries(self):
        p = self.protocol("menu")
        with self.assertRaises(g.NoFirmwareError): await p.run_firmware()
        await asyncio.sleep(.06)
        self.assertEqual(p._transport.writes,[b"2"])
    async def test_initial_probe_launch_unmodified(self):
        p = self.protocol(uploaded=False)
        await p.run_firmware()
        self.assertEqual(p._transport.writes,[b"2"])
        self.assertFalse(hasattr(p,"_lifecycle_results"))
    async def test_cancel_stops_future_writes(self):
        p = self.protocol("silence")
        task = asyncio.create_task(p.run_firmware())
        await asyncio.sleep(.02); task.cancel()
        with self.assertRaises(asyncio.CancelledError): await task
        n = len(p._transport.writes)
        await asyncio.sleep(.12)
        self.assertEqual(len(p._transport.writes),n)
    async def test_disconnect_aborts_pending_query(self):
        p = self.protocol("silence")
        task = asyncio.create_task(p.run_firmware())
        await asyncio.sleep(.02)
        p.connection_lost(None)
        with self.assertRaises((ConnectionError, RuntimeError)): await task
        self.assertIsNone(p._lifecycle_observer)

    async def test_bad_wrong_and_stale_replies_do_not_complete_query(self):
        p = m.CheckedCPC(); p._command_seq = 2; p._transport = Wire(p,"silence")
        task = asyncio.create_task(m.query(p,"reopened"))
        await asyncio.sleep(.001)
        req = p._transport.writes[0]
        p.data_received(STARTUP)
        p.data_received(reply(req,seq=0))
        p.data_received(reply(req,prop=t.PropertyId.SECONDARY_APP_VERSION))
        p.data_received(reply(req,endpoint=t.EndpointId.SECURITY))
        bad = bytearray(reply(req)); bad[-1] ^= 1; p.data_received(bad)
        await asyncio.sleep(.001)
        self.assertFalse(task.done())
        p.data_received(reply(req))
        result = await task
        self.assertEqual(result["result"],"reply")
        self.assertEqual(result["sequence"],2)

    async def test_unknown_valid_command_is_parser_failure_not_timeout(self):
        p = m.CheckedCPC(); p._transport = Wire(p,"silence")
        task = asyncio.create_task(m.query(p,"reopened"))
        await asyncio.sleep(.001)
        # CRC-valid unnumbered NOOP, unsupported by the pinned parser.
        from universal_silabs_flasher.common import crc16_ccitt
        header = bytes.fromhex("14000600c4")
        payload = bytes.fromhex("00000000")
        raw = header + crc16_ccitt(header).to_bytes(2,"little") + payload + crc16_ccitt(payload).to_bytes(2,"little")
        p.data_received(raw)
        with self.assertRaisesRegex(m.ObservationError,"parser_error:KeyError"): await task
        self.assertEqual(len(p._transport.writes),1)
        with self.assertRaises(m.ObservationError): await m.query(p,"next")

    async def test_reopened_disconnect_is_not_response_timeout(self):
        p = m.CheckedCPC(); p._transport = Wire(p,"silence")
        task = asyncio.create_task(m.query(p,"reopened"))
        await asyncio.sleep(.001)
        p.connection_lost(None)
        with self.assertRaisesRegex(m.ObservationError,"transport_lost"): await task

    async def test_expected_close_is_not_reported_as_failure(self):
        p = m.CheckedCPC(); p._transport = Wire(p)
        p.expected_close = True
        p.connection_lost(None)
        self.assertIsNone(p.failure)

class Guards(unittest.TestCase):
    def test_version_and_source_drift_fail_before_action(self):
        with patch.object(m.importlib.metadata,"version",return_value="9"):
            with self.assertRaises(RuntimeError): m.verify_sources()
        with patch.object(m.Path,"read_bytes",return_value=b"drift"):
            with self.assertRaises(RuntimeError): m.verify_sources()

if __name__ == "__main__": unittest.main(verbosity=2)
