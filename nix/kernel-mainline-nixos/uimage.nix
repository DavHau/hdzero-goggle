# uImage + DTB from the NixOS mainline kernel for the SD card image.
# The DTB is shipped separately on the config FAT partition; u-boot
# overwrites boot0's staged fdt at 0x7cfd1b20 with it before bootm,
# so the env.cfg bootargs reach the kernel.
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
    cp "$dtb" $out/sun8i-v536-hdzero-goggle.dtb
    mkimage -A arm -O linux -T kernel -C none \
      -a 0x40008000 -e 0x40008000 \
      -n "Linux-${kernel.version}-v536" -d ${kernel}/zImage $out/uImage
  ''
