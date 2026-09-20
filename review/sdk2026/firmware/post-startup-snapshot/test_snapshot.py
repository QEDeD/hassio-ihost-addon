import binascii
import json
from pathlib import Path
import unittest
import snapshot as m


def valid_record():
    values = [{"format_version":1, "build_id":0x504F5331}.get(name,i) for i,name in enumerate(m.field_names())]
    body = ("@POST1:%04X:" % len(values) + ":".join("%08X" % v for v in values)).encode()
    return b"\r\n" + body + (":%04X\r\n" % binascii.crc_hqx(body,0)).encode()


class Tests(unittest.TestCase):
    def test_fixed_record_and_crc(self):
        raw = valid_record()
        self.assertLessEqual(len(raw),1024)
        self.assertEqual(m.decode(b"partial CPC bytes" + raw)["format_version"],1)
        bad = raw.replace(b"00000001",b"00000002",1)
        with self.assertRaises(m.SnapshotError): m.decode(bad)
    def test_truncation_duplicate_and_wrong_count(self):
        raw = valid_record()
        for bad in (raw[:-1],raw[:-7],raw+raw,raw.replace(b"@POST1:",b"@POST1:FFFF",1),b"nothing"):
            with self.subTest(bad=bad[:20]):
                with self.assertRaises(m.SnapshotError): m.decode(bad)
    def test_split_raw_rx_and_final_launch_selection(self):
        raw=valid_record()
        run="2026 serialx.protocol DEBUG Immediately writing <GeckoBootloaderOption.RUN_FIRMWARE: b'2'>"
        log="\n".join([run,"2026 serialx.protocol DEBUG Received "+repr(raw),run,
            "2026 serialx.protocol DEBUG Immediately writing "+repr(raw),
            *["2026 serialx.protocol DEBUG Received "+repr(raw[n:n+7]) for n in range(0,len(raw),7)]])
        self.assertEqual(m.extract_received(log),raw)
        self.assertEqual(m.decode(m.extract_received(log)),m.decode(raw))
    def test_no_launch_and_overflow_rejected(self):
        with self.assertRaises(m.SnapshotError): m.extract_received("2026 serialx.protocol DEBUG Received b'no'")
        log="2026 serialx.protocol DEBUG Immediately writing <GeckoBootloaderOption.RUN_FIRMWARE: b'2'>\n2026 serialx.protocol DEBUG Received "+repr(b'x'*8193)
        with self.assertRaises(m.SnapshotError): m.extract_received(log)

if __name__ == "__main__": unittest.main(verbosity=2)
