#!/usr/bin/env bash
set -euo pipefail

[ "$(id -u)" -eq 0 ] || { echo "run with sudo" >&2; exit 1; }

here=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")
kver=$(uname -r)
name=uvcvideo-emeet
ver=$(sed -n 's/^PACKAGE_VERSION="\(.*\)"/\1/p' "$here/src/dkms.conf")

command -v dkms >/dev/null || { echo "dkms not found (pacman -S dkms linux-headers)" >&2; exit 1; }
[ -d "/usr/lib/modules/$kver/build" ] || { echo "no headers for $kver (pacman -S linux-headers)" >&2; exit 1; }

if dkms status "$name/$ver" 2>/dev/null | grep -q .; then
    echo "removing the registered $name/$ver so the current sources get built"
    dkms remove "$name/$ver" --all
fi
rm -rf "/usr/src/$name-$ver"

loose="/usr/lib/modules/$kver/updates/uvcvideo.ko"
if [ -f "$loose" ]; then
    echo "removing the copy install.sh placed at $loose, DKMS owns the module from here"
    rm -f "$loose"
fi

dkms install "$here/src"

echo "stop anything using the camera (OBS, browsers, ffmpeg), then reloading uvcvideo"
modprobe -r uvcvideo || { echo "uvcvideo is busy; close camera users and run: sudo modprobe -r uvcvideo && sudo modprobe uvcvideo" >&2; exit 1; }
modprobe uvcvideo

echo "loaded:  $(modinfo -n uvcvideo) ($(modinfo -F version uvcvideo))"
echo "status:  $(dkms status "$name/$ver")"
echo "check:   $here/tools/verify-live.sh"
