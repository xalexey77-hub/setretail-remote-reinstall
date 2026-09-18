#define _GNU_SOURCE
#include <arpa/inet.h>
#include <errno.h>
#include <fcntl.h>
#include <linux/nbd.h>
#include <netinet/in.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/socket.h>
#include <unistd.h>
static int read_full(int fd,void *buf,size_t n){unsigned char*p=buf;size_t o=0;while(o<n){ssize_t r=read(fd,p+o,n-o);if(r==0)return-1;if(r<0){if(errno==EINTR)continue;return-1;}o+=(size_t)r;}return 0;}
static uint64_t be64(const unsigned char*p){uint64_t v=0;for(int i=0;i<8;i++)v=(v<<8)|p[i];return v;}
static uint32_t be32(const unsigned char*p){return((uint32_t)p[0]<<24)|((uint32_t)p[1]<<16)|((uint32_t)p[2]<<8)|p[3];}
static int connect_tcp(const char*h,const char*p){char*e=NULL;long pv=strtol(p,&e,10);if(!e||*e||pv<1||pv>65535)return-1;struct sockaddr_in a={0};a.sin_family=AF_INET;a.sin_port=htons((uint16_t)pv);if(inet_pton(AF_INET,h,&a.sin_addr)!=1)return-1;int s=socket(AF_INET,SOCK_STREAM,0);if(s<0)return-1;if(connect(s,(struct sockaddr*)&a,sizeof(a))<0){close(s);return-1;}return s;}
int main(int argc,char**argv){if(argc<4){fprintf(stderr,"Usage: %s SERVER PORT DEVICE\n",argv[0]);return 2;}int s=connect_tcp(argv[1],argv[2]);if(s<0){perror("connect");return 3;}unsigned char h[152];if(read_full(s,h,sizeof(h))<0)return 4;if(memcmp(h,"NBDMAGIC",8)||be64(h+8)!=0x0000420281861253ULL)return 5;uint64_t size=be64(h+16);uint32_t flags=be32(h+24);int n=open(argv[3],O_RDWR);if(n<0){perror(argv[3]);return 6;}ioctl(n,NBD_CLEAR_SOCK);if(ioctl(n,NBD_SET_BLKSIZE,2048)<0)return 7;if(ioctl(n,NBD_SET_SIZE_BLOCKS,(unsigned long)(size/2048ULL))<0)return 8;
#ifdef NBD_SET_FLAGS
unsigned long kflags=0;
#ifdef NBD_FLAG_READ_ONLY
if(flags&1U)kflags|=NBD_FLAG_READ_ONLY;
#endif
if(kflags)ioctl(n,NBD_SET_FLAGS,kflags);
#endif
if(ioctl(n,NBD_SET_SOCK,s)<0)return 9;fprintf(stderr,"Connected %s:%s -> %s, size=%llu, block=2048, flags=0x%x\n",argv[1],argv[2],argv[3],(unsigned long long)size,flags);int rc=ioctl(n,NBD_DO_IT);if(rc<0&&errno!=EPIPE&&errno!=EINVAL)perror("NBD_DO_IT");ioctl(n,NBD_CLEAR_QUE);ioctl(n,NBD_CLEAR_SOCK);close(n);close(s);return 0;}
