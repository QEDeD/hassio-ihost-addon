"""Offline transformation checks; set SDK_CPC_UART_SOURCE to the pinned vendor file."""
import os
from pathlib import Path
import struct
import unittest
import instrument as m


class BootstrapTests(unittest.TestCase):
    source = None

    @classmethod
    def setUpClass(cls):
        if cls.source is None:
            cls.source = Path(os.environ["SDK_CPC_UART_SOURCE"]).read_text()

    def test_pinned_source_and_drift_rejection(self):
        m.overlay_driver(self.source)
        for bad in (self.source + "\n", self.source.replace("static void restart_dma(void)", "static void changed_restart(void)", 1)):
            with self.assertRaises(RuntimeError):
                m.overlay_driver(bad)

    def test_only_restart_changes_beyond_receive_diagnostic(self):
        before = m.receive_overlay_driver(self.source)
        after = m.overlay_driver(self.source)
        a, b, fn = m.function_span(before, "static void restart_dma(void)")
        c, d, patched = m.function_span(after, "static void restart_dma(void)")
        self.assertEqual(before[:a], after[:c])
        self.assertEqual(before[b:], after[d:])
        restored = patched.replace(m.BOOTSTRAP_INIT, m.ORIGINAL_INIT, 1).replace(
            "/* Initial LINK and DONEIEN are loaded from the bootstrap descriptor. */", m.LIVE_EDITS, 1)
        self.assertEqual(fn, restored)
        self.assertNotIn("LDMA_PERIPH->CH[read_channel].LINK |=", patched)
        self.assertNotIn("LDMA_PERIPH->CH[read_channel].CTRL |=", patched)
        self.assertIn("#else\n" + m.ORIGINAL_INIT + "\n#endif", patched)
        self.assertLess(patched.index("rx_descriptor_head->xfer.xfer_count"), patched.index("initial_rx_descriptor ="))
        self.assertLess(patched.index("initial_rx_descriptor.xfer.done_ifs ="), patched.index("sl_hal_ldma_start_transfer"))
        self.assertIn("static sl_hal_ldma_descriptor_t initial_rx_descriptor __attribute__((aligned(4)))", patched)

    def test_guard_rejects_changed_start_order_and_live_edits(self):
        _, _, fn = m.function_span(self.source, "static void restart_dma(void)")
        for old, new in [("SLI_CPC_HDLC_HEADER_RAW_SIZE - 1;", "6;"),
                         ("LINK |= LDMA_CH_LINK_LINK;", "LINK = LDMA_CH_LINK_LINK;")]:
            with self.assertRaises(RuntimeError):
                m.bootstrap_restart(fn.replace(old, new))

    def test_bootstrap_descriptor_invariants(self):
        # MG21 header: DONEIEN bit20, LINK bit1; 4-word descriptor layout.
        # Representative reviewed seven-byte descriptor0 points at descriptor1.
        ring0 = (0x03000060, 0x50008030, 0x20005000, 0x20000E00)
        ring1 = (0x03001100, 0x50008030, 0x20005200, 0x20000DF0)
        original = (ring0, ring1)
        bootstrap = (ring0[0] | (1 << 20), ring0[1], ring0[2], ring0[3] | 2)
        self.assertEqual(len(struct.pack("<4I", *bootstrap)), 16)
        self.assertEqual(bootstrap[0] ^ ring0[0], 1 << 20)
        self.assertEqual(bootstrap[1:3], ring0[1:3])
        self.assertEqual(bootstrap[3] & ~3, ring0[3])
        self.assertEqual((ring0, ring1), original)
        self.assertEqual(((bootstrap[0] >> 4) & 0x7FF) + 1, 7)
        self.assertEqual(ring0[3] & 3, 0)
        self.assertEqual(ring1[3] & 3, 0)


if __name__ == "__main__":
    unittest.main(verbosity=2)
