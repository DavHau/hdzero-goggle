{
  e2fsprogs,
  fetchzip,
  lib,
  qemu,
  writeShellApplication,
  runCommand,

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

  configfile = runCommand "configfile" {} ''
    cat ${linuxSrc}/arch/arm/configs/sunxi_defconfig > $out

    nixos_defconfig=${../kernel/nixos_defconfig}
    # get all keys from nixos_defconfig
    nixos_keys=$(grep -oP 'CONFIG_\K[^=]+' $nixos_defconfig)
    # remove all lines from $out that are in $nixos_keys
    for key in $nixos_keys; do
      sed -i "/$key/d" $out
    done
    cat ${../kernel/nixos_defconfig} >> $out
  '';

  qemuKernel = (pkgsLinux.linuxManualConfig rec {
    inherit lib configfile;
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
  passthru = {inherit qemuKernel configfile;};
  runtimeInputs = [
    qemu
    e2fsprogs
  ];
  text = ''
    trap 'chmod +w -R $tmpDir; rm -rf $tmpDir' EXIT
    tmpDir=$(mktemp -d)
    cat ${rootfs}/rootfs.ext2 > "$tmpDir/rootfs.ext4"

    qemu-img resize "$tmpDir/rootfs.ext4" 2G

      # -sd "$tmpDir/rootfs.ext4" \
    qemu-system-arm -M orangepi-pc \
      -nographic \
      -nic user \
      -kernel ${qemuKernel}/zImage \
      -append 'console=ttyS0,115200 root=/dev/mmcblk0 init=/init rootwait earlyprintk loglevel=8 earlycon=uart8250,mmio32,0x1c28000,115200n8' \
      -dtb ${kernel}/dtbs/sun8i-h3-orangepi-pc.dtb \
      -drive if=sd,driver=file,filename="$tmpDir/rootfs.ext4"

  '';
}
