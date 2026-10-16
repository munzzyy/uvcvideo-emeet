#!/usr/bin/env bash
set -euo pipefail

find_camera() {
    local d
    for d in /sys/class/video4linux/video*; do
        [ "$(cat "$d/index" 2>/dev/null)" = 0 ] || continue
        [ "$(cat "$d/device/../idVendor" 2>/dev/null):$(cat "$d/device/../idProduct" 2>/dev/null)" = 328f:00e1 ] || continue
        echo "/dev/$(basename "$d")"
        return
    done
}
dev=${1:-$(find_camera)}
[ -n "$dev" ] || { echo "no camera with USB id 328f:00e1 found, pass the device as the first argument" >&2; exit 2; }
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
