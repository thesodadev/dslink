# TODO: build all depends from another makefiles

dslink.nds: $(BUILD_DIR)/dslink7.elf $(BUILD_DIR)/dslink9.elf
	ndstool -h 0x200 -c $@  -b resource/dslink.bmp "dslink;the wifi code loader;" \
	-7 build/bootstub/arm7/dslink.elf -9 build/bootstub/arm9/dslink/dslink9.elf
