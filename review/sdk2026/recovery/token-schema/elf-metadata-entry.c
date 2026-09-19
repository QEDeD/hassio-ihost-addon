/* Test-only startup interception for the retained ELF; never call its daemon main. */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdint.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "elf-offsets.h"
static uintptr_t base;
#define AT(name) (base + OFFSET_##name)
static int metadata_main(int argc, char **argv) {
  uint32_t (*init)(void) = (void *)AT(halStackInitTokens);
  if (argc != 1 && !(argc == 2 && !strcmp(argv[1], "--synthetic-load"))) return 2;
  if (init() != 0) return 3;
  if (argc == 2) {
    uint8_t unused[2];
    uint32_t (*get)(uint32_t,void *,uint32_t) = (void *)AT(sl_token_manager_get_data);
    if (get(0x1ff01, unused, sizeof unused) != 0) return 4;
    uint32_t (*get_default)(uint32_t,void *) = (void *)AT(sl_zigbee_get_token_default);
    const uint32_t ids[] = {0x1e12c, 0x11000, 0x10800, 0x10880};
    const uint32_t sizes[] = {4, 4, 11, 1};
    const uint8_t counts[] = {1, 128, 64, 64};
    for (unsigned i=0; i<4; i++) {
      uint8_t expected[32], actual[32]; unsigned mismatch=0;
      if (get_default(ids[i], expected) != 0) return 6;
      for (unsigned j=0; j<counts[i]; j++) {
        if (get(ids[i]+j, actual, sizes[i]) != 0) return 7;
        if (memcmp(expected, actual, sizes[i])) mismatch++;
      }
      fprintf(stderr,"default_check id=0x%08x count=%u mismatches=%u\n",ids[i],counts[i],mismatch);
    }
  }
  uint32_t count = *(uint32_t *)AT(sli_zigbee_token_count);
  uint32_t *ids = *(uint32_t **)AT(tokenNvm3Keys);
  uint32_t *sizes = *(uint32_t **)AT(tokenSize);
  bool *counters = *(bool **)AT(tokenIsCnt);
  uint8_t *counts = *(uint8_t **)AT(tokenArraySize);
  puts("id,counter,size,count");
  for (uint32_t i=0; i<count; i++) printf("0x%08x,%u,%u,%u\n",ids[i],counters[i],sizes[i],counts[i]);
  return 0;
}
int __libc_start_main(int (*original)(int,char**,char**), int argc, char **argv,
    void (*init)(void), void (*fini)(void), void (*rtld_fini)(void), void *stack_end) {
  base = (uintptr_t)original - OFFSET_main;
  typeof(&__libc_start_main) next = dlsym(RTLD_NEXT, "__libc_start_main");
  if (!next) _Exit(5);
  return next((void *)metadata_main, argc, argv, init, fini, rtld_fini, stack_end);
}
