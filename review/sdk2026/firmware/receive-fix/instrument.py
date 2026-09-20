"""Guarded normal-firmware bootstrap correction; no diagnostic instrumentation."""
from pathlib import Path
import hashlib
import json
import sys

DRIVER_SHA = '2fe944161fbec7240c5ac83ebf76a445d7f9a7a6282ef3b135e77a567634f6d5'
APP_SHA = '311be88effa602bbd40264ec51abfd90f3ee39d4591e3918ff98639f75ff74e8'
HANDLER_SHA = 'd23f9f02a39fa55bba2e90e99c5d69803bc2460698e8ffcbcdf77898bd9aa884'
CONFIG_SHA = 'be1581f8a6a17d509fa5bf224423fdc820e2e914d803659a99928fda54e8ef2e'
BOOTSTRAP_INIT = '#if (SL_CPC_DRV_UART_FLOW_CONTROL_TYPE == WITHOUT_HWFC)\n  /* Load the complete initial hardware state from stable RAM. The two\n   * reusable descriptors retain their original spill semantics. */\n  static sl_hal_ldma_descriptor_t initial_rx_descriptor __attribute__((aligned(4)));\n  _Static_assert(sizeof(initial_rx_descriptor) == 16u, "Reviewed LDMA descriptor size changed");\n  initial_rx_descriptor = *rx_descriptor_head;\n  initial_rx_descriptor.xfer.link = 1u;\n  initial_rx_descriptor.xfer.done_ifs = 1u;\n  sl_hal_ldma_init_transfer(LDMA_PERIPH, read_channel, &rx_config, &initial_rx_descriptor);\n#else\n  sl_hal_ldma_init_transfer(LDMA_PERIPH, read_channel, &rx_config, rx_descriptor_head);\n#endif'
ORIGINAL_INIT = '  sl_hal_ldma_init_transfer(LDMA_PERIPH, read_channel, &rx_config, rx_descriptor_head);'
LIVE_EDITS = '#if (SL_CPC_DRV_UART_FLOW_CONTROL_TYPE == WITHOUT_HWFC)\n  LDMA_PERIPH->CH[read_channel].LINK |= LDMA_CH_LINK_LINK;\n\n  // Enable interrupts\n#ifdef _LDMA_CH_CTRL_DONEIEN_MASK\n  LDMA_PERIPH->CH[read_channel].CTRL |= LDMA_CH_CTRL_DONEIEN;\n#else\n  LDMA_PERIPH->CH[read_channel].CTRL |= LDMA_CH_CTRL_DONEIFSEN;\n#endif\n#endif'


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def replace_once(text, old, new):
    require(text.count(old) == 1, f"Expected exactly one hook: {old!r}")
    return text.replace(old, new)


def function_span(text, signature):
    start = text.index(signature + "\n{")
    end = text.index("\n}\n", start) + 3
    return start, end, text[start:end]


def bootstrap_restart(fn):
    # Preserve the common seven-byte initialization and every surrounding line.
    require(fn.count("rx_descriptor_head = &rx_descriptor[0];") == 1, "RX head setup changed")
    require(fn.count("rx_descriptor_head->xfer.xfer_count = SLI_CPC_HDLC_HEADER_RAW_SIZE - 1;") == 1,
            "Initial header count changed")
    require(fn.index("rx_descriptor_head->xfer.xfer_count") < fn.index(ORIGINAL_INIT),
            "Initial descriptor copy must follow count setup")
    modified = replace_once(fn, ORIGINAL_INIT, BOOTSTRAP_INIT)
    modified = replace_once(modified, LIVE_EDITS, "/* Initial LINK and DONEIEN are loaded from the bootstrap descriptor. */")
    restored = modified.replace(BOOTSTRAP_INIT, ORIGINAL_INIT, 1).replace(
        "/* Initial LINK and DONEIEN are loaded from the bootstrap descriptor. */", LIVE_EDITS, 1)
    require(restored == fn, "Bootstrap patch changed surrounding restart behavior")
    return modified

def checked_read(path, expected):
    data = path.read_bytes()
    require(hashlib.sha256(data).hexdigest() == expected, f"Unreviewed input: {path}")
    return data.decode("utf-8")


def overlay_driver(original):
    require(hashlib.sha256(original.encode()).hexdigest() == DRIVER_SHA, "Driver checksum mismatch")
    a, b, fn = function_span(original, "static void restart_dma(void)")
    return original[:a] + bootstrap_restart(fn) + original[b:]


def prepare(root, sdk):
    root = root.resolve()
    sdk = sdk.resolve()
    require(root != sdk and sdk not in root.parents, "Working tree must not be inside SDK")
    original_path = sdk / "cpc/src/sl_cpc_drv_uart.c"
    original = checked_read(original_path, DRIVER_SHA)
    driver = overlay_driver(original)
    preserved = {
        root / "source/app.c": APP_SHA,
        root / "generated/autogen/sl_event_handler.c": HANDLER_SHA,
        root / "generated/config/sl_cpc_config.h": CONFIG_SHA,
    }
    for path, digest in preserved.items():
        checked_read(path, digest)
    cmake_path = root / "generated/cmake_gcc/rcp-uart-802154.cmake"
    cmake_original = cmake_path.read_text()
    require('add_library(slc' in cmake_original, "Generated CMake target changed")
    overlay_path = root / "source/sl_cpc_drv_uart_receive_fix.c"
    cmake = replace_once(cmake_original, '"${SDK_PATH}/cpc/src/sl_cpc_drv_uart.c"', '"' + str(overlay_path) + '"')
    # All guards above precede mutation. No target flags or other inputs change.
    overlay_path.write_text(driver)
    cmake_path.write_text(cmake)
    evidence = root / "evidence"
    evidence.mkdir(exist_ok=True)
    manifest = {
        "purpose": "normal full firmware; bootstrap descriptor correction only; no diagnostics",
        "driver_input_sha256": DRIVER_SHA,
        "driver_overlay_sha256": hashlib.sha256(driver.encode()).hexdigest(),
        "cmake_sha256": hashlib.sha256(cmake.encode()).hexdigest(),
        "preserved_original_inputs": {str(p.relative_to(root)): h for p, h in preserved.items()},
    }
    (evidence / "receive-fix-overlay.json").write_text(json.dumps(manifest, indent=2) + "\n")
    checked_read(original_path, DRIVER_SHA)
    for path, digest in preserved.items():
        checked_read(path, digest)


if __name__ == "__main__":
    require(len(sys.argv) == 3, "Usage: instrument.py WORK SDK")
    prepare(Path(sys.argv[1]), Path(sys.argv[2]))
