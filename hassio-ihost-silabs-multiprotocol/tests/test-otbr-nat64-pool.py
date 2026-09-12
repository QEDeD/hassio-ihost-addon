#!/usr/bin/env python3
import pathlib
import runpy
import subprocess
import unittest
from unittest.mock import patch

SOURCE = pathlib.Path(__file__).resolve().parents[1] / "rootfs/etc/s6-overlay/scripts/otbr-nat64-pool-check"
MODULE = runpy.run_path(str(SOURCE))
CHECK = MODULE["check"]


class PoolTests(unittest.TestCase):
    def test_defaults_and_unrelated_routes(self):
        CHECK([], [{"dst": "default"}, {"dst": "0.0.0.0/0", "table": 200},
                   {"dst": "10.0.0.0/8"}])

    def test_all_overlapping_route_shapes(self):
        for destination in ["192.168.255.0/24", "192.168.255.42/32", "192.168.0.0/16"]:
            with self.subTest(destination=destination), self.assertRaises(ValueError):
                CHECK([], [{"dst": destination, "table": 200}])

    def test_interface_overlap(self):
        with self.assertRaises(ValueError):
            CHECK([{"addr_info": [{"family": "inet", "local": "192.168.255.1", "prefixlen": 24}]}], [])

    def test_malformed_inspection(self):
        for rows in [[{}], [{"dst": "nonsense"}], [{"dst": "::/0"}]]:
            with self.subTest(rows=rows), self.assertRaises((ValueError, KeyError)):
                CHECK([], rows)

    def test_inspection_command_and_failure(self):
        with patch.object(subprocess, "run", return_value=subprocess.CompletedProcess([], 0, "[]")) as run:
            MODULE["inspect"](["route", "show", "table", "all"])
            self.assertEqual(run.call_args.args[0], ["ip", "-j", "-4", "route", "show", "table", "all"])
        with patch.object(subprocess, "run", side_effect=subprocess.TimeoutExpired("ip", 1)):
            self.assertEqual(MODULE["main"](), 1)
        with patch.object(subprocess, "run", return_value=subprocess.CompletedProcess([], 0, "{}")):
            self.assertEqual(MODULE["main"](), 1)


if __name__ == "__main__":
    unittest.main()
