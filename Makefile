#---------------------------------------------------------------------------------
.SUFFIXES:
#---------------------------------------------------------------------------------
ifeq ($(strip $(DEVKITARM)),)
$(error "Please set DEVKITARM in your environment. export DEVKITARM=<path to>devkitARM")
endif

include $(DEVKITARM)/ds_rules

dslink7sourcefiles :=	$(wildcard arm7/source/*.c) $(wildcard arm7/source/*.s) $(wildcard arm7/source/*.cpp)

dslink9sourcefiles :=	$(wildcard arm9/source/*.c) $(wildcard arm9/source/*.s) $(wildcard arm9/source/*.cpp) \
						$(wildcard arm9/data/*.*)

dslink7sfiles	:=	source/bootstubarm7.s
dslink7cfiles	:=	source/exodecr.c

dslink9files	:=	source/bootstubarm9.s

dslink7ofiles	:=	$(dslink7sfiles:.s=.o) $(dslink7cfiles:.c=.o)
dslink9ofiles	:=	$(dslink9files:.s=.o)

DEPSDIR	:=	.

export TOPDIR	:=	$(CURDIR)

UNAME := $(shell uname -s)

ifneq (,$(findstring MINGW,$(UNAME)))
	EXEEXT			:= .exe
endif

.PHONY: host/dslink$(EXEEXT)

all:	host/dslink$(EXEEXT) dslink.nds dsilink.nds

dslink.nds:	data dslink7.elf dslink9.elf
	ndstool -c $@ -7 dslink7.elf -9 dslink9.elf

dsilink.nds:	data dslink7.elf dslink9i.elf
	ndstool -c $@ -7 dslink7.elf -9 dslink9i.elf

host/dslink$(EXEEXT):
	$(MAKE) -C host

source/bootstubarm9.o: data/dslink.arm9.exo data/dslink.arm7.exo 

source/bootstubarm9i.o: source/bootstubarm9.s data/dslink.arm9i.exo data/dslink.arm7.exo 
	$(CC) -c -x assembler-with-cpp -DDSi source/bootstubarm9.s -o $@
CFLAGS	:=	-O2
				
dslink7.elf:	$(dslink7ofiles)
	$(CC) -nostartfiles -nostdlib -specs=ds_arm7.specs $^ -o $@

dslink9.elf:	$(dslink9ofiles)
	$(CC) -nostartfiles -nostdlib -specs=ds_arm9.specs $^ -o $@

dslink9i.elf:	source/bootstubarm9i.o
	$(CC) -nostartfiles -nostdlib -specs=ds_arm9.specs $^ -o $@

deps:
	mkdir deps

data:
	mkdir data

data/dslink.arm7.exo: arm7/dslink.arm7.bin
	exomizer raw -b -q $< -o $@

data/dslink.arm9.exo: arm9/dslink.arm9.bin
	exomizer raw -b -q $< -o $@

data/dslink.arm9i.exo: arm9/dslink.arm9i.bin
	exomizer raw -b -q $< -o $@

arm7/dslink.arm7.bin:	arm7/dslink.arm7.elf
	$(OBJCOPY) -O binary $< $@

arm9/dslink.arm9.bin:	arm9/dslink.arm9.elf
	$(OBJCOPY) -O binary $< $@

arm9/dslink.arm9i.bin:	arm9/dslink.arm9i.elf
	$(OBJCOPY) -O binary $< $@
	
arm7/dslink.arm7.elf:	$(dslink7sourcefiles)
	@$(MAKE) ARM7ELF=$(CURDIR)/$@ -C arm7 

arm9/dslink.arm9.elf:	$(dslink9sourcefiles) arm9/Makefile
	@$(MAKE) ARM9ELF=$(TOPDIR)/$@ -C arm9 

arm9/dslink.arm9i.elf:	$(dslink9sourcefiles) arm9/Makefile
	@$(MAKE) ARM9ELF=$(TOPDIR)/$@ -C arm9 

clean:
	@rm -fr data deps $(dslink7ofiles) source/bootstubarm9i.o $(dslink9ofiles) dslink7.elf dslink9.elf dslink.nds dslink9i.elf dsilink.nds source/*.d
	@$(MAKE) -C arm7 clean
	@$(MAKE) -C arm9 clean
	@$(MAKE) -C host clean
