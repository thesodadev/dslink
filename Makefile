RES_DIR = resource
BUILD_DIR = build
SRC_DIR = source

ARM7_STUB_SRC_FILES = $(SRC_DIR)/bootstubarm7.s $(SRC_DIR)/exodecr.c
ARM7_STUB_OBJ_FILES = $(patsubst %,$(BUILD_DIR)/%,$(addsuffix .o,$(basename $(notdir $(ARM7_STUB_SRC_FILES)))))

ARM9_STUB_SRC_FILES = $(SRC_DIR)/bootstubarm9.s
ARM9_STUB_OBJ_FILES = $(patsubst %,$(BUILD_DIR)/%,$(addsuffix .o,$(basename $(notdir $(ARM9_STUB_SRC_FILES)))))

# Toolchain
CC = arm-none-eabi-gcc
AS = arm-none-eabi-as
LD = arm-none-eabi-gcc

$(BUILD_DIR)/dslink7.elf: $(ARM7_STUB_OBJ_FILES)
	$(CC) -nostartfiles -nostdlib -specs=arm7.specs $^ -o $@

$(BUILD_DIR)/dslink9.elf: $(ARM9_STUB_OBJ_FILES)
	$(CC) -nostartfiles -nostdlib -specs=arm9.specs $^ -o $@

dslink.nds: $(BUILD_DIR)/dslink7.elf $(BUILD_DIR)/dslink9.elf
	ndstool -h 0x200 -c $@  -b resource/dslink.bmp "dslink;the wifi code loader;" \
	-7 build/bootstub/arm7/dslink.elf -9 build/bootstub/arm9/dslink/dslink9.elf

$(BUILD_DIR)/%.o: $(SRC_DIR)/%.c
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD_DIR)/%.o: $(SRC_DIR)/%.s
	$(CC) $(ASFLAGS) -c $< -o $@

.PHONY: all clean build rebuild path_builder

all: build
rebuild: clean path_builder build
build: $(BUILD_DIR)/$(BIN_NAME).exo

clean:
	rm -rf $(BUILD_DIR)

path_builder:
	mkdir -p $(BUILD_DIR)
