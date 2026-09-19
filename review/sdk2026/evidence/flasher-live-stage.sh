#!/bin/sh
set -eu
umask 077
stage=/share/codex-sdk2026-stage-20260919
bundle=$stage/bundle
venv=/tmp/codex-sdk2026-flasher
[ "$(sha256sum "$stage/flasher-bundle.tar" | cut -d ' ' -f 1)" = ca589f0efc1d722db1ca0b75c2a9b7734a7896c84db48f486f2bb9e44accdfe0 ]
test ! -e "$bundle"
test ! -e "$venv"
mkdir "$bundle"
tar -xf "$stage/flasher-bundle.tar" -C "$bundle"
cd "$bundle"
cat > "$stage/SHA256SUMS" <<'MANIFEST'
4fde928e881fa8a16d12f889d9fe3198067fb6302d6e4fe896535b14b27097e4  alpine-packages.txt
3278ccba30b241168ca4ab93c919be805411b918fdc062f06d3684d12dc33ae3  apks/gdbm-1.26-r0.apk
2737e2b23ed08d4911ee62cd0163b5f4bf0379cacf4dc35b23a00209584c98fd  apks/libbz2-1.0.8-r6.apk
161223a16f042b8e469e9441291e071464fd91d4f4bbe6f496ee8d0abd4e0701  apks/libcrypto3-3.5.8-r0.apk
34fa41e3994d9a844f50a7c01cb40bb2e272fa7f506b96e92a2b4a20b23a81bc  apks/libexpat-2.8.4-r0.apk
6da1a19313a40c56cac756fb11e2c4d5267831e1c22fc8323f24c943c94da6e0  apks/libffi-3.5.2-r1.apk
393dcd32629f06d7d85409c272d142d0c082772d10b87ef55ee82f47de3be637  apks/libgcc-15.2.0-r5.apk
cf8caa8a88bc4ce9d9e395567fefaf9ef7fbd55c50ae6155b35c1b58f3755023  apks/libncursesw-6.6_p20260516-r0.apk
057be8b1b788580f4cb72c382a6dcc03467d15bd69700f32192bd709e7a57a12  apks/libpanelw-6.6_p20260516-r0.apk
aca521e5ae4a321322a9d47ed64a1775f5ab1ffd215d1e9fc0433c58f7bfd037  apks/libssl3-3.5.8-r0.apk
14c987b556f5385a5db18376e788c75f37d85321b8dc1920d926ea7daac1d6f6  apks/libstdc++-15.2.0-r5.apk
1278f374bbc8b4aad674244458cca5fc63e0780a921138eef400d5db64381a31  apks/mpdecimal-4.0.1-r0.apk
573712e2f49c15bfc20a2699f204acdfc74c772722b15e7353d768057fae0e71  apks/musl-1.2.6-r2.apk
ce83be6d0bd10584a53c3a5868cc1595ce5f0f8e0b621f8f7f70b6144e521fc9  apks/ncurses-terminfo-base-6.6_p20260516-r0.apk
8ab13441fd0abfd625ac4e91eed5648d90a6422359d45469307bd78ad4f1b223  apks/py3-pip-26.1.2-r0.apk
b7a66a9b68224468f9398220df4620f74747ee98e7526c2968c469c09a04cc37  apks/py3-pip-pyc-26.1.2-r0.apk
353665d585c0c54705794fea9667c6b8afe8accb525e30819e9c1d4b9383b673  apks/pyc-3.14.7-r1.apk
8b7e0ce40ab6f0955138e791caf3e16c8b4616befde61c840137cc1a16770985  apks/python3-3.14.7-r1.apk
c9da22e6f75c460ebc9d157a2c46393cd9ab6da83b6ab64044910b43a87c8df1  apks/python3-pyc-3.14.7-r1.apk
04c6f299bd36870a78e8afe1a04e8c64673d46ad3905f84b590b36281f947bd1  apks/python3-pycache-pyc0-3.14.7-r1.apk
766911ecb986a6c5cf0841a6b556cd1e9dbbf22b3559726de32416486cd15c81  apks/readline-8.3.3-r1.apk
a8a216e53d22faa3f04d2e3650c1991af66f8d0b42fadff5afcdb9afb60b19e5  apks/sqlite-libs-3.53.4-r0.apk
ab362dd515ead04c31a6c302163248da7aa4813e283c971e6dd3f789b453a1d9  apks/xz-libs-5.8.4-r0.apk
b636306cbf8a0c15493b38de608ba11605fd8f11ade631f5ece6f7fdf5a1e09e  apks/zlib-1.3.2-r0.apk
b5deda18cba9f07f03f5faeb5d6969e51110bf0bd8450dd00bb3cf14047a9d50  firmware/candidate.gbl
22c4d75097b5cda0e8d60634cc1753d9615069398055b81b8c5a219e64f49897  firmware/recovery.gbl
40fd84de70686326e76b4836c765255f7b50a26a22c1c17ca40af770eadea787  firmware/rollback.gbl
86ea742a47319ed9f7fcd762060e5f5f39e41075d7456cf53cc34d19cec191f2  offline-test.log
0366d77cc1f1ac88ea458231ba4f639323d5caf34de0d50b7618277fd4395f1f  python-version.txt
5d99bfb66ae4dbcf1104e2d99c8a5a0fb0b47e87370764e55a2efa2315ecbf00  requirements-resolved.txt
2ae6080e12d7618bf4461d07850c327f59c457ebc02ee637aff6b16fb07a70fc  verify-offline.sh
9243213661e29250eb41368e5daa826fc017156c3b8a11440826b2e3ed376472  wheels/aiohappyeyeballs-2.7.1-py3-none-any.whl
1c5ec8fb1bcc31a8466f74aaf26c345d5c386fa4bd08a3f0eb9c7a4a3fe8b5bf  wheels/aiohttp-3.14.3-cp314-cp314-musllinux_1_2_x86_64.whl
053243f8b92b990551949e63930a839ff0cf0b0ebbe0597b0f3fb19e1a0fe82e  wheels/aiosignal-1.4.0-py3-none-any.whl
2549cf4057f95f53dcba16f2b64e8e2791d7e1adedb13197dd8ed77bb226d7d0  wheels/aiosqlite-0.21.0-py3-none-any.whl
c647aa4a12dfbad9333ca4e71fe62ddc36f4e63b2d260a37a8b83d2f043ac309  wheels/attrs-26.1.0-py3-none-any.whl
4a0047b942aca1105da3b069a5037e74a321972f03e0646de32cf05b379df824  wheels/bellows-1.0.2-py3-none-any.whl
5c58fe613dc5e5336357eff555824a314d8e43282600435c8d1cb6a7a2fedd13  wheels/cffi-2.1.1-cp314-cp314-musllinux_1_2_x86_64.whl
255bc9599cf7748b4b1a446ccc735421bd08a2ae529a8b88597d3de5664ee360  wheels/click-8.5.0-py3-none-any.whl
a43e394b528d52112af599f2fc9e4b7cf3c15f94e53581f74fa6867e68c91756  wheels/click_log-0.4.0-py2.py3-none-any.whl
612ee75c546f53e92e70049c9dbfcc18c935a2b9a53b66085ce9ef6a6e5c0934  wheels/coloredlogs-15.0.1-py2.py3-none-any.whl
2c3603d5d8f5b241ba7fcc466b1fa9b0cbcbf45ebeaf5598c46dd4dcfb9e396e  wheels/crc-8.0.0-py3-none-any.whl
1680c9a7bb1ca4bec45fa19b8ca64319f10d2ce4eb8b0d25d51cb99a20ca0108  wheels/crccheck-1.3.1-py3-none-any.whl
9ebcdd5519be9b652a46f507817a74591774fc3d6923ac364e4dfa64e36b291b  wheels/cryptography-50.0.1-cp311-abi3-musllinux_1_2_x86_64.whl
972af65924ea25cf5b4d9326d549e69a9a4918d8a76a9d3a7cd174d98b237550  wheels/frozendict-2.4.7-py3-none-any.whl
073f8bf8becba60aa931eb3bc420b217bb7d5b8f4750e6f8b3be7f3da85d38b7  wheels/frozenlist-1.8.0-cp314-cp314-musllinux_1_2_x86_64.whl
36810ddf5ad35d30eef75c8c317339b1da8e8faf799953406925fa6777f82de2  wheels/gpiod-2.5.0-cp314-cp314-musllinux_1_2_x86_64.whl
1697e1a8a8f550fd43c2865cd84542fc175a61dcb779b6fee18cf6b6ccba1477  wheels/humanfriendly-10.0-py2.py3-none-any.whl
ab7ae7122974553370f0bdb919e1a960b2cd1bc1ef0276416d896db81c14582c  wheels/idna-3.20-py3-none-any.whl
d489f15263b8d200f8387e64b4c3a75f06629559fb73deb8fdfb525f2dab50ce  wheels/jsonschema-4.26.0-py3-none-any.whl
98802fee3a11ee76ecaca44429fda8a41bff98b00a0f2838151b113f210cc6fe  wheels/jsonschema_specifications-2025.9.1-py3-none-any.whl
448c05bd13f8675b3629fbc3fabb9e7bb19a5636a7a3eb677ea25a08d0544a56  wheels/multidict-6.9.0-cp314-cp314-musllinux_1_2_x86_64.whl
9fb0a5be8d9aa213150e8d8148a42aca4984b285bcad1e69587dc4298edd929b  wheels/propcache-0.5.4-cp314-cp314-musllinux_1_2_x86_64.whl
b727414169a36b7d524c1c3e31839a521725078d7b2ff038656844266160a992  wheels/pycparser-3.0-py3-none-any.whl
381329a9f99628c9069361716891d34ad94af76e461dcb0335825aecc7692231  wheels/referencing-0.37.0-py3-none-any.whl
639c8929aa0afe81be836b04de888460d6bed38b9c54cfc18da8f6bfabf5af5d  wheels/rpds_py-2026.6.3-cp314-cp314-musllinux_1_2_x86_64.whl
256712ba329d9ce0d1d08e0ddc6e9cd5d55784d15d47a70ea64f3610b37e8091  wheels/serialx-1.10.0-py3-none-any.whl
c293e525e6fef9c20e8728fd4612df02a0aa31bb5fe91ecd93e123b1b7bffa73  wheels/tqdm-4.70.1-py3-none-any.whl
481caa481374e813c1b176ada14e97f1f67a4539ce9cfeb3f350d78d6370c2e8  wheels/typing_extensions-4.16.0-py3-none-any.whl
e0aedb6e0f65992032169046c73fde54664855d8732faab660a614d30acd2cf8  wheels/universal_silabs_flasher-1.1.0-py3-none-any.whl
ee342095263e1b5afbd4d418cb5adc92810eebfd07696bb033a261210df33db4  wheels/voluptuous-0.16.0-py3-none-any.whl
90c30ed53546da833c700115c0064c22120d1b1560f474699fd31f22dd668233  wheels/yarl-1.25.1-cp314-cp314-musllinux_1_2_x86_64.whl
e941a350bc8b1a4a9c14436d022fe31acfd78b09f15be32a425090fd1d24a231  wheels/zigpy-2.2.0-py3-none-any.whl
MANIFEST
sha256sum -c "$stage/SHA256SUMS" > "$stage/files-verified.log"
apk info -v | sort > "$stage/packages-before.txt"
set --
for package in "$bundle"/apks/*.apk; do
 name=${package##*/}; name=${name%-r*}; name=${name%-*}
 if ! apk info --exists "$name" >/dev/null 2>&1; then set -- "$@" "$package"; fi
done
apk add --simulate --no-network --virtual .codex-sdk2026-flasher "$@" > "$stage/apk-simulation.log" 2>&1
if grep -Eq 'Upgrading|Downgrading|Purging|Removing' "$stage/apk-simulation.log"; then
 echo 'REFUSED: simulation changes an existing package'; exit 1
fi
apk add --no-network --virtual .codex-sdk2026-flasher "$@" > "$stage/apk-install.log" 2>&1
python3 -m venv "$venv"
"$venv/bin/pip" install --no-index --find-links "$bundle/wheels" universal-silabs-flasher==1.1.0 > "$stage/pip-install.log" 2>&1
"$venv/bin/pip" check
"$venv/bin/universal-silabs-flasher" --help > "$stage/flasher-help.txt"
for firmware in "$bundle"/firmware/*.gbl; do
 "$venv/bin/universal-silabs-flasher" dump-gbl-metadata --firmware "$firmware"
done
apk info -v | sort > "$stage/packages-after.txt"
if ! comm -23 "$stage/packages-before.txt" "$stage/packages-after.txt" | grep -q .; then
 echo 'PASS: all original package versions retained'
else
 echo 'FAIL: existing package inventory changed'; exit 1
fi
printf 'FLASHER_STAGED_AND_OFFLINE_VALIDATED_NO_SERIAL_ACCESS\n'
