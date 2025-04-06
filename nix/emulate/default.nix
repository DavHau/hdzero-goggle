{
  e2fsprogs,
  fetchzip,
  lib,
  qemu,
  writeShellApplication,

  # from this project
  kernel,
  pkgsLinux,
  rootfs,
}:
let
  linuxVer = "4.9.118";

  linuxSrc = fetchzip {
    url = "mirror://kernel/linux/kernel/v4.x/linux-${linuxVer}.tar.xz";
    hash = "sha256-uBuCZJBGfv+uwDl7fenIrFMwRzQzqFIjIExH3cvP90g=";
  };

  qemuKernel = (pkgsLinux.linuxManualConfig rec {
    inherit lib;
    configfile = "${linuxSrc}/arch/arm/configs/sunxi_defconfig";
    stdenv = pkgsLinux.stdenv;
    src = linuxSrc;
    version = linuxVer;
    modDirVersion = version;
    allowImportFromDerivation = true;
  }).overrideAttrs (old: {
    preBuild = ''
      cat .config
      export NIX_CFLAGS_COMPILE="$NIX_CFLAGS_COMPILE -Wno-missing-attributes"
    '';
    postInstall = ''
      cp $buildRoot/.config $out/.config
    '';
  });
in
writeShellApplication {
  name = "emulate";
  passthru = {inherit qemuKernel;};
  runtimeInputs = [
    qemu
    e2fsprogs
  ];
  text = ''
    trap 'chmod +w -R $tmpDir; rm -rf $tmpDir' EXIT
    tmpDir=$(mktemp -d)
    cat ${rootfs}/rootfs.ext2 > "$tmpDir/rootfs.ext4"

    fsck -y "$tmpDir/rootfs.ext4"

      # -sd "$tmpDir/rootfs.ext4" \
    qemu-system-arm -M orangepi-pc \
      -nographic \
      -nic user \
      -kernel ${qemuKernel}/zImage \
      -append 'console=ttyS0,115200 root=/dev/mmcblk0 rootwait earlyprintk loglevel=8 earlycon=uart8250,mmio32,0x1c28000,115200n8' \
      -dtb ${kernel}/dtbs/sun8i-h3-orangepi-pc.dtb \
      -drive if=sd,driver=file,filename="$tmpDir/rootfs.ext4"
      # -sd "/tmpflakep/unpack/OrangePi_pc_debian_stretch_server_linux3.4.113_v1.0.img"

  '';
}
