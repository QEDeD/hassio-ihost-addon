"""Prepare a checksum-pinned local diagnostic overlay; never writes the SDK."""
from pathlib import Path
import hashlib
import json
import re
import sys

DRIVER_SHA = "2fe944161fbec7240c5ac83ebf76a445d7f9a7a6282ef3b135e77a567634f6d5"
CORE_SHA = "38769f54e490b2a747971223083237c65fe4653dcfb1bc35abf4500b78480a17"
HANDLER_SHA = "d23f9f02a39fa55bba2e90e99c5d69803bc2460698e8ffcbcdf77898bd9aa884"
APP_SHA = "311be88effa602bbd40264ec51abfd90f3ee39d4591e3918ff98639f75ff74e8"
CONFIG_SHA = "be1581f8a6a17d509fa5bf224423fdc820e2e914d803659a99928fda54e8ef2e"


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def checked_read(path, expected):
    data = path.read_bytes()
    require(hashlib.sha256(data).hexdigest() == expected, f"Unreviewed input: {path}")
    return data.decode("utf-8")


def replace_once(text, old, new):
    require(text.count(old) == 1, f"Expected exactly one hook: {old!r}")
    return text.replace(old, new)


def function_span(text, signature):
    start = text.index(signature + "\n{")
    end = text.index("\n}\n", start) + 3
    return start, end, text[start:end]


def base_overlay_driver(original):
    require(hashlib.sha256(original.encode()).hexdigest() == DRIVER_SHA, "Driver checksum mismatch")
    txsig = "void CPC_UART_ISR_TX_HANDLER(SL_CPC_DRV_UART_PERIPHERAL_NO)(void)"
    a, b, tx = function_span(original, txsig)
    tx_entry = "    post_snapshot_live.txc_enter++;\n"
    tx_exit = "    post_snapshot_live.txc_exit++;\n"
    tx_new = replace_once(tx, "  if (flag & CPC_UART_IF_TXC) {\n", "  if (flag & CPC_UART_IF_TXC) {\n" + tx_entry)
    tx_new = replace_once(tx_new, "      sli_cpc_drv_wake_host_gpio(false);\n    }\n  }\n}",
                         "      sli_cpc_drv_wake_host_gpio(false);\n    }\n" + tx_exit + "  }\n}")
    require(tx_new.replace(tx_entry, "").replace(tx_exit, "") == tx, "TX hook changed original semantics")
    modified = original[:a] + tx_new + original[b:]
    a, b, rx = function_span(modified, "static void rx_dma_complete_no_hwfc(void)")
    rx_entry = "  post_snapshot_live.rx_callback_enter++;\n"
    rx_exit = "{ post_snapshot_live.rx_callback_exit++; return; }"
    require(rx.count("return;") == 6, "Unexpected RX return-path count")
    rx_new = rx.replace("{\n", "{\n" + rx_entry, 1)
    rx_new = rx_new.replace("return;", rx_exit)
    require(rx_new.count(rx_exit) == 6, "RX exit hook incomplete")
    require(rx_new.replace(rx_entry, "").replace(rx_exit, "return;") == rx, "RX hook changed original semantics")
    modified = modified[:a] + rx_new + modified[b:]
    modified = '#include "snapshot.h"\n' + modified
    modified += '\n/* Primitive read-only view for the terminal diagnostic. */\nuint32_t post_snapshot_tx_ready(void) { return tx_ready ? 1u : 0u; }\n'
    return modified



def add_after(text, anchor, addition):
    """Insert only; verify that deleting the addition reconstructs the input."""
    modified = replace_once(text, anchor, anchor + addition)
    require(modified.replace(anchor + addition, anchor, 1) == text, "Insertion changed original source")
    return modified


def overlay_driver(original):
    modified = base_overlay_driver(original)
    a, b, fn = function_span(modified, "static void rx_dma_complete_no_hwfc(void)")
    addition = """  if (header_expected_next) {
    if (post_snapshot_live.rx_header_callbacks == 0u) {
      post_snapshot_live.first_header_uart_if = USART0->IF;
    }
    post_snapshot_live.rx_header_callbacks++;
  } else {
    if (post_snapshot_live.rx_payload_callbacks == 0u) {
      post_snapshot_live.first_payload_uart_if = USART0->IF;
    }
    post_snapshot_live.rx_payload_callbacks++;
  }
"""
    fn = add_after(fn, "  post_snapshot_live.rx_callback_enter++;\n", addition)
    modified = modified[:a] + fn + modified[b:]
    a, b, fn = function_span(modified, "static sl_status_t resize_current_dma_descriptor(uint16_t new_length)")
    fn = add_after(fn, "static sl_status_t resize_current_dma_descriptor(uint16_t new_length)\n{\n", "  post_snapshot_live.resize_calls++;\n  post_snapshot_live.resize_last_requested = new_length;\n  post_snapshot_live.resize_last_received = 0xFFFFFFFFu;\n")
    fn = add_after(fn, "  if (already_recvd_cnt >= new_length) {\n", "    post_snapshot_live.resize_last_received = already_recvd_cnt;\n")
    fn = add_after(fn, "  remaining = new_length - already_recvd_cnt;\n", "  post_snapshot_live.resize_last_received = already_recvd_cnt;\n")
    for value, field in [("SL_STATUS_FAIL", "resize_fail"), ("SL_STATUS_ALREADY_EXISTS", "resize_already"), ("SL_STATUS_OK", "resize_ok")]:
        before = fn
        original_return = "return " + value + ";"
        replacement = "{ post_snapshot_live." + field + "++; " + original_return + " }"
        fn = replace_once(fn, original_return, replacement)
        require(fn.replace(replacement, original_return, 1) == before, "Resize return control flow changed")
    modified = modified[:a] + fn + modified[b:]
    modified = add_after(modified, "static void dispatch_recovery(void)\n{\n", "  post_snapshot_live.recovery_dispatches++;\n")
    modified = add_after(modified, "static void recovery(void *data)\n{\n", "  post_snapshot_live.recovery_runs++;\n")
    modified += """
/* Called once with PRIMASK set, after capture begins. Fixed objects only. */
void post_snapshot_receive_state(void)
{
  post_snapshot_live.header_expected = header_expected_next ? 1u : 0u;
  post_snapshot_live.next_rx_size = next_rx_size;
  post_snapshot_live.recovery_flags = (recovery_context.out_of_sync ? 1u : 0u)
    | (recovery_context.misaligned_payload ? 2u : 0u)
    | (recovery_context.recovery_completed ? 4u : 0u)
    | (recovery_dispatcher_handle.submitted ? 8u : 0u);
  post_snapshot_live.rx_link = read_channel < DMA_CHAN_COUNT
    ? LDMA_PERIPH->CH[read_channel].LINK : 0xFFFFFFFFu;
  /* Descriptor words CTRL, DST and LINK are fixed offsets 0, 2 and 3.
   * uint32_t aliasing of the vendor union is avoided with fixed-size memcpy. */
  _Static_assert(sizeof(sl_hal_ldma_descriptor_t) == 16u, "Reviewed LDMA descriptor size changed");
  uint32_t words[4];
  memcpy(words, &rx_descriptor[0], sizeof(words));
  post_snapshot_live.desc0_ctrl = words[0];
  post_snapshot_live.desc0_dst = words[2];
  post_snapshot_live.desc0_link = words[3];
  memcpy(words, &rx_descriptor[1], sizeof(words));
  post_snapshot_live.desc1_ctrl = words[0];
  post_snapshot_live.desc1_dst = words[2];
  post_snapshot_live.desc1_link = words[3];
  post_snapshot_live.head_index = rx_descriptor_head == &rx_descriptor[0] ? 0u
    : rx_descriptor_head == &rx_descriptor[1] ? 1u : 0xFFFFFFFFu;
}
"""
    return modified


def overlay_core(original):
    require(hashlib.sha256(original.encode()).hexdigest() == CORE_SHA, "Core checksum mismatch")
    addition = """      if (post_snapshot_live.first_bad_seen == 0u) {
        post_snapshot_live.first_bad_uart_if = USART0->IF;
        post_snapshot_live.first_bad_header_length = data_length + SLI_CPC_HDLC_FCS_SIZE;
        post_snapshot_live.first_bad_driver_length = rx_handle->data_length;
        post_snapshot_live.first_bad_fcs = fcs;
        post_snapshot_live.first_bad_crc = sli_cpc_get_crc_sw(rx_handle->data, data_length);
        post_snapshot_live.first_bad_control = control;
        /* Commit last; priority0 snapshot may interrupt this sequence. */
        post_snapshot_live.first_bad_seen = 1u;
      }
"""
    modified = add_after(original, "    if (!crc_valid) {\n", addition)
    return '#include "snapshot.h"\n#include "em_device.h"\n' + modified


def prepare(root, sdk, recipe):
    root = root.resolve()
    sdk = sdk.resolve()
    require(root != sdk and sdk not in root.parents, "Working tree must not be inside SDK")
    source = root / "source"
    evidence = root / "evidence"
    handler_path = root / "generated/autogen/sl_event_handler.c"
    app_path = source / "app.c"
    config_path = root / "generated/config/sl_cpc_config.h"
    cmake_path = root / "generated/cmake_gcc/rcp-uart-802154.cmake"
    handler = checked_read(handler_path, HANDLER_SHA)
    app = checked_read(app_path, APP_SHA)
    config = checked_read(config_path, CONFIG_SHA)
    driver_original = checked_read(sdk / "cpc/src/sl_cpc_drv_uart.c", DRIVER_SHA)
    driver = overlay_driver(driver_original)
    core_original = checked_read(sdk / "cpc/src/sl_cpc.c", CORE_SHA)
    core = overlay_core(core_original)
    fields = json.loads((recipe / "fields.json").read_text())
    require(isinstance(fields, list) and fields and len(fields) <= 111, "Invalid field table")
    require(all(isinstance(f, str) and re.fullmatch(r"[a-z][a-z0-9_]*", f) for f in fields), "Invalid field name")
    require(len(set(fields)) == len(fields), "Duplicate field name")
    require(fields[:2] == ["format_version", "build_id"], "Unexpected schema prefix")
    header = "/* Generated from fields.json; order is the wire contract. */\n#ifndef POST_SNAPSHOT_FIELDS_H\n#define POST_SNAPSHOT_FIELDS_H\nenum {\n"
    header += "".join(f"  POST_F_{f} = {i},\n" for i, f in enumerate(fields))
    header += f"  POST_WORD_COUNT = {len(fields)}\n}};\n#endif\n"
    handler = '#include "snapshot.h"\n' + replace_once(handler, "  sl_cpc_process_action();", "  post_snapshot_live.phase = 1u;\n  post_snapshot_live.cpc_enter++;\n  sl_cpc_process_action();\n  post_snapshot_live.cpc_exit++;\n  post_snapshot_live.phase = 2u;")
    app = '#include "snapshot.h"\n' + replace_once(app, "    sl_host_wakeup_init();", "    sl_host_wakeup_init();\n    post_snapshot_arm();")
    app = replace_once(app, "    otTaskletsProcess(sInstance);", "    post_snapshot_live.phase = 3u;\n    otTaskletsProcess(sInstance);\n    post_snapshot_live.tasklets_done++;\n    post_snapshot_live.phase = 4u;")
    app = replace_once(app, "    otSysProcessDrivers(sInstance);", "    post_snapshot_live.phase = 5u;\n    otSysProcessDrivers(sInstance);\n    post_snapshot_live.drivers_done++;\n    post_snapshot_live.full_loop_done++;\n    post_snapshot_live.phase = 6u;")
    config = replace_once(config, "#define SL_CPC_DEBUG_CORE_EVENT_COUNTERS     0", "#define SL_CPC_DEBUG_CORE_EVENT_COUNTERS     1")
    cmake = cmake_path.read_text()
    require('add_library(slc' in cmake, "Generated CMake target changed")
    overlay_path = source / "sl_cpc_drv_uart_snapshot.c"
    core_overlay_path = source / "sl_cpc_receive_snapshot.c"
    cmake = replace_once(cmake, '"${SDK_PATH}/cpc/src/sl_cpc_drv_uart.c"', '"' + str(overlay_path) + '"')
    cmake = replace_once(cmake, '"${SDK_PATH}/cpc/src/sl_cpc.c"', '"' + str(core_overlay_path) + '"')
    cmake += '\n# Local terminal diagnostic overlay; preserve existing target compile/link options.\n'
    cmake += 'target_sources(slc PRIVATE "' + str(source / "snapshot.c") + '")\n'
    cmake += 'target_include_directories(slc PRIVATE "' + str(source) + '")\n'
    # All validation above precedes mutation. Only generated working-tree inputs change.
    handler_path.write_text(handler)
    app_path.write_text(app)
    config_path.write_text(config)
    overlay_path.write_text(driver)
    core_overlay_path.write_text(core)
    (source / "snapshot_fields.h").write_text(header)
    for name in ["snapshot.c", "snapshot.h"]:
        (source / name).write_bytes((recipe / name).read_bytes())
    cmake_path.write_text(cmake)
    evidence.mkdir(exist_ok=True)
    (evidence / "fields.json").write_bytes((recipe / "fields.json").read_bytes())
    changed = [handler_path, app_path, config_path, overlay_path, core_overlay_path, source / "snapshot_fields.h", source / "snapshot.c", source / "snapshot.h", cmake_path]
    manifest = {
        "purpose": "offline terminal snapshot; no SDK mutation",
        "build_id": "52585331", "field_count": len(fields),
        "driver_input_sha256": DRIVER_SHA, "core_input_sha256": CORE_SHA, "rx_return_hooks": 6,
        "files": {str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest() for p in changed},
    }
    (evidence / "snapshot-overlay.json").write_text(json.dumps(manifest, indent=2) + "\n")
    require(hashlib.sha256((sdk / "cpc/src/sl_cpc_drv_uart.c").read_bytes()).hexdigest() == DRIVER_SHA, "SDK unexpectedly changed")
    require(hashlib.sha256((sdk / "cpc/src/sl_cpc.c").read_bytes()).hexdigest() == CORE_SHA, "SDK core unexpectedly changed")


if __name__ == "__main__":
    require(len(sys.argv) == 3, "Usage: instrument.py WORK SDK")
    prepare(Path(sys.argv[1]), Path(sys.argv[2]), Path(__file__).resolve().parent)
