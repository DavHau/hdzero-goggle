# Mainline V536 kernel uImage for boot testing.
# Cross-compiled for armv7l; produces uImage (zImage + appended DTB).
{
  stdenv,
  buildPackages,
  fetchFromGitHub,
}:
let
  version = "7.0.9-v536";

  # Board-focused config from the v536-port branch.
  defconfig = "sun8i_v536_defconfig";

  # Extra options on top of the defconfig (none needed currently).
  extraConfig = [ ];

  src = fetchFromGitHub {
    owner = "Mic92";
    repo = "linux";
    rev = "729bc06239d54beb3c57801090dd7c0d88a958a7";
    hash = "sha256-Og9LPA5XgxCoORsiBgAildDqdbookKq60mzUa1ZuY6o=";
  };

  dtbRelPath = "allwinner/sun8i-v536-hdzero-goggle.dtb";
in
stdenv.mkDerivation {
  pname = "kernel-mainline-v536";
  inherit version src;

  depsBuildBuild = [ buildPackages.stdenv.cc ];

  nativeBuildInputs = with buildPackages; [
    bc
    bison
    flex
    openssl
    elfutils
    ncurses
    perl
    kmod
    lzop
    xz
    ubootTools
    dtc
    python3
  ];

  postPatch = ''
    patchShebangs scripts/
  '';

  configurePhase = ''
    runHook preConfigure
    export ARCH=arm
    export CROSS_COMPILE=${stdenv.cc.targetPrefix}
    export KBUILD_BUILD_VERSION=1
    # UTS_VERSION embeds `date` unless this is set; keep the image reproducible.
    export KBUILD_BUILD_TIMESTAMP="$(date -u -d "@$SOURCE_DATE_EPOCH")"
    export KBUILD_BUILD_USER=nixbld
    export KBUILD_BUILD_HOST=nixbld
    make ${defconfig}
    ${builtins.concatStringsSep "\n" (map (opt: "scripts/config --enable ${opt}") extraConfig)}
    make olddefconfig
    runHook postConfigure
  '';

  buildPhase = ''
    runHook preBuild
    make -j$NIX_BUILD_CORES zImage dtbs
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    local boot=arch/arm/boot
    cat $boot/zImage $boot/dts/${dtbRelPath} > zImage-dtb
    mkimage -A arm -O linux -T kernel -C none \
      -a 0x40008000 -e 0x40008000 \
      -n "Linux-mainline-v536" -d zImage-dtb $out/uImage
    cp $boot/zImage $out/
    cp $boot/dts/${dtbRelPath} $out/
    runHook postInstall
  '';

  dontStrip = true;
  dontFixup = true;
}
