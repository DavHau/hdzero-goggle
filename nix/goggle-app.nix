{
  # nixpkgs inputs
  cmake,
  lib,
  mtdutils,
  stdenv,
  e2fsprogs,

  # defined by this project
  hdzero-goggle-src,
  toolchain,
}:
let
  inherit (lib)
    readFile
    removeSuffix
    ;
  version = removeSuffix "\n" (readFile (hdzero-goggle-src + "/VERSION"));
in
stdenv.mkDerivation {
  pname = "hdzero-goggle";
  version = version;
  src = hdzero-goggle-src;
  postPatch = ''
    substituteInPlace ./mkapp/mkapp_ota.sh \
      --replace-fail "APP_VERSION=\$(get_app_version)" "APP_VERSION=${version}"
    patchShebangs ./mkapp/mkapp_ota.sh
  '';
  dontConfigure = true;
  dontInstall = true;
  dontFixup = true;
  nativeBuildInputs = [
    cmake
    mtdutils
    e2fsprogs
  ];
  buildPhase = ''
    mkdir build
    cmake . -DCMAKE_BUILD_TYPE=Release -DCMAKE_TOOLCHAIN_FILE=${toolchain}/share/buildroot/toolchainfile.cmake -Bbuild

    cd build
    make all -j$NIX_BUILD_CORES
    cd ..

    # Disable the services installation hack that upstream uses
    # (it breaks the sd card on first boot)
    echo -e "#!/bin/sh\ntrue" > mkapp/app/services/install.sh
    echo -e "#!/bin/sh\ntrue" > mkapp/app/services/startup.sh

    mkfs.ext4 -d ./mkapp/app app.ext2 "100M"
    mv ./out $out
    mv app.ext2 $out/
    mv mkapp/app $out/app
    fsck.ext4 -y $out/app.ext2
  '';
}
