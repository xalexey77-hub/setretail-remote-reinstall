#!/usr/bin/env bash
set -euo pipefail
BASE="${1:?NBD initramfs.gz}"; OUT="${2:-/boot/setretail-core-preflight-v3.gz}"; PORT="${3:-10022}"
W="$(mktemp -d /tmp/sr-preflight.XXXXXX)"; trap 'rm -rf "$W"' EXIT; cd "$W"
gzip -dc "$BASE"|cpio -idm
python3 - "$PORT" <<'PY'
from pathlib import Path
import sys
port=int(sys.argv[1]); p=Path("etc/init.d/tc-config"); s=p.read_text()
marker="# After restore items"; tag="SETRETAIL SAFE PREFLIGHT REMOTE DEBUG"
if tag in s: raise SystemExit("already patched")
if marker not in s: raise SystemExit("marker not found")
patch=("# ===== "+tag+" =====\n(\n"
       '    echo "REMOTE DEBUG START PORT=%d" > /tmp/preflight-remote.log\n'%port+
       '    /usr/bin/nc -lk -p %d -e /bin/ash >>/tmp/preflight-remote.log 2>&1\n'%port+
       ") &\necho $! > /tmp/preflight-nc.pid\n# ===== END "+tag+" =====\n\n")
p.write_text(s.replace(marker,patch+marker,1))
PY
find . -print0|cpio --null -o --format=newc 2>"$W/pack.log"|gzip -9>"$OUT"
gzip -t "$OUT"; echo "OK: $OUT"; sha256sum "$OUT"
