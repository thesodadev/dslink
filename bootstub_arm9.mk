BIN_NAME = bootstub

BUILD_DIR = build/bootstub/arm9
SRC_DIR = source/bootstub/arm9

SRC_FILES = $(wildcard $(SRC_DIR)/*.c) $(wildcard $(SRC_DIR)/*.s)
OBJ_FILES = $(patsubst %,$(BUILD_DIR)/%,$(addsuffix .o,$(basename $(notdir $(SRC_FILES)))))

ARCHFLAGS = -mthumb \
  			-mthumb-interwork \
			-march=armv5te \
			-mtune=arm946e-s

CFLAGS = -Wall -Os \
		 -ffunction-sections \
		 -fdata-sections \
		 -fomit-frame-pointer \
		 -ffast-math \
		 -I.\
		 $(ARCHFLAGS)

ASFLAGS = -x assembler-with-cpp \
		  -DDSLINK_ARM7_EXO=build/arm7/dslink.exo \
		  -DDSLINK_ARM9_EXO=build/arm9/dslink.exo \
		  $(ARCHFLAGS)

LDFLAGS	= -specs=arm9.specs \
		  -nostartfiles -nostdlib \
		  $(ARCHFLAGS)

# Toolchain
CC = arm-none-eabi-gcc
LD = arm-none-eabi-gcc

# Build rules
$(BUILD_DIR)/$(BIN_NAME).elf: $(OBJ_FILES)
	$(LD) $(LDFLAGS) $^ -o $@

$(BUILD_DIR)/%.o: $(SRC_DIR)/%.c
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD_DIR)/%.o: $(SRC_DIR)/%.s
	$(CC) $(ASFLAGS) -c $< -o $@

.PHONY: all clean build rebuild path_builder

all: build
rebuild: clean path_builder build
build: $(BUILD_DIR)/$(BIN_NAME).elf

clean:
	rm -rf $(BUILD_DIR)

path_builder:
	mkdir -p $(BUILD_DIR)
