#!/usr/bin/env bash
set -euo pipefail
I="${1:?initramfs.gz}"; W="$(mktemp -d /tmp/sr-audit.XXXXXX)"; trap 'rm -rf "$W"' EXIT; cd "$W"
gzip -t "$I"; gzip -dc "$I"|cpio -idm >/dev/null 2>&1
stat -c '%a %A %U:%G %s %n' usr/bin/sudo; sha256sum usr/bin/sudo
ls -l usr/sbin/nbd-client; sha256sum usr/sbin/nbd-client
grep -n -E 'nbd\*|NBD=|nbd-client|/dev/nbd0' etc/init.d/tc-config
