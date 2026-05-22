# Cross dev shell for building a mainline kernel for the V536 port in a
# local checkout (e.g. ~/git/linux-v536): `nix develop .#kernel-mainline`
{
  mkShell,
  stdenv,
  buildPackages,
}:
mkShell {
  packages = [
    buildPackages.stdenv.cc # HOSTCC
  ]
  ++ (with buildPackages; [
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
  ]);
  shellHook = ''
    export ARCH=arm
    export CROSS_COMPILE=${stdenv.cc.targetPrefix}
    export KBUILD_BUILD_VERSION=1
    echo "mainline kernel dev shell: ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE"
  '';
}
