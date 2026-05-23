# Mainline V536 kernel uImage for boot testing.
# Cross-compiled for armv7l; produces uImage (zImage + appended DTB).
{
  stdenv,
  buildPackages,
  fetchFromGitHub,
}:
let
  version = "7.0.9-v536";

  # Change this to "sun8i_v536_defconfig" once the dedicated defconfig
  # lands on the v536-port branch.
  defconfig = "sunxi_defconfig";

  # Extra options on top of defconfig (only needed while using
  # sunxi_defconfig; drop when switching to sun8i_v536_defconfig).
  extraConfig = [
    "ARM_APPENDED_DTB"
    "MTD"
    "MTD_SPI_NOR"
    "SUN20I_GPADC"
  ];

  src = fetchFromGitHub {
    owner = "Mic92";
    repo = "linux";
    rev = "a06268b5f072b72fc33cac4592ff02b9c831a9db";
    hash = "sha256-LMes3luo/yha2+ssQ4NV0lnZDzFxtU5aqnxCF2T2bzc=";
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
    make ${defconfig}
    ${builtins.concatStringsSep "\n" (
      map (opt: "scripts/config --enable ${opt}") extraConfig
    )}
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
