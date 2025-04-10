{
  linuxManualConfig,
  stdenv,
  lib,
  lzop,
  ubootTools,
  breakpointHook,

  # flake inputs
  tinyvision-src,

  # customization
  configfile ? ../kernel/hdzgoggle_defconfig,
}:
let
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
      breakpointHook
    ];
    installTargets = old.installTargets ++ [ "uinstall" ];
    buildFlags = old.buildFlags ++ [
      "uImage"
    ];
  })
