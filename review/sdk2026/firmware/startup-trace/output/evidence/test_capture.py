import asyncio
import importlib.util
import pathlib
import unittest
from unittest.mock import Mock, patch
from universal_silabs_flasher import gecko_bootloader as g


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, pathlib.Path(__file__).with_name(path))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module

capture = load("capture", "capture-launch.py")
parser = load("parser", "parse-markers.py")


class CaptureTests(unittest.IsolatedAsyncioTestCase):
    async def test_actual_launch_keeps_received_markers(self):
        old = g.RUN_APPLICATION_DELAY
        capture.configure_capture(g)
        self.assertEqual(g.RUN_APPLICATION_DELAY, 30.0)
        p = g.GeckoBootloaderProtocol()
        p._transport = Mock()
        p._state_machine.state = g.State.IN_MENU
        real_timeout = asyncio.timeout
        seen = []
        def short_timeout(delay):
            seen.append(delay)
            return real_timeout(0.025)
        async def receive():
            await asyncio.sleep(0.005)
            p.data_received(b"\r\n@S00\r\n")
        try:
            with patch.object(g.asyncio, "timeout", short_timeout):
                await asyncio.gather(p.run_firmware(), receive())
            self.assertEqual(seen, [30.0, 30.0])  # RUN and vendor state-machine wait
            p._transport.write.assert_called_once_with(b"2")
            self.assertIn(b"@S00", p._buffer)
        finally:
            g.RUN_APPLICATION_DELAY = old

    async def test_returning_menu_still_fails(self):
        p = g.GeckoBootloaderProtocol()
        p._transport = Mock()
        p._state_machine.state = g.State.IN_MENU
        async def menu():
            await asyncio.sleep(0.005)
            p.data_received(b"\r\nGecko Bootloader v1.12.00\r\n1. upload gbl\r\n2. run\r\n3. ebl info\r\nBL > ")
        task = asyncio.create_task(menu())
        with self.assertRaises(g.NoFirmwareError):
            await p.run_firmware()
        await task
        p._transport.write.assert_called_once_with(b"2")

    def test_source_and_version_guards(self):
        with patch.object(capture.importlib.metadata, "version", return_value="9.9"):
            with self.assertRaises(RuntimeError): capture.configure_capture(g)
        with patch.object(capture.Path, "read_bytes", return_value=b"changed"):
            with self.assertRaises(RuntimeError): capture.configure_capture(g)

    def test_only_rx_and_split_markers(self):
        text = "\n".join([
            "x serialx.descriptor_transport DEBUG Received b'\\r\\n@S77\\r\\n'",
            "x serialx.descriptor_transport DEBUG Sending b'2'",
            "x serialx.descriptor_transport DEBUG Received b'\\r\\n@S66\\r\\n'",
            "x serialx.descriptor_transport DEBUG Sending b'2'",
            "x serialx.descriptor_transport DEBUG Sending b'\\r\\n@S99\\r\\n'",
            "x serialx.descriptor_transport DEBUG Received b'noise\\r\\n@S'",
            "x serialx.descriptor_transport DEBUG Received b'00\\r\\n\\r\\n@S01\\r\\n'",
            "x other DEBUG Received b'\\r\\n@S88\\r\\n'",
        ])
        self.assertEqual(parser.extract(text), ["\r\n@S00\r\n", "\r\n@S01\r\n"])

    def test_missing_launch_rejected(self):
        with self.assertRaisesRegex(ValueError, "No logged"):
            parser.extract("x serialx.descriptor_transport DEBUG Received b'noise'")


if __name__ == "__main__": unittest.main(verbosity=2)
