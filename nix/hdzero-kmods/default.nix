{
  stdenv,

  # flake inputs
  hdzero-goggle-linux-src,

  # from this project
  hdzero-goggle-src,
  kernel,
}:

# Reimplemented vendor kernel modules from src/kmod, built out-of-tree
# against the nix built kernel.
stdenv.mkDerivation {
  pname = "hdzero-kmods";
  version = "0.0.0-dev";

  src = "${hdzero-goggle-src}/src/kmod";

  nativeBuildInputs = kernel.moduleBuildDependencies;

  makeFlags = kernel.makeFlags ++ [
    # Variable refers to the local Makefile.
    "KERNELDIR=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
    # sunxi-vin headers for the hdzero module; not part of kernel.dev
    "LINUX_SRC=${hdzero-goggle-linux-src}"
    # Variable of the Linux src tree's main Makefile.
    "INSTALL_MOD_PATH=$(out)"
  ];

  buildFlags = [ "modules" ];
  installTargets = [ "modules_install" ];
}
