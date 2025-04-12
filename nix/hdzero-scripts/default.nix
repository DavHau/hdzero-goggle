{
  lib,
  stdenv,
}:
stdenv.mkDerivation {
  name = "hdzero-scripts";
  src = lib.cleanSource ./bin;
  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;
  installPhase = ''
    mkdir -p $out/bin
    cp -r $src/* $out/bin/
  '';
}
