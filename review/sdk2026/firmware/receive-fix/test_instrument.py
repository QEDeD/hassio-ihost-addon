"""Offline normal-firmware patch checks; set SDK_CPC_UART_SOURCE."""
import hashlib
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import instrument as m

EXPECTED_RESTART_SHA = "aab4641d64a1a49ab5f621dec656287d5d61539da5419cb2ea0d54138a502297"

class FixTests(unittest.TestCase):
    source = None
    @classmethod
    def setUpClass(cls):
        if cls.source is None:
            cls.source = Path(os.environ["SDK_CPC_UART_SOURCE"]).read_text()

    def test_exact_rxb1_restart_and_no_diagnostics(self):
        result = m.overlay_driver(self.source)
        _, _, fn = m.function_span(result, "static void restart_dma(void)")
        self.assertEqual(hashlib.sha256(fn.encode()).hexdigest(), EXPECTED_RESTART_SHA)
        self.assertNotIn("post_snapshot", result)
        self.assertNotIn("SysTick", result)
        self.assertNotIn("snapshot.h", result)

    def test_only_restart_changed_and_hwfc_preserved(self):
        result = m.overlay_driver(self.source)
        a, b, old = m.function_span(self.source, "static void restart_dma(void)")
        c, d, new = m.function_span(result, "static void restart_dma(void)")
        self.assertEqual(self.source[:a], result[:c])
        self.assertEqual(self.source[b:], result[d:])
        self.assertIn("#else\n" + m.ORIGINAL_INIT + "\n#endif", new)
        restored = new.replace(m.BOOTSTRAP_INIT, m.ORIGINAL_INIT, 1).replace(
            "/* Initial LINK and DONEIEN are loaded from the bootstrap descriptor. */", m.LIVE_EDITS, 1)
        self.assertEqual(restored, old)

    def test_rejects_source_and_anchor_drift(self):
        with self.assertRaises(RuntimeError): m.overlay_driver(self.source + "\n")
        _, _, fn = m.function_span(self.source, "static void restart_dma(void)")
        with self.assertRaises(RuntimeError):
            m.bootstrap_restart(fn.replace("SLI_CPC_HDLC_HEADER_RAW_SIZE - 1;", "6;"))

    def test_prepare_preserves_all_other_inputs(self):
        with tempfile.TemporaryDirectory(prefix="receive-fix-check-") as tmp:
            base = Path(tmp); sdk = base / "sdk"; root = base / "work"
            driver = sdk / "cpc/src/sl_cpc_drv_uart.c"
            driver.parent.mkdir(parents=True); driver.write_bytes(self.source.encode("utf-8"))
            preserved = {"source/app.c": "APP_SHA", "generated/autogen/sl_event_handler.c": "HANDLER_SHA",
                         "generated/config/sl_cpc_config.h": "CONFIG_SHA"}
            hashes = {}
            for path, const in preserved.items():
                p = root / path; p.parent.mkdir(parents=True, exist_ok=True)
                p.write_bytes(("unchanged fixture for " + path + "\n").encode("utf-8"))
                hashes[const] = hashlib.sha256(p.read_bytes()).hexdigest()
            cmake = root / "generated/cmake_gcc/rcp-uart-802154.cmake"
            cmake.parent.mkdir(parents=True)
            original = 'add_library(slc "${SDK_PATH}/cpc/src/sl_cpc_drv_uart.c")\n# target flags preserved\n'
            cmake.write_bytes(original.encode("utf-8"))
            before = {p: p.read_bytes() for p in root.rglob("*") if p.is_file()}
            with patch.multiple(m, **hashes): m.prepare(root, sdk)
            for path in preserved:
                self.assertEqual((root / path).read_bytes(), before[root / path])
            self.assertEqual(driver.read_text(), self.source)
            self.assertEqual(cmake.read_text(), original.replace('"${SDK_PATH}/cpc/src/sl_cpc_drv_uart.c"',
                '"' + str((root / "source/sl_cpc_drv_uart_receive_fix.c").resolve()) + '"'))
            added = {p.relative_to(root).as_posix() for p in root.rglob("*") if p.is_file() and p not in before}
            self.assertEqual(added, {"source/sl_cpc_drv_uart_receive_fix.c", "evidence/receive-fix-overlay.json"})

if __name__ == "__main__": unittest.main(verbosity=2)
