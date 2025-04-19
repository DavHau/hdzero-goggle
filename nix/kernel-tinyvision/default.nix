{
  linuxManualConfig,
  stdenv,
  lib,
  lzop,
  ubootTools,
  runCommand,

  # flake inputs
  tinyvision-src,

  # customization
}:
let
  configfile = runCommand "configfile" {} ''
    cat ${../kernel/hdzgoggle_defconfig} > $out

    nixos_defconfig=${../kernel/nixos_defconfig}
    # get all keys from nixos_defconfig
    nixos_keys=$(cat $nixos_defconfig | grep -v '#' | grep -oP 'CONFIG_\K[^=]+')
    # remove all lines from $out that are in $nixos_keys
    for key in $nixos_keys; do
      echo "removing $key from $out"
      sed -i "/$key/d" $out
    done
    cat ${../kernel/nixos_defconfig} >> $out
  '';
  linux = linuxManualConfig rec {
    inherit configfile lib stdenv;
    src = "${tinyvision-src}/kernel/linux-4.9";
    version = "4.9.191";
    modDirVersion = version;
    allowImportFromDerivation = true;
  };
in
  linux.overrideAttrs (old: {
    nativeBuildInputs = old.nativeBuildInputs or [] ++ [
      lzop
      ubootTools
    ];
    installTargets = old.installTargets ++ [ "uinstall" ];
    buildFlags = old.buildFlags ++ [
      "uImage"
    ];
    postPatch = ''
      substituteInPlace arch/arm/boot/dts/Makefile \
        --replace \
          'sun8iw16p1-soc.dtb' \
          'sun8iw16p1-soc.dtb sun8i-h3-orangepi-pc.dtb'

      substituteInPlace drivers/video/fbdev/sunxi/disp2/disp/dev_fb.c \
        --replace CONFIG_DECOMPRESS_LZMA CONFIG_FOO_BAR
    '';
  })
