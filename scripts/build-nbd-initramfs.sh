#!/usr/bin/env bash
set -euo pipefail
CORE="${1:?core.gz}"; NBD="${2:?static nbd-client}"; OUT="${3:-/boot/setretail-core-nbd-v3.gz}"
W="$(mktemp -d /tmp/sr-nbd.XXXXXX)"; trap 'rm -rf "$W"' EXIT
mkdir -p "$W/src" "$W/check"; cd "$W/src"
gzip -dc "$CORE"|cpio -idm
test -x usr/bin/sudo
H="$(sha256sum usr/bin/sudo|awk '{print $1}')"; M="$(stat -c %a usr/bin/sudo)"
install -m 0755 "$NBD" usr/sbin/nbd-client
find . -print0|cpio --null -o --format=newc 2>"$W/pack.log"|gzip -9>"$OUT"
gzip -t "$OUT"; cd "$W/check"; gzip -dc "$OUT"|cpio -idm >/dev/null 2>&1
test "$(sha256sum usr/bin/sudo|awk '{print $1}')" = "$H"
test "$(stat -c %a usr/bin/sudo)" = "$M"; test -x usr/sbin/nbd-client
echo "OK: $OUT"; sha256sum "$OUT"; stat -c '%a %A %U:%G %s %n' usr/bin/sudo
