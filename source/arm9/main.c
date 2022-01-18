#include <nds/nds.h>
#include <dswifi/dswifi9.h>
#include <dswifi/sys/socket.h>
#include <dswifi/netinet/in.h>
#include <dswifi/netdb.h>
#include <stdio.h>
#include <errno.h>

#include "display.h"

const int __secure_area__ = 0;

//---------------------------------------------------------------------------------
void waitButtonA() {
//---------------------------------------------------------------------------------
	while(1) {
		scanKeys();
		swiWaitForVBlank();
		if (keysDown() & KEY_A) break;
	}
}

extern char _start[];

//---------------------------------------------------------------------------------
int recvall(int socket, void *buffer, int size, int flags) {
//---------------------------------------------------------------------------------
	int len, sizeleft = size;
	int row,column;
	getCursor(&row,&column);
	
	while (sizeleft) {
		len = recv(socket,buffer,sizeleft,flags);
		if (len == 0) {
			size = 0;
			break;
		};
		if (len == -1) {
			len = 0;
			kprintf("\nrecv -1, errno %d\n",errno);
			size = 0;
			break;
		}
		sizeleft -=len;
		buffer +=len;
	}
	setCursor(row,column);
	return size;
}

//---------------------------------------------------------------------------------
int progressRead(int socket, char *buffer, int size) {
//---------------------------------------------------------------------------------

	int row,column;
	getCursor(&row,&column);
	
	int sizeleft = size, len;
	int chunksize = size/100;
	int target = size - chunksize;

	if (chunksize < 1024) chunksize = 1024;
	if (chunksize > size) chunksize = size;

	int percent = 0;

	while(sizeleft) {
		len = recvall(socket,buffer,chunksize,0);
		if (len == 0) break;
		sizeleft -= len;
		buffer += len;
		if (sizeleft <= target) {
			percent = (100 * (size - sizeleft))/size;
			target -= chunksize;
			if (target<0) target = 0;
		}
		setCursor(row,column);
		kprintf("%%%d  ",percent);
		if ( sizeleft < chunksize) chunksize = sizeleft;
	}
	
	setCursor(row,column);
	if (sizeleft) {
		kprintf("\nReceive Error\n");
	} else {
		kprintf("%%100\n");
	}
	return sizeleft;
}

void arm9Reset(void *clearfrom);

char *DSiBuffer[0x1000];

//---------------------------------------------------------------------------------
int loadNDS(int socket, u32 remote) {
//---------------------------------------------------------------------------------
	int len;
	
	int i=0;
	ioctl(socket,FIONBIO,&i);

	kprintf("Reading NDS header: ");
	len = recvall(socket,__NDSHeader,512,0);
	
	if (len != 512) {
		kprintf("Error.\n");
		return 1;
	}

	kprintf("OK.\n");

	char *arm7dest = __NDSHeader->arm7destination;
	int arm7size = __NDSHeader->arm7binarySize;

	char *arm9dest = __NDSHeader->arm9destination;
	int arm9size = __NDSHeader->arm9binarySize;
	
	volatile int response = 0;
	
	if (arm9dest + arm9size > _start) response = 1;
	if (arm7dest >= (char *)0x02000000 && arm7dest < (char *)0x03000000 && arm7dest + arm7size > _start) response = 2;

	if (isDSiMode() && (__NDSHeader->unitCode & 0x02)) response |= (1<<16);

	send(socket,(int *)&response,sizeof(response),0);
	
	if(response & 0x0f) return 1;

	if(response & (1<<16)) {
		kprintf("Reading DSi header: ");
		len = recvall(socket,__DSiHeader,0x1000,0);
		if (len != 0x1000) {
			kprintf("Error.\n");
			return 1;
		}
		kprintf("OK.\n");
	}

	kprintf("Reading arm7 binary: ");
	if (progressRead(socket,(char *)memUncached((void*)0x02000000),arm7size)) {
		kprintf("\nReceive error.\n");
		return 1;
	}
	
	fifoSendValue32(FIFO_USER_01,1);

	while(!fifoCheckValue32(FIFO_USER_01)) {
		swiIntrWait(1,IRQ_FIFO_NOT_EMPTY);
	}
	fifoGetValue32(FIFO_USER_01);

	kprintf("Reading arm9 binary: ");
	if(progressRead(socket,(char *)arm9dest,arm9size)) {
		kprintf("\nReceive error.\n");
		return 1;
	}

	if(response & (1<<16)) {
		char *arm7idest = __DSiHeader->arm7idestination;
		int arm7isize = __DSiHeader->arm7ibinarySize;

		char *arm9idest = __DSiHeader->arm9idestination;
		int arm9isize = __DSiHeader->arm9ibinarySize;

		if (arm7isize) {
			kprintf("Reading arm7i binary: ");
			if (progressRead(socket,(char *)memUncached((void*)arm7idest),arm7isize)) {
				kprintf("\nReceive error.\n");
				return 1;
			}
		}

		if (arm9isize) {
			kprintf("Reading arm9i binary: ");
			if (progressRead(socket,(char *)arm9idest,arm9isize)) {
				kprintf("\nReceive error.\n");
				return 1;
			}
		}
	}

	volatile int cmdlen=0;
	char *cmdline;
	if (arm9size != 0){
		cmdline = (char*)(arm9dest+arm9size);
	} else {
		cmdline = (char*)(arm7dest+arm7size);
	}
	len = recvall(socket,(char*)&cmdlen,4,0);

	if (cmdlen) {
		len = recvall(socket,cmdline,cmdlen,0);

		__system_argv->argvMagic = ARGV_MAGIC;
		__system_argv->commandLine = cmdline;
		__system_argv->length = cmdlen;
		__system_argv->host = remote;
	}

	Wifi_DisableWifi();

	DC_FlushAll();
	REG_IPC_SYNC = 0;

	fifoSendValue32(FIFO_USER_01,2);

	irqDisable(IRQ_ALL);
	REG_IME = 0;

	//clear out ARM9 DMA channels
	for (i=0; i<4; i++) {
		DMA_CR(i) = 0;
		DMA_SRC(i) = 0;
		DMA_DEST(i) = 0;
		TIMER_CR(i) = 0;
		TIMER_DATA(i) = 0;
	}

	u16 *mainregs = (u16*)0x04000000;
	u16 *subregs = (u16*)0x04001000;

	for (i=0; i<43; i++) {
		mainregs[i] = 0;
		subregs[i] = 0;
	}

	REG_DISPSTAT = 0;

	dmaFillWords(0, BG_PALETTE, (2*1024));
	VRAM_A_CR = 0x80;
	dmaFillWords(0, VRAM, 128*1024);
	VRAM_A_CR = 0;
	VRAM_B_CR = 0;
// Don't mess with the ARM7's VRAM
//	VRAM_C_CR = 0;
//	VRAM_D_CR = 0;
	VRAM_E_CR = 0;
	VRAM_F_CR = 0;
	VRAM_G_CR = 0;
	VRAM_H_CR = 0;
	VRAM_I_CR = 0;
	REG_POWERCNT  = 0x820F;
	REG_EXMEMCNT = 0xE880;

	//set shared ram to ARM7
	WRAM_CR = 0x03;

	while((REG_IPC_SYNC &0xf)!=7);
	REG_IPC_SYNC = 0x700;
	while((REG_IPC_SYNC &0xf)!=0);
	REG_IPC_SYNC = 0;

	arm9Reset(cmdline+cmdlen);
	while(1);
}

//---------------------------------------------------------------------------------
int main(void) {
//---------------------------------------------------------------------------------

	initDisplay();

	kprintf("dslink ... connecting ...\n");

	if(!Wifi_InitDefault(WFC_CONNECT)) {
		kprintf(" Failed to connect!\n");
		waitButtonA();
		return 0;
	}

	struct in_addr ip, gateway, mask, dns1, dns2;

	ip = Wifi_GetIPInfo(&gateway, &mask, &dns1, &dns2);
	kprintf("Connected: %s\n",inet_ntoa(ip));
	
	int sock_udp = socket(PF_INET, SOCK_DGRAM, 0);
	struct sockaddr_in sa_udp, sa_udp_remote;

	sa_udp.sin_family = AF_INET;
	sa_udp.sin_addr.s_addr = INADDR_ANY;
	sa_udp.sin_port = htons(17491);

	if(bind(sock_udp, (struct sockaddr*) &sa_udp, sizeof(sa_udp)) < 0) {
		kprintf(" UDP socket error\n");
		waitButtonA();
		return 0;
	}

	struct sockaddr_in sa_tcp;
	sa_tcp.sin_addr.s_addr=INADDR_ANY;
	sa_tcp.sin_family=AF_INET;
	sa_tcp.sin_port=htons(17491);
	int sock_tcp=socket(AF_INET,SOCK_STREAM,0);
	bind(sock_tcp,(struct sockaddr *)&sa_tcp,sizeof(sa_tcp));
	int i=1;
	ioctl(sock_tcp,FIONBIO,&i);
	ioctl(sock_udp,FIONBIO,&i);
	listen(sock_tcp,2);

	int dummy, sock_tcp_remote;
	char recvbuf[256];

	while(1) {
		int len = recvfrom(sock_udp, recvbuf, sizeof(recvbuf), 0, (struct sockaddr*) &sa_udp_remote, &dummy);

		if (len!=-1) {
			if (strncmp(recvbuf,"dsboot",strlen("dsboot")) == 0) {
				sa_udp_remote.sin_family=AF_INET;
				sa_udp_remote.sin_port=htons(17491);
				sendto(sock_udp, "bootds", strlen("bootds"), 0, (struct sockaddr*) &sa_udp_remote,sizeof(sa_udp_remote));
			}
		}

		sock_tcp_remote = accept(sock_tcp,(struct sockaddr *)&sa_tcp,&dummy);
		if (sock_tcp_remote != -1) {
			loadNDS(sock_tcp_remote,sa_tcp.sin_addr.s_addr);
			closesocket(sock_tcp_remote);
		}
		swiWaitForVBlank();
		scanKeys();
		if (keysDown() & KEY_START) break;
	}
	return 0;
}
