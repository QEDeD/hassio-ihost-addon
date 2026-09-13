/* Linux-only, one-shot IPv6 UDP injector. Requires CAP_NET_RAW.
 * Build: cc -std=c11 -O2 -Wall -Wextra -Werror -static -o inject6 inject6.c
 * Usage: inject6 SRC_IPV6 DST_IPV6 SRCPORT DSTPORT < payload.bin
 * No address, route or firewall changes; no retries. Input must reach EOF.
 */
#define _DEFAULT_SOURCE
#include <arpa/inet.h>
#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <unistd.h>

enum { MAX_PAYLOAD = 512, IP_LEN = 40, UDP_LEN = 8 };

static void put16(uint8_t *p, uint16_t n)
{
    p[0] = (uint8_t)(n >> 8);
    p[1] = (uint8_t)n;
}

static uint32_t sum_bytes(uint32_t sum, const uint8_t *p, size_t n)
{
    while (n >= 2) {
        sum += ((uint32_t)p[0] << 8) | p[1];
        p += 2;
        n -= 2;
    }
    if (n) sum += (uint32_t)p[0] << 8;
    return sum;
}

/* UDP checksum field must be zero on entry. Addresses are network bytes. */
static uint16_t udp_checksum(const uint8_t *src, const uint8_t *dst,
                             const uint8_t *udp, size_t n)
{
    uint32_t sum = sum_bytes(0, src, 16);
    sum = sum_bytes(sum, dst, 16);
    /* Length <= 520: upper 16 bits of the pseudoheader length are zero. */
    sum += (uint32_t)n + IPPROTO_UDP;
    sum = sum_bytes(sum, udp, n);
    while (sum >> 16) sum = (sum & 0xffffu) + (sum >> 16);
    uint16_t result = (uint16_t)~sum;
    return result ? result : 0xffffu;
}

static int parse_port(const char *text, uint16_t *port)
{
    unsigned long n;
    char *end;
    if (!*text) return 0;
    for (const char *p = text; *p; ++p)
        if (*p < '0' || *p > '9') return 0;
    errno = 0;
    n = strtoul(text, &end, 10);
    if (errno || *end || n == 0 || n > 65535) return 0;
    *port = (uint16_t)n;
    return 1;
}

static int parse_address(const char *text, struct in6_addr *address)
{
    return inet_pton(AF_INET6, text, address) == 1 &&
           !IN6_IS_ADDR_UNSPECIFIED(address) &&
           !IN6_IS_ADDR_MULTICAST(address) &&
           !IN6_IS_ADDR_V4MAPPED(address) &&
           !IN6_IS_ADDR_LINKLOCAL(address);
}

static int self_test(void)
{
    struct in6_addr src, dst;
    uint8_t udp[11] = {0};
    if (inet_pton(AF_INET6, "2001:db8::1", &src) != 1 ||
        inet_pton(AF_INET6, "2001:db8::2", &dst) != 1) return 1;
    put16(udp, 12345);
    put16(udp + 2, 5540);
    put16(udp + 4, 8);
    if (udp_checksum(src.s6_addr, dst.s6_addr, udp, 8) != 0x5e8c)
        return 1;
    put16(udp + 4, 11);
    udp[8] = 1; udp[9] = 2; udp[10] = 3;
    if (udp_checksum(src.s6_addr, dst.s6_addr, udp, 11) != 0x5a84)
        return 1;
    /* A payload that produces mathematical checksum zero must emit ffff. */
    put16(udp + 4, 10);
    put16(udp + 8, 0x5e88);
    if (udp_checksum(src.s6_addr, dst.s6_addr, udp, 10) != 0xffff)
        return 1;
    puts("checksum self-test passed (empty, odd length, zero encoding)");
    return 0;
}

int main(int argc, char **argv)
{
    struct in6_addr src, dst;
    struct sockaddr_in6 target = {0};
    uint16_t sport, dport;
    uint8_t packet[IP_LEN + UDP_LEN + MAX_PAYLOAD] = {0};
    uint8_t *udp = packet + IP_LEN;
    size_t n;
    int fd, enabled = 1;
    ssize_t sent;

    if (argc == 2 && strcmp(argv[1], "--self-test") == 0)
        return self_test();
    if (argc != 5) {
        fprintf(stderr, "Usage: %s SRC_IPV6 DST_IPV6 SRCPORT DSTPORT < payload\n"
                        "       %s --self-test\n", argv[0], argv[0]);
        return 2;
    }
    if (!parse_address(argv[1], &src) || !parse_address(argv[2], &dst) ||
        !parse_port(argv[3], &sport) || !parse_port(argv[4], &dport)) {
        fputs("Invalid address or port; use unicast IPv6 without scope IDs, "
              "excluding unspecified, link-local and IPv4-mapped addresses; "
              "ports must be 1..65535.\n", stderr);
        return 2;
    }
    n = fread(udp + UDP_LEN, 1, MAX_PAYLOAD, stdin);
    if (ferror(stdin)) { fputs("Payload read failed\n", stderr); return 1; }
    if (fgetc(stdin) != EOF) {
        fputs("Payload exceeds 512 bytes\n", stderr);
        return 2;
    }
    if (ferror(stdin)) { fputs("Payload read failed\n", stderr); return 1; }

    packet[0] = 0x60;
    put16(packet + 4, (uint16_t)(UDP_LEN + n));
    packet[6] = IPPROTO_UDP;
    packet[7] = 64;
    memcpy(packet + 8, &src, 16);
    memcpy(packet + 24, &dst, 16);
    put16(udp, sport);
    put16(udp + 2, dport);
    put16(udp + 4, (uint16_t)(UDP_LEN + n));
    put16(udp + 6, udp_checksum(src.s6_addr, dst.s6_addr, udp, UDP_LEN + n));

    fd = socket(AF_INET6, SOCK_RAW, IPPROTO_RAW);
    if (fd < 0) { perror("socket"); return 1; }
    if (setsockopt(fd, IPPROTO_IPV6, IPV6_HDRINCL, &enabled, sizeof enabled) < 0) {
        perror("IPV6_HDRINCL");
        close(fd);
        return 1;
    }
    target.sin6_family = AF_INET6;
    target.sin6_addr = dst;
    /* Linux raw IPv6 sendto expects sin6_port zero, not the UDP port. */
    sent = sendto(fd, packet, IP_LEN + UDP_LEN + n, 0,
                  (const struct sockaddr *)&target, sizeof target);
    if (sent < 0) { perror("sendto"); close(fd); return 1; }
    close(fd);
    if ((size_t)sent != IP_LEN + UDP_LEN + n) {
        fputs("Incomplete packet send\n", stderr);
        return 1;
    }
    fprintf(stderr, "Submitted one IPv6 UDP packet (%zu payload bytes); "
                    "delivery is not verified.\n", n);
    return 0;
}
