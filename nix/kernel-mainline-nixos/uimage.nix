# uImage (zImage + appended DTB) built from the NixOS mainline kernel package,
# for the kernel partition of the SD card image. Same load/entry address as
# nix/kernel-mainline; the vendor u-boot loads it with `bootm`.
{
  runCommand,
  buildPackages,
  kernel,
}:
runCommand "uImage-mainline-v536-${kernel.version}"
  {
    nativeBuildInputs = [ buildPackages.ubootTools ];
  }
  ''
    mkdir -p $out
    dtb=$(find ${kernel}/dtbs -name sun8i-v536-hdzero-goggle.dtb)
    cat ${kernel}/zImage "$dtb" > zImage-dtb
    mkimage -A arm -O linux -T kernel -C none \
      -a 0x40008000 -e 0x40008000 \
      -n "Linux-${kernel.version}-v536" -d zImage-dtb $out/uImage
  ''
