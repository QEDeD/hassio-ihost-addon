/* Local terminal diagnostic; not a vendor API or production feature. */
#ifndef POST_STARTUP_SNAPSHOT_H
#define POST_STARTUP_SNAPSHOT_H
#include <stdint.h>
typedef struct {
  volatile uint32_t phase, cpc_enter, cpc_exit, tasklets_done, drivers_done;
  volatile uint32_t full_loop_done, txc_enter, txc_exit, rx_callback_enter, rx_callback_exit;
  volatile uint32_t first_bad_seen, first_bad_header_length, first_bad_driver_length, first_bad_fcs, first_bad_crc, first_bad_control, first_bad_uart_if, rx_header_callbacks, rx_payload_callbacks, first_header_uart_if, first_payload_uart_if, resize_calls, resize_ok, resize_already, resize_fail, resize_last_requested, resize_last_received, recovery_dispatches, recovery_runs, header_expected, next_rx_size, recovery_flags, rx_link, desc0_ctrl, desc0_dst, desc0_link, desc1_ctrl, desc1_dst, desc1_link, head_index;
} post_snapshot_live_t;
extern post_snapshot_live_t post_snapshot_live;
extern volatile uint32_t post_snapshot_fault;
void post_snapshot_arm(void);
void post_snapshot_receive_state(void);
uint32_t post_snapshot_tx_ready(void);
#endif
