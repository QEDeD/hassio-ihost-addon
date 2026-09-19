/* Baseline static-table variant. Only call the host loader, never daemon main. */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include "baseline-elf-offsets.h"
static uintptr_t base;
#define AT(name) (base + OFFSET_##name)
static int metadata_main(int argc, char **argv) {
  (void)argv;
  if (argc != 1) return 2;
  void (*load)(void) = (void *)AT(initializeTokenSystem);
  load();
  uint8_t (*count)(void) = (void *)AT(sl_zigbee_get_token_count);
  uint32_t *ids = (void *)AT(tokenNvm3Keys);
  uint8_t *sizes = (void *)AT(tokenSize);
  uint8_t *counters = (void *)AT(tokenIsCnt);
  uint8_t *counts = (void *)AT(tokenArraySize);
  puts("id,counter,size,count");
  for (unsigned i=0; i<count(); i++) printf("0x%08x,%u,%u,%u\n",ids[i],counters[i],sizes[i],counts[i]);
  return 0;
}
int __libc_start_main(int (*original)(int,char**,char**), int argc, char **argv,
    void (*init)(void), void (*fini)(void), void (*rtld_fini)(void), void *stack_end) {
  base = (uintptr_t)original - OFFSET_main;
  typeof(&__libc_start_main) next = dlsym(RTLD_NEXT, "__libc_start_main");
  if (!next) _Exit(5);
  return next((void *)metadata_main, argc, argv, init, fini, rtld_fini, stack_end);
}
