#!/usr/bin/env bash
set -euo pipefail

[ "$(id -u)" -eq 0 ] || { echo "run with sudo" >&2; exit 1; }

here=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")
kver=$(uname -r)
ko="$here/src/uvcvideo.ko"
dest="/usr/lib/modules/$kver/updates"

[ -f "$ko" ] || { echo "missing $ko, run 'make -C $here/src' first" >&2; exit 1; }
vm=$(modinfo -F vermagic "$ko")
case "$vm" in
    "$kver "*) ;;
    *) echo "module built for '$vm', running kernel is $kver" >&2; exit 1 ;;
esac

install -d "$dest"
tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
strip --strip-debug -o "$tmp" "$ko"
install -m 0644 "$tmp" "$dest/uvcvideo.ko"
depmod "$kver"

echo "stop anything using the camera (OBS, browsers, ffmpeg), then reloading uvcvideo"
modprobe -r uvcvideo || { echo "uvcvideo is busy; close camera users and run: sudo modprobe -r uvcvideo && sudo modprobe uvcvideo" >&2; exit 1; }
modprobe uvcvideo

echo "loaded: $(modinfo -n uvcvideo)"
echo "check:  $here/tools/verify-live.sh"
