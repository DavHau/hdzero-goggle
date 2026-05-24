#!/usr/bin/env bash
# Flash boot0 + u-boot (boot_package) to the internal eMMC.
#
# Replaces the removed vendor `ota-burnuboot` / `libota-burnboot.so` blobs
# that the vendor `rc.sh` used to write the bootloader during the OTA flow.
# Our image never runs rc.sh, so the blobs were dropped in commit
# "Drop the vendor bootloader OTA flasher" (ltqtnzvkyzzo).
#
# UNTESTED: offsets match nix/sdcard/genimage.cfg (boot0 at 8K,
# boot_package at 16400K), but this script has not been run on hardware
# yet. Verify the eMMC device node and dry-run with `--dry-run` before
# flashing. A bad write to boot0 bricks internal boot — SD card recovery
# (sdcard-nixos-mainline image) is then the only way back in, short of
# FEL mode over USB.
#
# Usage:
#   flash-internal-uboot.sh [--dry-run] <boot0.fex> <boot_package.fex> <device>
#
# Example (booted from SD, internal eMMC is typically mmcblk2 on V536 —
# confirm with `lsblk` / `cat /sys/block/*/device/type` first):
#   flash-internal-uboot.sh boot0.fex boot_package.fex /dev/mmcblk2
set -euo pipefail

DRY_RUN=0
if [ "${1:-}" = "--dry-run" ]; then
	DRY_RUN=1
	shift
fi

if [ $# -ne 3 ]; then
	echo "usage: $0 [--dry-run] <boot0.fex> <boot_package.fex> <device>" >&2
	exit 2
fi

BOOT0="$1"
BOOT_PACKAGE="$2"
DEV="$3"

# Offsets in KiB, mirrored from nix/sdcard/genimage.cfg.
BOOT0_OFFSET_K=8
BOOT_PACKAGE_OFFSET_K=16400

for f in "$BOOT0" "$BOOT_PACKAGE"; do
	[ -f "$f" ] || { echo "missing file: $f" >&2; exit 1; }
done
[ -b "$DEV" ] || { echo "not a block device: $DEV" >&2; exit 1; }

run() {
	echo "+ $*"
	if [ "$DRY_RUN" -eq 0 ]; then
		"$@"
	fi
}

run dd if="$BOOT0"        of="$DEV" bs=1k seek="$BOOT0_OFFSET_K"        conv=fsync,notrunc
run dd if="$BOOT_PACKAGE" of="$DEV" bs=1k seek="$BOOT_PACKAGE_OFFSET_K" conv=fsync,notrunc
run sync

echo "done. power-cycle to boot the new bootloader."
