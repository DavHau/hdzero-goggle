#!/usr/bin/env bash
# Build a uImage (zImage + appended DTB) from the mainline V536 kernel tree.
# Run inside `nix develop .#kernel-mainline`.
set -euo pipefail

# Local checkout of the v536-port branch of https://github.com/Mic92/linux
KERNEL_DIR="${KERNEL_DIR:-$HOME/git/linux-v536}"
OUT="${KBUILD_OUTPUT:-build-v536}"
DTB=arch/arm/boot/dts/allwinner/sun8i-v536-hdzero-goggle.dtb

cd "$KERNEL_DIR"
export KBUILD_OUTPUT="$OUT"

if [ ! -f "$OUT/.config" ]; then
	make sunxi_defconfig
	scripts/config --file "$OUT/.config" --enable ARM_APPENDED_DTB \
		--enable MTD --enable MTD_SPI_NOR --enable SUN20I_GPADC
	make olddefconfig
fi

make -j"$(nproc)" zImage dtbs

cd "$OUT/arch/arm/boot"
cat zImage "dts/allwinner/$(basename "$DTB")" > zImage-dtb
mkimage -A arm -O linux -T kernel -C none -a 0x40008000 -e 0x40008000 \
	-n "Linux-mainline-v536" -d zImage-dtb uImage-v536
echo "uImage: $PWD/uImage-v536"
