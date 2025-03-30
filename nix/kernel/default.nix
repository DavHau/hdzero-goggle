{
  hdzero-goggle-linux-src,
  linuxManualConfig,
  stdenv,
  lib,
  lzop,
  ubootTools,
  breakpointHook,
}:
let
  linux = linuxManualConfig rec {
    inherit lib stdenv;
    src = hdzero-goggle-linux-src;
    version = "4.9.118";
    modDirVersion = version;
    configfile = ./hdzgoggle_defconfig;
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
  })
