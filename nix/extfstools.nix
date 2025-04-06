{
  stdenv,
  fetchFromGitHub,
  cmake,
  openssl,
  boost,
}:
let
  itslib = stdenv.mkDerivation {
    name = "itslib";
    src = fetchFromGitHub {
      owner = "nlitsme";
      repo = "legacy-itslib-library";
      rev = "49f88ee0f292f24bbc7a32d2cbdeb8821d40ad3d";
      hash = "sha256-+2Bedeu8il8p5+Dx1s8c8SGe5kS4QZmKqZV7lijySwU=";
    };
    nativeBuildInputs = [
      cmake
    ];
    buildInputs = [
      openssl
    ];
    installPhase = ''
      mkdir -p $out/lib
      mv *.a $out/lib/
      mv ../include $out/include
    '';
  };
in
stdenv.mkDerivation {
  name = "extfstools";
  src = fetchFromGitHub {
    owner = "nlitsme";
    repo = "extfstools";
    rev = "3541ca0950e095b726eae3c43b12b4b95667c56d";
    hash = "sha256-fSdEXtfWFryuUFFT/zUYYL2Ven08uVgzJEl91GbCECo=";
  };
  nativeBuildInputs = [
    cmake
  ];
  buildInputs = [
    itslib
    boost
    openssl
  ];
  postPatch = ''
    substituteInPlace cmake_find/Finditslib.cmake \
      --replace-fail \
        'add_subdirectory(''${ITSLIB_PATH})' \
        'add_subdirectory(${itslib.src} ''${CMAKE_BINARY_DIR}/itslib)'
  '';
}
