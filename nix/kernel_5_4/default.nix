{
  linuxManualConfig,
  stdenv,
  lib,
  lzop,
  ubootTools,
  xz,
  runCommand,
  flex,
  bison,
  breakpointHook,

  # flake inputs,
  kernel-5-4-src,
  ...
}:
let
  linux = linuxManualConfig rec {
    inherit lib stdenv;
    src = kernel-5-4-src;
    version = "5.4.61";
    modDirVersion = version;
    allowImportFromDerivation = true;
    configfile = runCommand "configfile" {} ''
      cat ${./hdzgoggle_defconfig} > $out

      nixos_defconfig=${./nixos_defconfig}
      # get all keys from nixos_defconfig
      nixos_keys=$(cat $nixos_defconfig | grep -v '#' | grep -oP 'CONFIG_\K[^=]+')
      # remove all lines from $out that are in $nixos_keys
      for key in $nixos_keys; do
        echo "removing $key from $out"
        sed -i "/$key/d" $out
      done
      cat ${./nixos_defconfig} >> $out
    '';
  };
in
  linux.overrideAttrs (old: {
    nativeBuildInputs = old.nativeBuildInputs or [] ++ [
      flex
      lzop
      ubootTools
      xz
      bison
      breakpointHook
    ];
    buildInputs = old.buildInputs or [] ++ [
      xz
    ];
    installTargets = old.installTargets ++ [ "uinstall" ];
    buildFlags = old.buildFlags ++ [
      "uImage"
      "LOADADDR=0x40008000"
    ];
    postPatch = ''
      substituteInPlace drivers/video/fbdev/sunxi/disp2/disp/dev_fb.c \
        --replace CONFIG_DECOMPRESS_LZMA CONFIG_FOO_BAR

      for file in drivers/crypto/sunxi-ce/sunxi_{ce,ce_cdev}.h; do
        substituteInPlace "$file" \
          --replace "#define SS_SUPPORT_CE_V3_1		1" ""
      done

    '';
  })
