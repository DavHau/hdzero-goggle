{
  e2fsprogs,
  fetchzip,
  lib,
  qemu,
  writeShellApplication,
  runCommand,
  dtc,
  pkgsArm,

  # from this project
  kernel,
} @ args:
let
  # kernel = pkgsArm.linux_6_12.override {
  #   defconfig = "sunxi_defconfig";
  # };
  dtbDir = runCommand "hdzero-dtb" {} ''
    mkdir $out
    ${dtc}/bin/dtc -o $out/hdzero_goggle.dtb -O dtb ${../sdcard/hdzero_goggle.dts}
  '';
in
writeShellApplication {
  name = "emulate";
  runtimeInputs = [
    qemu
    e2fsprogs
  ];
  text = ''
    trap 'chmod +w -R $tmpDir; rm -rf $tmpDir' EXIT
    tmpDir=$(mktemp -d)

    echo starting qemu
      # -dtb ${dtbDir}/hdzero_goggle.dtb
      # -dtb ${kernel}/dtbs/sun8i-h3-orangepi-pc.dtb
    qemu-system-arm -M orangepi-pc \
      -nographic \
      -nic user \
      -kernel ${kernel}/zImage \
      -append 'console=ttyS0,115200 earlycon=uart8250,mmio32,0x1c28000,115200n8' \
      -dtb ${kernel}/dtbs/sun8iw16p1-pro.dtb
  '';
}
