/* One ordinary IPv6 CASE rejection probe; no raw socket or configuration changes.
 * stdin: generated Sigma1 (166 bytes). stdout: received packet hex and outcome.
 * Keeps the connected UDP socket for acknowledgements; never retries Sigma1.
 * cc -std=c11 -O2 -Wall -Wextra -Werror -static -o control6 control6.c
 */
#define _POSIX_C_SOURCE 200809L
#include <arpa/inet.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <unistd.h>

int main(int argc, char **argv) {
    struct sockaddr_in6 peer = {.sin6_family=AF_INET6};
    struct timeval timeout = {.tv_sec=4};
    uint8_t request[167], reply[512], ack[26];
    if (argc!=2 || inet_pton(AF_INET6,argv[1],&peer.sin6_addr)!=1 ||
        IN6_IS_ADDR_MULTICAST(&peer.sin6_addr) || IN6_IS_ADDR_UNSPECIFIED(&peer.sin6_addr) ||
        IN6_IS_ADDR_LINKLOCAL(&peer.sin6_addr) || IN6_IS_ADDR_V4MAPPED(&peer.sin6_addr)) return 2;
    peer.sin6_port=htons(5540);
    size_t n=fread(request,1,sizeof request,stdin);
    if (ferror(stdin) || n!=166 || request[0]!=4 || request[1] || request[2] || request[3] ||
        request[16]!=5 || request[17]!=0x30 || request[20] || request[21]) return 2;
    int fd=socket(AF_INET6,SOCK_DGRAM,0);
    if (fd<0) {perror("socket"); return 1;}
    if (setsockopt(fd,SOL_SOCKET,SO_RCVTIMEO,&timeout,sizeof timeout)<0 ||
        connect(fd,(struct sockaddr *)&peer,sizeof peer)<0 || send(fd,request,n,0)!=(ssize_t)n) {
        perror("initial send"); close(fd); return 1;
    }
    int accepted=0;
    for (int count=0;count<4;count++) {
        ssize_t len=recv(fd,reply,sizeof reply,0);
        if (len<0) {perror("receive"); break;}
        printf("reply_hex="); for(ssize_t i=0;i<len;i++) printf("%02x",reply[i]); puts(""); fflush(stdout);
        /* Unsecured responder: destination ID only; same identity and exchange. */
        if (len<22 || reply[0]!=1 || reply[1] || reply[2] || reply[3] ||
            memcmp(reply+8,request+8,8) || memcmp(reply+18,request+18,2) ||
            reply[20] || reply[21] || (reply[16]&~6)) break;
        size_t offset=22;
        if(reply[16]&2) {
            if(len<26 || memcmp(reply+22,request+4,4)) break;
            offset=26;
        }
        if(reply[17]==0x10) {
            if(reply[16]!=2 || (size_t)len!=offset) break;
            puts("correlated standalone ACK; awaiting rejection"); continue;
        }
        const uint8_t rejection[8]={1,0,0,0,0,0,1,0};
        if(reply[17]!=0x40 || (size_t)len!=offset+8 || memcmp(reply+offset,rejection,8)) break;
        if(reply[16]&4) {
            memcpy(ack,request,16);
            /* First request counter + 16, with modulo arithmetic. */
            uint32_t counter=(uint32_t)request[4]|((uint32_t)request[5]<<8)|
                ((uint32_t)request[6]<<16)|((uint32_t)request[7]<<24);
            counter+=16;
            for(int i=0;i<4;i++) ack[4+i]=(uint8_t)(counter>>(8*i));
            ack[16]=3; ack[17]=0x10; memcpy(ack+18,request+18,4); memcpy(ack+22,reply+4,4);
            if(send(fd,ack,sizeof ack,0)!=(ssize_t)sizeof ack) {perror("ack send"); break;}
            puts("sent standalone ACK on same socket");
        }
        accepted=1; break;
    }
    close(fd);
    puts(accepted?"PASS: correlated NoSharedTrustRoots rejection":"INCONCLUSIVE: no accepted rejection; no retry performed");
    return accepted?0:1;
}
