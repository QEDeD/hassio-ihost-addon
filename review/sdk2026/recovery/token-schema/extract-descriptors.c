#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "sl_zigbee_token.h"
#include "stack-info.h"
#include "stack/include/binding-table.h"
extern sl_status_t halStackInitTokens(void);
extern uint32_t *tokenNvm3Keys, *tokenSize, sli_zigbee_token_count;
extern bool *tokenIsCnt;
extern uint8_t *tokenArraySize;
extern uint8_t sli_zigbee_binding_table_size, sl_zigbee_key_table_size;
int main(int argc, char **argv) {
  bool synthetic_load = argc == 2 && !strcmp(argv[1], "--synthetic-load");
  if (argc != 1 && argc != 3 && !synthetic_load) return 2;
  if (argc == 3) {
    char *end;
    long binding = strtol(argv[1], &end, 10);
    if (*end || binding < 0 || binding > 255) return 2;
    long keys = strtol(argv[2], &end, 10);
    if (*end || keys < 0 || keys > 255) return 2;
    sli_zigbee_binding_table_size = binding;
    sl_zigbee_key_table_size = keys;
  }
  fprintf(stderr, "runtime-counts binding=%u child=%u keys=%u certificates=%u zc-zr=%u\n",
          sl_zigbee_get_binding_table_size(), sl_zigbee_get_child_table_size(),
          sl_zigbee_get_key_table_size(), sl_zigbee_get_certificate_table_size(),
          sl_zigbee_get_zc_and_zr_count());
  if (halStackInitTokens() != SL_STATUS_OK) return 1;
  if (synthetic_load) {
    uint8_t unused[2];
    if (slx_zigbee_token_manager_get_data(0x1ff01, unused, sizeof unused) != SL_STATUS_OK) return 4;
    const uint32_t ids[] = {0x1e12c, 0x11000, 0x10800, 0x10880};
    const uint32_t sizes[] = {4, 4, 11, 1};
    const uint8_t counts[] = {1, 128, 64, 64};
    unsigned failures = 0;
    for (unsigned i=0; i<4; i++) {
      uint8_t expected[32], actual[32]; unsigned mismatch=0;
      if (sl_zigbee_get_token_default(ids[i], expected) != SL_STATUS_OK) return 6;
      for (unsigned j=0; j<counts[i]; j++) {
        if (slx_zigbee_token_manager_get_data(ids[i]+j, actual, sizes[i]) != SL_STATUS_OK) return 7;
        if (memcmp(expected, actual, sizes[i])) mismatch++;
      }
      fprintf(stderr,"default_check id=0x%08x count=%u mismatches=%u\n",ids[i],counts[i],mismatch);
      failures += mismatch;
    }
    if (failures) return 8;
  }
  puts("id,counter,size,count");
  for (uint32_t i = 0; i < sli_zigbee_token_count; i++)
    printf("0x%08x,%u,%u,%u\n", tokenNvm3Keys[i], tokenIsCnt[i], tokenSize[i], tokenArraySize[i]);
  return 0;
}
/* Preserve assertion failure without stack reset/radio-side diagnostic hooks. */
void halInternalAssertFailed(const char *filename, int line) {
  (void)filename; (void)line;
  fputs("vendor assertion failed\n", stderr);
  abort();
}
