/* Local terminal diagnostic; not a vendor API or production feature. */
#ifndef POST_STARTUP_SNAPSHOT_H
#define POST_STARTUP_SNAPSHOT_H
#include <stdint.h>
typedef struct {
  volatile uint32_t phase, cpc_enter, cpc_exit, tasklets_done, drivers_done;
  volatile uint32_t full_loop_done, txc_enter, txc_exit, rx_callback_enter, rx_callback_exit;
} post_snapshot_live_t;
extern post_snapshot_live_t post_snapshot_live;
extern volatile uint32_t post_snapshot_fault;
void post_snapshot_arm(void);
uint32_t post_snapshot_tx_ready(void);
#endif
