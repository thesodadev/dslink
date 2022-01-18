BIN_NAME = dslink

BUILD_DIR = build/arm7
SRC_DIR = source/arm7

SRC_FILES = $(wildcard $(SRC_DIR)/*.c) $(wildcard $(SRC_DIR)/*.s)
OBJ_FILES = $(patsubst %,$(BUILD_DIR)/%,$(addsuffix .o,$(basename $(notdir $(SRC_FILES)))))

LIBS = -lnds7 -ldswifi7 \
		-lm -lg -lsysbase -lc -lgcc \
	   	-nodefaultlibs

ARCHFLAGS = -mthumb-interwork
			
CFLAGS = -DNDEBUG -Wall -Os \
		 -ffunction-sections \
		 -fdata-sections \
		 -fomit-frame-pointer \
		 -ffast-math \
		 -mcpu=arm7tdmi \
		 -mtune=arm7tdmi \
		 -DARM7 \
		 $(ARCHFLAGS)

ASFLAGS = -x assembler-with-cpp \
		  $(ARCHFLAGS)

LDFLAGS	= -specs=arm7_vram.specs \
		  -g $(ARCHFLAGS) \
		  -Wl,--gc-sections \
		  -Wl,--section-start,.crt0=0x06020000,--nmagic


# Toolchain
CC = arm-none-eabi-gcc
AS = arm-none-eabi-as
LD = arm-none-eabi-gcc
OBJCOPY = arm-none-eabi-objcopy

# Build rules
$(BUILD_DIR)/$(BIN_NAME).elf: $(OBJ_FILES)
	$(LD) $(LDFLAGS) $^ $(LIBS) -o $@

$(BUILD_DIR)/$(BIN_NAME).bin: $(BUILD_DIR)/$(BIN_NAME).elf
	$(OBJCOPY) -O binary $< $@

$(BUILD_DIR)/$(BIN_NAME).exo: $(BUILD_DIR)/$(BIN_NAME).bin
	exomizer raw -b -q $< -o $@

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
