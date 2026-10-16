#!/usr/bin/env bash
set -euo pipefail

dev=${1:-/dev/v4l/by-id/usb-EMEET_EMEET_SmartCam_C60E_4K_Dual_A260808000902961-video-index0}
command -v v4l2-ctl >/dev/null || { echo "v4l2-ctl not found (pacman -S v4l-utils)" >&2; exit 2; }

read_zoom() { v4l2-ctl -d "$dev" --get-ctrl=zoom_absolute | awk -F': *' '{print $2}'; }

a=$(read_zoom)
echo "zoom_absolute now: $a"
echo "press the remote's 11X (or any zoom button) within 3 seconds"
sleep 3
b=$(read_zoom)
echo "zoom_absolute after: $b"

if [ "$a" != "$b" ]; then
    echo "PASS: the driver saw the remote's change"
else
    echo "FAIL: value unchanged (did you press the button, and is the patched module loaded?)"
    echo "loaded module: $(modinfo -n uvcvideo)"
    exit 1
fi
