{
  stdenv,
  fetchFromGitHub,

  # from this project
  kernel,
}:


stdenv.mkDerivation {
  pname = "sunxi-linux-drivers";
  version = "0.0.0-dev";

  src = fetchFromGitHub {
    owner = "fifteenhex";
    repo = "xradio";
    rev = "180aafb14191c78c1529d5a28ca58c7c9dcf2c55";
    hash = "sha256-PoNshmcp/lI3RGCoEvqTBYajlcx9lKA/I2GFWD+Rn7w=";
  };

  nativeBuildInputs = kernel.moduleBuildDependencies;

  makeFlags = kernel.makeFlags ++ [
    # Variable refers to the local Makefile.
    "KERNELDIR=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
    # Variable of the Linux src tree's main Makefile.
    "INSTALL_MOD_PATH=$(out)"
  ];

  buildFlags = [ "modules" ];
  installTargets = [ "modules_install" ];
}
