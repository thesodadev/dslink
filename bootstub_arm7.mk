BIN_NAME = bootstub

BUILD_DIR = build/bootstub/arm7
SRC_DIR = source/bootstub/arm7

SRC_FILES = $(wildcard $(SRC_DIR)/*.c) $(wildcard $(SRC_DIR)/*.s)
OBJ_FILES = $(patsubst %,$(BUILD_DIR)/%,$(addsuffix .o,$(basename $(notdir $(SRC_FILES)))))

ARCHFLAGS = -mthumb \
  			-mthumb-interwork \
			-mcpu=arm7tdmi \
			-mtune=arm7tdmi

CFLAGS = -Wall -Os \
		 -ffunction-sections \
		 -fdata-sections \
		 -fomit-frame-pointer \
		 -ffast-math \
		 $(ARCHFLAGS)

ASFLAGS = -x assembler-with-cpp \
		  $(ARCHFLAGS)

LDFLAGS	= -specs=arm7.specs \
		  -nostartfiles -nostdlib \
		  -Wl,--nmagic

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
