{
  mkShell,
  cmake,
  libxcrypt,
  sdl2-compat,
  mtdutils,
}:
mkShell {
  packages = [
    cmake
    libxcrypt
    sdl2-compat.dev
    mtdutils
  ];
}
