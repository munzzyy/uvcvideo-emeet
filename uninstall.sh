#!/usr/bin/env bash
set -euo pipefail

[ "$(id -u)" -eq 0 ] || { echo "run with sudo" >&2; exit 1; }

kver=$(uname -r)
rm -f "/usr/lib/modules/$kver/updates/uvcvideo.ko"
depmod "$kver"

modprobe -r uvcvideo || { echo "uvcvideo is busy; close camera users and run: sudo modprobe -r uvcvideo && sudo modprobe uvcvideo" >&2; exit 1; }
modprobe uvcvideo
echo "loaded: $(modinfo -n uvcvideo)"
