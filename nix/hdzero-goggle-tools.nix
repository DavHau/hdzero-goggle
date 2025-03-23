{
  stdenv,
  fetchFromGitHub,
  glibc,
}:
stdenv.mkDerivation {
  name = "hdzero-goggle-tools";
  src = fetchFromGitHub {
    owner = "bkleiner";
    repo = "hdzero-goggle-tools";
    rev = "25788515410db8c9a931ece88650c1b5a4da85b1";
    sha256 = "sha256-kCd2Ld1GuzrTwops4MoTjBwRucfEEdr/l4AOinZ3Jrs=";
  };
  postPatch = ''
    for makefile in ./**/Makefile; do
      substituteInPlace "$makefile" --replace-fail " -static" " "
    done
  '';
  buildPhase = ''
    make -j$NIX_BUILD_CORES
  '';
  installPhase = ''
    mkdir $out
    mv bin $out/bin
  '';
  postFixup = ''
    patchelf --set-interpreter ${glibc}/lib64/ld-linux-x86-64.so.2 \
      $out/bin/u_boot_env_gen
  '';
}
