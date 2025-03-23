{
  # nixpkgs inputs
  cmake,
  lib,
  sdl2-compat,
  libxcrypt,
  stdenv,

  # defined by this project
  hdzero-goggle-src,
}:
let
  inherit (lib)
    readFile
    removeSuffix
    ;
in
stdenv.mkDerivation {
  pname = "hdzero-goggle-emulator";
  version = removeSuffix "\n" (readFile (hdzero-goggle-src + "/VERSION"));
  src = hdzero-goggle-src;
  dontInstall = true;
  dontFixup = true;
  nativeBuildInputs = [
    cmake
  ];
  buildInputs = [
    libxcrypt
  ];
  CMAKE_PREFIX_PATH = "${sdl2-compat.dev}/lib/cmake/SDL2/";
  buildPhase = ''
    mkdir build
    cmake . -Bbuild -DEMULATOR_BUILD=ON -DCMAKE_BUILD_TYPE=Debug
    cd build
    make -j$NIX_BUILD_CORES
    mkdir -p $out/bin
    mv ./HDZGOGGLE $out/bin/
  '';
}
