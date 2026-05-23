# uImage + DTB from the NixOS mainline kernel for the SD card image.
# The DTB is shipped separately on the config FAT partition; u-boot
# overwrites boot0's staged fdt at 0x7cfd1b20 with it before bootm,
# so the env.cfg bootargs reach the kernel.
{
  runCommand,
  buildPackages,
  kernel,
  dtc,
}:
runCommand "uImage-mainline-v536-${kernel.version}"
  {
    nativeBuildInputs = [
      buildPackages.ubootTools
      dtc
    ];
  }
  ''
    mkdir -p $out
    dtb=$(find ${kernel}/dtbs -name sun8i-v536-hdzero-goggle.dtb)

    # Compile and apply the XR819 wifi overlay (mmc1 + pwrseq)
    dtc -@ -I dts -O dtb -o xr819-wifi.dtbo ${./xr819-wifi.dtso}
    fdtoverlay -i "$dtb" -o $out/sun8i-v536-hdzero-goggle.dtb xr819-wifi.dtbo

    mkimage -A arm -O linux -T kernel -C none \
      -a 0x40008000 -e 0x40008000 \
      -n "Linux-${kernel.version}-v536" -d ${kernel}/zImage $out/uImage
  ''
