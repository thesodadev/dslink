# TODO: build all depends from another makefiles
.PHONY: arm7 arm9 bootstub_arm7 bootstub_arm9 dslink.nds build

build: arm7 arm9 bootstub_arm7 bootstub_arm9 dslink.nds

arm7: arm7.mk
	$(MAKE) -f arm7.mk rebuild

arm9: arm9.mk
	$(MAKE) -f arm9.mk rebuild
	
bootstub_arm7: bootstub_arm7.mk
	$(MAKE) -f bootstub_arm7.mk rebuild
	
bootstub_arm9: bootstub_arm9.mk
	$(MAKE) -f bootstub_arm9.mk rebuild

dslink.nds: build/bootstub/arm7/bootstub.elf build/bootstub/arm9/bootstub.elf
	ndstool -h 0x200 -c build/$@  -b resource/dslink.bmp "dslink;the wifi code loader;" \
	-7 build/bootstub/arm7/bootstub.elf -9 build/bootstub/arm9/bootstub.elf
	
install: build/dslink.nds
	install -d $(DESTDIR)/opt/nds
	install -m 644 $@ $(DESTDIR)/opt/nds
