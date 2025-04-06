{
  hdzero-goggle-linux-src,
  linuxManualConfig,
  stdenv,
  lib,
  lzop,
  ubootTools,
  breakpointHook,

  configfile ? ./hdzgoggle_defconfig,
}:
let
  linux = linuxManualConfig rec {
    inherit configfile lib stdenv;
    src = hdzero-goggle-linux-src;
    version = "4.9.118";
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
      "dtbs" "DTC_FLAGS=-@"
    ];
    installFlags = old.installFlags ++ [
      "dtbs_install"
      "INSTALL_DTBS_PATH=$(out)/dtbs"
    ];
    postPatch = ''
      substituteInPlace arch/arm/boot/dts/Makefile \
        --replace \
          'sun8iw16p1-soc.dtb' \
          'sun8iw16p1-soc.dtb sun8i-h3-orangepi-pc.dtb'
    '';
  })
