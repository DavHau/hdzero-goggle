# Cross dev shell for building the 4.9.118 vendor kernel and modules
# directly in a local kernel checkout (incremental, no nix rebuilds).
# Must be called from the same nixpkgs/cross package set as nix/kernel,
# otherwise the 4.9 sources will not build with the newer gcc.
{
  mkShell,
  stdenv,
  buildPackages,

  # from this project
  kernel,
}:
mkShell {
  # toolchain + lzop, ubootTools, bc, bison, flex, openssl, ... as used by the
  # kernel derivation itself
  inputsFrom = [ kernel ];
  packages = [
    buildPackages.stdenv.cc # HOSTCC for scripts/, fixdep, etc.
    buildPackages.kmod
  ];
  shellHook = ''
    export ARCH=arm
    export CROSS_COMPILE=${stdenv.cc.targetPrefix}
    export KBUILD_BUILD_VERSION=1
    echo "kernel dev shell: ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE"
    echo "config: copy it once with"
    echo "  cp ${kernel.configfile} .config && make olddefconfig"
  '';
}
