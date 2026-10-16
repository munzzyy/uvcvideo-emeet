# uvcvideo-emeet

A one-device quirk for the Linux uvcvideo driver so it sees changes the EMEET SmartCam C60E 4K (USB 328f:00e1) makes on its own, like the IR remote's zoom buttons.

Licence: GPL-2.0-or-later, same as the kernel's uvcvideo files this is built from (see `LICENSE` and the SPDX line at the top of each source file). The module is loaded into the kernel, so only use builds you made from sources you have read.

Targets: the EMEET C60E 4K Dual and a Linux kernel built from the v7.2.8 sources in `src/` (other cameras are untouched). Install: `make -C src`, then `sudo ./install.sh`, or DKMS (see below). Specific to the author's machine: the Arch Linux kernel it was built and tested against, and the companion `cameractrls-emeet` and `lark` projects that rely on live reads. Nothing in the repo is tied to one unit of the camera.

## Why

The driver caches control values. It re-reads a control from the camera only if the control is flagged AUTO_UPDATE, or if the camera sends a status interrupt saying it changed. This camera's firmware clears AUTO_UPDATE in its GET_INFO answer and never sends the interrupt. So after the first read, `v4l2-ctl --get-ctrl=zoom_absolute` returns the cached value forever, even after the remote changed the real zoom.

The quirk (UVC_QUIRK_FORCE_AUTO_UPDATE) keeps AUTO_UPDATE set for every control of this one device that supports GET_CUR. The existing code then drops the cache on each get and asks the camera.

Relevant spots in the v7.2.8 source: `uvc_ctrl_get_flags()` (overwrites the flags from the device byte), `__uvc_ctrl_load_cur()` (returns the cache when `ctrl->loaded`), `uvc_ctrl_commit_entity()` (clears `loaded` only for AUTO_UPDATE controls), `uvc_ctrl_status_event()` (the interrupt path this firmware never uses).

## The patch

Also in `uvc-force-auto-update.patch`. Base is stable v7.2.8; pristine copies are in `upstream/` with hashes in `upstream.sha256`. The patched copies are in `src/`.

```diff
--- a/uvc_ctrl.c
+++ b/uvc_ctrl.c
@@ -2876,6 +2876,10 @@
 				UVC_CTRL_FLAG_AUTO_UPDATE : 0)
 			    |  (data[0] & UVC_CONTROL_CAP_ASYNCHRONOUS ?
 				UVC_CTRL_FLAG_ASYNCHRONOUS : 0);
+
+		if (dev->quirks & UVC_QUIRK_FORCE_AUTO_UPDATE &&
+		    info->flags & UVC_CTRL_FLAG_GET_CUR)
+			info->flags |= UVC_CTRL_FLAG_AUTO_UPDATE;
 	}
 
 	kfree(data);
--- a/uvc_driver.c
+++ b/uvc_driver.c
@@ -3270,6 +3270,15 @@
 	  .bInterfaceSubClass	= 1,
 	  .bInterfaceProtocol	= UVC_PC_PROTOCOL_UNDEFINED,
 	  .driver_info		= UVC_INFO_META(V4L2_META_FMT_D4XX) },
+	/* EMEET SmartCam C60E 4K: firmware clears AUTO_UPDATE and sends no status events */
+	{ .match_flags		= USB_DEVICE_ID_MATCH_DEVICE
+				| USB_DEVICE_ID_MATCH_INT_INFO,
+	  .idVendor		= 0x328f,
+	  .idProduct		= 0x00e1,
+	  .bInterfaceClass	= USB_CLASS_VIDEO,
+	  .bInterfaceSubClass	= 1,
+	  .bInterfaceProtocol	= UVC_PC_PROTOCOL_UNDEFINED,
+	  .driver_info		= UVC_INFO_QUIRK(UVC_QUIRK_FORCE_AUTO_UPDATE) },
 	/* Generic USB Video Class */
 	{ USB_INTERFACE_INFO(USB_CLASS_VIDEO, 1, UVC_PC_PROTOCOL_UNDEFINED) },
 	{ USB_INTERFACE_INFO(USB_CLASS_VIDEO, 1, UVC_PC_PROTOCOL_15) },
--- a/uvcvideo.h
+++ b/uvcvideo.h
@@ -81,6 +81,7 @@
 #define UVC_QUIRK_INVALID_DEVICE_SOF	0x00010000
 #define UVC_QUIRK_MJPEG_NO_EOF		0x00020000
 #define UVC_QUIRK_MSXU_META		0x00040000
+#define UVC_QUIRK_FORCE_AUTO_UPDATE	0x00080000
 
 /* Format flags */
 #define UVC_FMT_FLAG_COMPRESSED		0x00000001
```

## Build

```
make -C src
```

Reads the headers in `/usr/lib/modules/$(uname -r)/build`, writes `src/uvcvideo.ko`, no network, no sudo. Built here against 7.2.8-arch1-2: vermagic `7.2.8-arch1-2 SMP preempt mod_unload`, same depends line as the stock module, and `modinfo -F alias src/uvcvideo.ko` contains `usb:v328Fp00E1d*dc*dsc*dp*ic0Eisc01ip00in*` (the stock module has no such alias, it only binds through the generic class match).

## Install (loads a module, needs sudo)

```
sudo ./install.sh
tools/verify-live.sh
```

install.sh puts the module in `/usr/lib/modules/$(uname -r)/updates/`, which depmod prefers over the stock one, then reloads uvcvideo. Close OBS, browsers and ffmpeg first or the unload fails (it tells you and stops). verify-live.sh reads zoom twice, 3 seconds apart; press the remote's 11X in between. PASS means the value changed.

## Undo

```
sudo ./uninstall.sh
```

Removes the file, runs depmod, reloads the stock module. A reboot does the same once the file is gone.

## Kernel updates

Without DKMS, a kernel update brings the stock driver back and the remote goes invisible again until you rebuild and run install.sh. To have it rebuilt automatically:

```
sudo pacman -S dkms linux-headers
sudo dkms install ./src
```

`src/dkms.conf` is package uvcvideo-emeet version 1.0, autoinstall on, destination `/updates`. Remove with `sudo dkms remove uvcvideo-emeet/1.0 --all`.

## Risks

- The module is unsigned, so loading it taints the kernel. Secure Boot with enforced module signatures would refuse it; MODULE_SIG_FORCE is off here.
- It replaces the uvcvideo for every UVC camera, but only 328f:00e1 gets the quirk. Other cameras behave exactly as before.
- Each control read now costs a USB control transfer (a few hundred bytes), instead of being served from the cache. Anything that polls many controls will generate more traffic.
- Setting the module parameter `quirks=` replaces this device's quirks, so it would turn the fix off.
- The bundled sources are v7.2.8. On a much newer kernel the build fails against its headers, and the sources would pin you to old driver code; rebase the patch onto that kernel's uvc files then.

## Verified

Built, loaded and read live on 7.2.8-arch1-2: with the module loaded, `zoom_absolute` follows the remote's step buttons. The DKMS flow is untested.
