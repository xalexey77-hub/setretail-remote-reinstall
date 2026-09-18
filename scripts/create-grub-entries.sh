#!/usr/bin/env bash
set -euo pipefail
IP="${1:?NBD_SERVER_IP}"; PORT="${2:-10810}"
KERNEL="${3:-/boot/setretail-vmlinuz}"; PRE="${4:-/boot/setretail-core-preflight-v3.gz}"; INS="${5:-/boot/setretail-core-nbd-v3.gz}"
printf '%s\n' '#!/bin/sh' 'exec tail -n +3 $0' '' \
"menuentry 'SetRetail NBD SAFE PREFLIGHT V3' --id setretail-nbd-preflight-v3 {" \
"    linux $KERNEL loglevel=3 tce=nbd0/boot/tce setmode=preflight nbd=${IP}:${PORT}:no-ping efi32=0 loop.max_loop=255 norestore noswap" \
"    initrd $PRE" '}' >/etc/grub.d/43_setretail_preflight_v3
printf '%s\n' '#!/bin/sh' 'exec tail -n +3 $0' '' \
"menuentry 'SetRetail NBD Remote Install V3' --id setretail-nbd-install-v3 {" \
"    linux $KERNEL loglevel=3 tce=nbd0/boot/tce setmode=install nbd=${IP}:${PORT}:no-ping efi32=0 loop.max_loop=255" \
"    initrd $INS" '}' >/etc/grub.d/44_setretail_install_v3
chmod 755 /etc/grub.d/43_setretail_preflight_v3 /etc/grub.d/44_setretail_install_v3
update-grub
grep -n -A3 -B1 'SetRetail NBD .* V3' /boot/grub/grub.cfg || true
