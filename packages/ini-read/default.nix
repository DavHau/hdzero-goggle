{
  stdenv,

  # flake inputs
  minIni-src,
  ...
}:
stdenv.mkDerivation {
  name = "ini-read";
  src = ./.;
  CPATH = [
    "${minIni-src}/dev"
  ];
  buildPhase = ''
    $CXX $CXXFLAGS ini-read.cpp ${minIni-src}/dev/minIni.c -o ini-read
  '';
  installPhase = ''
    mkdir -p $out/bin
    cp ini-read $out/bin/
  '';
}
