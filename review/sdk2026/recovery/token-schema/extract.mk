include zigbeed.Makefile
.PHONY: extract-descriptors
extract-descriptors:
	$(CC) $(C_FLAGS) $(C_DEFS) $(INCLUDES) -ffunction-sections -fdata-sections -Wl,--gc-sections \
	 /token-schema/extract-descriptors.c \
	 $(SDK_PATH)/zigbee/stack/platform/sl_zigbee_token.c \
	 $(SDK_PATH)/zigbee/stack/platform/sl_zigbee_token_defines.c \
	 $(SDK_PATH)/zigbee/stack/platform/sl_zigbee_token_host.c \
	 $(SDK_PATH)/zigbee/stack/config/sl_zigbee_configuration.c \
	 $(SDK_PATH)/zigbee/stack/config/sl_zigbee_configuration_access.c \
	 $(SDK_PATH)/zigbee/stack/internal/src/baremetal/stack-info-baremetal-wrapper.c \
	 $(SDK_PATH)/zigbee/stack/internal/src/baremetal/binding-table-baremetal-wrapper.c \
	 $(SDK_PATH)/platform_core/platform/common/src/sl_core_mock.c -o /token-schema/extract-descriptors
