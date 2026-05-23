#!/usr/bin/env bash
# Build the mainline V536 kernel uImage and DTB from a local checkout.
# Run inside `nix develop .#kernel-mainline`.
#
# The DTB is not appended: u-boot loads it from the config FAT partition
# (kernel.dtb) and applies the env.cfg bootargs to it. To test a build,
# write uImage to the kernel partition (p1) and the DTB as kernel.dtb on
# the config partition (p3) of the SD card.
set -euo pipefail

# Local checkout of the v536-port branch of https://github.com/Mic92/linux
KERNEL_DIR="${KERNEL_DIR:-$HOME/git/linux-v536}"
OUT="${KBUILD_OUTPUT:-build-v536}"
DTB=dts/allwinner/sun8i-v536-hdzero-goggle.dtb

cd "$KERNEL_DIR"
export KBUILD_OUTPUT="$OUT"

if [ ! -f "$OUT/.config" ]; then
	# Board defconfig from the v536-port branch; same config the nix
	# package starts from.
	make sun8i_v536_defconfig
fi

make -j"$(nproc)" zImage dtbs

cd "$OUT/arch/arm/boot"
mkimage -A arm -O linux -T kernel -C none -a 0x40008000 -e 0x40008000 \
	-n "Linux-mainline-v536" -d zImage uImage-v536
echo "uImage: $PWD/uImage-v536"
echo "dtb:    $PWD/$DTB"
