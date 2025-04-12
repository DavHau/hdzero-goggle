{
  hdzero-goggle-linux-src,
  linuxManualConfig,
  stdenv,
  lib,
  lzop,
  ubootTools,
  breakpointHook,
  xz,
  runCommand,
  ...
}:
let
  linux = linuxManualConfig rec {
    inherit lib stdenv;
    src = hdzero-goggle-linux-src;
    version = "4.9.118";
    modDirVersion = version;
    allowImportFromDerivation = true;
    configfile = runCommand "configfile" {} ''
      cat ${./hdzgoggle_defconfig} > $out

      nixos_defconfig=${../kernel/nixos_defconfig}
      # get all keys from nixos_defconfig
      nixos_keys=$(grep -oP 'CONFIG_\K[^=]+' $nixos_defconfig)
      # remove all lines from $out that are in $nixos_keys
      for key in $nixos_keys; do
        sed -i "/$key/d" $out
      done
      cat ${./nixos_defconfig} >> $out
    '';
  };
in
  linux.overrideAttrs (old: {
    nativeBuildInputs = old.nativeBuildInputs or [] ++ [
      lzop
      ubootTools
      xz
      breakpointHook
    ];
    buildInputs = old.buildInputs or [] ++ [
      xz
    ];
    installTargets = old.installTargets ++ [ "uinstall" ];
    buildFlags = old.buildFlags ++ [
      "uImage"
    ];
    # makeFlags = old.makeFlags ++ [
    #   ''SHELL=${buildPackages.writeShellScript "bash" ''
    #     bash -x "$@"
    #   ''}''
    # ];
    postPatch = ''
      substituteInPlace arch/arm/boot/dts/Makefile \
        --replace \
          'sun8iw16p1-soc.dtb' \
          'sun8iw16p1-soc.dtb sun8i-h3-orangepi-pc.dtb'

      substituteInPlace drivers/video/fbdev/sunxi/disp2/disp/dev_fb.c \
        --replace CONFIG_DECOMPRESS_LZMA CONFIG_FOO_BAR
    '';
    # preBuild = "exit 1";
  })
