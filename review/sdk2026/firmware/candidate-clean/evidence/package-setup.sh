#!/bin/sh
# Freeze package indices and downloads to one reviewed Debian archive timestamp.
set -eu
sources=/etc/apt/sources.list.d/debian.sources
# These pinned bases have exactly one deb822 file. Refuse unreviewed mirrors.
test ! -e /etc/apt/sources.list
test "$(find /etc/apt/sources.list.d -maxdepth 1 -type f | wc -l)" -eq 1
test "$(grep -c '^URIs: http://deb.debian.org/debian\(-security\)\?$' "$sources")" -eq 2
test "$(grep -c '^Signed-By: /usr/share/keyrings/debian-archive-keyring.pgp$' "$sources")" -eq 2
sed -i \
  -e '/^# http:\/\/snapshot.debian.org\/archive\//d' \
  -e 's|^URIs: http://deb.debian.org/debian$|URIs: https://snapshot.debian.org/archive/debian/20260914T000000Z/|' \
  -e 's|^URIs: http://deb.debian.org/debian-security$|URIs: https://snapshot.debian.org/archive/debian-security/20260914T000000Z/|' \
  -e '/^Signed-By:/a Check-Valid-Until: no' "$sources"
# Snapshot metadata deliberately ages. Disable expiry only on these two sources;
# signatures and signed index/package hashes remain mandatory. Fail any index
# error, instead of apt's default warning and reuse of stale index files.
cat > /etc/apt/apt.conf.d/99sdk2026-snapshot <<'APT'
// Direct timestamped URIs above are authoritative. Do not let a base image's
// older APT::Snapshot setting remap package-list lookup to another timestamp.
APT::Snapshot "";
Acquire::Check-Valid-Until "true";
Acquire::AllowInsecureRepositories "false";
Acquire::AllowDowngradeToInsecureRepositories "false";
APT::Get::AllowUnauthenticated "false";
APT::Update::Error-Mode "any";
APT
