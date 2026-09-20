"""Instrument exact generated call sites; refuse drift. Does not edit SDK files."""
from pathlib import Path
import json
import sys
root = Path(sys.argv[1])
recipe = Path(__file__).parent
handler = root / "generated/autogen/sl_event_handler.c"
s = handler.read_text()
assert "startup_trace" not in s
s = 'extern void startup_trace_mark(unsigned char);\nextern void startup_trace_cpc_ready(void);\n' + s
calls = ["sl_clock_manager_runtime_init", "bootloader_init", "sl_dma_manager_instances_init",
         "nvm3_initDefault", "sl_ot_crash_handler_init", "sl_gpio_init", "sl_cpc_init",
         "sl_mbedtls_init", "psa_crypto_init", "sl_se_init", "sli_protocol_crypto_init",
         "sli_aes_seed_mask", "sl_rail_util_dma_init", "sl_rail_util_pa_init",
         "sl_rail_util_pti_init", "sl_rail_util_rf_path_init", "sl_rail_util_rssi_init",
         "sl_ot_sys_init", "sl_ot_init"]
markers = {"00": "app_init_early: clocks/sleeptimer/MPU already returned", "FF": "final checkpoint inside app_init; permanent UART handoff before processing"}
for i, call in enumerate(calls, 1):
    needle = f"  {call}();"
    assert s.count(needle) == 1, call
    enter, leave = i * 2 - 1, i * 2
    ready = "\n  startup_trace_cpc_ready();" if call == "sl_cpc_init" else ""
    s = s.replace(needle, f"  startup_trace_mark(0x{enter:02X});\n{needle}{ready}\n  startup_trace_mark(0x{leave:02X});")
    markers[f"{enter:02X}"] = f"before {call}"
    markers[f"{leave:02X}"] = f"after {call}"
handler.write_text(s)
app = root / "source/app.c"
s = app.read_text()
needle = "    sl_host_wakeup_init();"
assert s.count(needle) == 1
s = 'extern void startup_trace_finish(void);\n' + s.replace(needle, needle + "\n    startup_trace_finish();")
app.write_text(s)
(root / "source/startup_trace.c").write_bytes((recipe / "startup_trace.c").read_bytes())
cm = root / "generated/cmake_gcc/rcp-uart-802154.cmake"
s = cm.read_text()
assert "add_library(slc" in s
s += '\n# Local diagnostic only; same target options and SDK configuration.\ntarget_sources(slc PRIVATE "' + str(root / "source/startup_trace.c") + '")\n'
cm.write_text(s)
(root / "evidence/startup-markers.json").write_text(json.dumps(markers, indent=2) + "\n")
