// Executes the real patched SDK resolver. Syscall fixtures observe routing
// choices and inject failures without access to production or a real network.
#include "resolver.hpp"
#include <openthread/message.h>
#include <openthread/udp.h>
#include <openthread/nat64.h>
#include <openthread/platform/time.h>
#include <cassert>
#include <cstring>
#include <map>
#include <vector>
#include <string>
#include <iostream>

using ot::Posix::Resolver;
struct Socket { int family; std::string interface; };
struct Send { int fd; int family; std::string interface; uint32_t scope; };
static std::map<int, Socket> sockets;
static std::vector<Send> sent;
static int nextFd = 100, socketCalls = 0, failSocketCall = 0;
static bool failBinding = false;
static const char *infra = "fixture-infra";
static int completed = 0;
otInstance *gInstance = nullptr;
extern "C" {
ssize_t __wrap_read(int fd, void *buffer, size_t size) { assert(sockets.count(fd)); assert(size>=12); memset(buffer,0,12); return 12; }
otMessage *otUdpNewMessage(otInstance *, const otMessageSettings *) { return reinterpret_cast<otMessage *>(2); }
otError otMessageAppend(otMessage *, const void *, uint16_t length) { assert(length==12); return OT_ERROR_NONE; }
void otMessageFree(otMessage *) {}
const char *otExitCodeToString(uint8_t) { return "fixture"; }
const char *otThreadErrorToString(otError) { return "fixture"; }
void otLogCritPlat(const char *, ...) {}
void otLogPlatArgs(otLogLevel, const char *, const char *, va_list) {}
int __wrap_socket(int family, int, int) {
    if (++socketCalls == failSocketCall) { errno = ENOMEM; return -1; }
    int fd = nextFd++; sockets[fd] = {family, ""}; return fd;
}
int __wrap_setsockopt(int fd, int level, int option, const void *value, socklen_t size) {
    assert(level == SOL_SOCKET && option == SO_BINDTODEVICE);
    if (failBinding) { errno = EPERM; return -1; }
    sockets.at(fd).interface.assign(static_cast<const char *>(value), size); return 0;
}
int __wrap_close(int fd) { assert(sockets.erase(fd) == 1); return 0; }
ssize_t __wrap_sendto(int fd, const void *, size_t size, int, const sockaddr *address, socklen_t) {
    auto &socket = sockets.at(fd);
    uint32_t scope = address->sa_family == AF_INET6 ? reinterpret_cast<const sockaddr_in6 *>(address)->sin6_scope_id : 0;
    sent.push_back({fd, address->sa_family, socket.interface, scope}); return size;
}
const char *otSysGetInfraNetifName(void) { return infra; }
unsigned int otSysGetInfraNetifIndex(void) { return 9; }
uint64_t otPlatTimeGet(void) { return 0; }
uint16_t otMessageGetLength(const otMessage *) { return 12; }
uint16_t otMessageRead(const otMessage *, uint16_t, void *buffer, uint16_t) { memset(buffer, 0, 12); return 12; }
void otPlatDnsUpstreamQueryDone(otInstance *, otPlatDnsUpstreamQuery *, otMessage *) { ++completed; }
otError otIp4FromIp4MappedIp6Address(const otIp6Address *input, otIp4Address *output) {
    const auto *bytes = reinterpret_cast<const unsigned char *>(input);
    const unsigned char prefix[12] = {0,0,0,0,0,0,0,0,0,0,0xff,0xff};
    if (memcmp(bytes, prefix, 12)) return OT_ERROR_INVALID_ARGS;
    memcpy(output, bytes+12, 4); return OT_ERROR_NONE;
}
void otIp4ToIp4MappedIp6Address(const otIp4Address *input, otIp6Address *output) {
    auto *bytes = reinterpret_cast<unsigned char *>(output); memset(bytes,0,16);
    bytes[10]=bytes[11]=0xff; memcpy(bytes+12,input,4);
}
}
static otIp6Address address(const char *text) { otIp6Address result; assert(inet_pton(AF_INET6,text,&result)==1); return result; }
static void reset() { assert(sockets.empty()); sent.clear(); socketCalls=0; failSocketCall=0; failBinding=false; infra="fixture-infra"; }
static void run(Resolver &resolver, bool recursive, bool host4=true, bool host6=true) {
    resolver.SetResolvConfEnabled(false); resolver.Init();
    otIp6Address hosts[] = {address("::ffff:127.0.0.53"),address("2001:db8:2::53")};
    if (!host4) hosts[0]=hosts[1];
    resolver.SetUpstreamDnsServers(hosts, unsigned(host4)+unsigned(host6));
    auto rdnss=address("fe80::53"); resolver.SetRecursiveDnsServerList(&rdnss, recursive?1:0);
    resolver.Query(reinterpret_cast<otPlatDnsUpstreamQuery *>(1),reinterpret_cast<const otMessage *>(1));
}
static void cancel(Resolver &resolver) { resolver.Cancel(reinterpret_cast<otPlatDnsUpstreamQuery *>(1)); assert(sockets.empty()); }
int main() {
    reset(); { Resolver r{}; run(r,true); assert(sent.size()==3); assert(sent[0].interface=="fixture-infra" && sent[0].scope==9); assert(sent[1].interface.empty() && sent[1].family==AF_INET); assert(sent[2].interface.empty() && sent[2].family==AF_INET6); assert(sent[0].fd!=sent[2].fd); cancel(r); }
    std::cout<<"PASS host IPv4/IPv6 unbound, RDNSS bound and link-local scoped; cleanup\n";
    reset(); { Resolver r{}; run(r,true); ot::Posix::Mainloop::Context context{}; r.UpdateFdSet(context); int replyFd=sent[0].fd; assert(FD_ISSET(replyFd,&context.mReadFdSet)); assert(FD_ISSET(replyFd,&context.mErrorFdSet)); FD_ZERO(&context.mReadFdSet); FD_ZERO(&context.mErrorFdSet); FD_SET(replyFd,&context.mReadFdSet); int before=completed; r.Process(context); assert(completed==before+1); assert(sockets.empty()); }
    std::cout<<"PASS RDNSS socket polled, reply delivered and all transaction sockets closed\n";
    reset(); failBinding=true; { Resolver r{}; run(r,true); assert(sent.size()==3); for(auto &s:sent) assert(s.interface.empty()); assert(sent[0].fd==sent[2].fd); assert(sockets.size()==2); cancel(r); }
    std::cout<<"PASS RDNSS bind failure falls back, failed socket closed\n";
    reset(); infra=nullptr; { Resolver r{}; run(r,false); assert(sent.size()==2); for(auto &s:sent) assert(s.interface.empty()); cancel(r); }
    std::cout<<"PASS host DNS works without infrastructure interface\n";
    reset(); failSocketCall=2; { Resolver r{}; run(r,false); assert(sent.empty()); assert(sockets.empty()); }
    std::cout<<"PASS IPv6 allocation failure closes prior IPv4 socket\n";
    reset(); failSocketCall=3; { Resolver r{}; run(r,true); assert(sent.size()==3); for(auto &s:sent) assert(s.interface.empty()); assert(sockets.size()==2); cancel(r); }
    std::cout<<"PASS RDNSS allocation failure falls back without leak\n";
}
