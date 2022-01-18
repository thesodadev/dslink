BIN_NAME = dslink

BUILD_DIR = build/arm9
RES_DIR = resource
SRC_DIR = source/arm9

SRC_FILES = $(wildcard $(SRC_DIR)/*.c) $(wildcard $(SRC_DIR)/*.s)
OBJ_FILES = $(patsubst %,$(BUILD_DIR)/%,$(addsuffix .o,$(basename $(notdir $(SRC_FILES)))))

LIBS = -lnds9 -ldswifi9 \
		-lm -lg -lsysbase -lc -lgcc \
	   	-nodefaultlibs

INCLUDE_FLAGS = -I$(BUILD_DIR)

ARCHFLAGS = -mthumb \
  			-mthumb-interwork \
			-march=armv5te \
			-mtune=arm946e-s

CFLAGS = -g -flto -DNDEBUG -Wall -Os \
		 -ffunction-sections \
		 -fdata-sections \
		 -fomit-frame-pointer \
		 -ffast-math \
		 $(ARCHFLAGS) \
		 $(INCLUDE_FLAGS) \
		 -DARM9

ASFLAGS = -x assembler-with-cpp \
		  $(ARCHFLAGS)

LDFLAGS	= -specs=dsi_arm9.specs \
		-g -flto $(ARCHFLAGS) \
		-Wl,--gc-sections \
		-Wl,--section-start,.crt0=0x02e40000

# Toolchain
CC = arm-none-eabi-gcc
AS = arm-none-eabi-as
LD = arm-none-eabi-gcc
OBJCOPY = arm-none-eabi-objcopy

# Build rules
$(BUILD_DIR)/$(BIN_NAME).elf: $(BUILD_DIR)/font.o $(OBJ_FILES)
	$(LD) $(LDFLAGS) $^ $(LIBS) -o $@

$(BUILD_DIR)/$(BIN_NAME).bin: $(BUILD_DIR)/$(BIN_NAME).elf
	$(OBJCOPY) -O binary $< $@

$(BUILD_DIR)/$(BIN_NAME).exo: $(BUILD_DIR)/$(BIN_NAME).bin
	exomizer raw -b -q $< -o $@

$(BUILD_DIR)/%.o: $(SRC_DIR)/%.c
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD_DIR)/%.o: $(SRC_DIR)/%.s
	$(CC) $(ASFLAGS) -c $< -o $@

$(BUILD_DIR)/%.o: $(RES_DIR)/%.bin
	bin2s -a 4 -H $(BUILD_DIR)/$(basename $(<F)).h $< | \
	$(AS) -o $(BUILD_DIR)/$(@F)

.PHONY: all clean build rebuild path_builder

all: build
rebuild: clean path_builder build
build: $(BUILD_DIR)/$(BIN_NAME).exo

clean:
	rm -rf $(BUILD_DIR)

path_builder:
	mkdir -p $(BUILD_DIR)
