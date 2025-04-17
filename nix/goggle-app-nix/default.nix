{
  # nixpkgs inputs
  cmake,
  lib,
  mtdutils,
  stdenv,
  e2fsprogs,
  glibc,
  autoPatchelfHook,
  breakpointHook,
  pkgsBuildBuild,
  libgcc,
  alsa-lib,
  vim,
  ripgrep,
  libxcrypt,
  which,
  live555,
  ffmpeg,
  zlib,
  ncurses5,
  fetchFromGitHub,

  # flake inputs
  nix-filter,
  minIni-src,

  # defined by this project
  hdzero-goggle-src,
  lvgl-src,
}:
let
  inherit (lib)
    readFile
    removeSuffix
    ;
  version = removeSuffix "\n" (readFile (hdzero-goggle-src + "/VERSION"));
  softwinnerIncludes = [
    # copied from CMakeLists.txt
    "lib/softwinner/include/system/public/include"
    "lib/softwinner/include/system/public/include/vo"
    "lib/softwinner/include/system/public/include/utils"
    "lib/softwinner/include/middleware/sample/configfileparser"
    "lib/softwinner/include/middleware/media/LIBRARY/libcedarx/libcore/common/iniparser"
    "lib/softwinner/include/middleware/include"
    "lib/softwinner/include/middleware/include/utils"
    "lib/softwinner/include/middleware/include/media"
    "lib/softwinner/include/middleware/media/include/utils"
    "lib/softwinner/include/middleware/media/include/component"
    "lib/softwinner/include/middleware/media/LIBRARY/libcedarc/include"
    "lib/softwinner/include/middleware/media/LIBRARY/libisp/include"
    "lib/softwinner/include/middleware/media/LIBRARY/libisp/isp_tuning"

    # added manually
    "lib/softwinner/include/middleware/media/LIBRARY/libisp"
  ];
  softwinnerLibs = stdenv.mkDerivation {
    name = "hdzero-app-libs-patched";
    src = nix-filter.lib {
      root = hdzero-goggle-src;
      include = softwinnerIncludes ++ [
        "lib/softwinner/lib/libmedia_mpp.so"
        "lib/softwinner/lib/libmpp_vi.so"
        "lib/softwinner/lib/libmpp_isp.so"
        "lib/softwinner/lib/libmpp_vo.so"
        "lib/softwinner/lib/libISP.so"
        "lib/softwinner/lib/libcedarxrender.so"
        "lib/softwinner/lib/libion.so"
        "lib/softwinner/lib/liblog.so"
        "lib/softwinner/lib/libmedia_utils.so"
        "lib/softwinner/lib/libcedarxstream.so"
        "lib/softwinner/lib/libMemAdapter.so"
        "lib/softwinner/lib/libcdx_common.so"
        "lib/softwinner/lib/libadecoder.so"
        "lib/softwinner/lib/libhwdisplay.so"
        "lib/softwinner/lib/libcutils.so"
        "lib/softwinner/lib/libcedarx_aencoder.so"
        "lib/softwinner/lib/libmpp_component.so"
        "lib/softwinner/lib/libcedarx_tencoder.so"
        "lib/softwinner/lib/libvencoder.so"
        "lib/softwinner/lib/libvenc_base.so"
        "lib/softwinner/lib/libvenc_codec.so"
        "lib/softwinner/lib/libvdecoder.so"
        "lib/softwinner/lib/libcdx_parser.so"
        "lib/softwinner/lib/libcdx_stream.so"
        "lib/softwinner/lib/libmpp_ise.so"
        "lib/softwinner/lib/libisp_ini.so"
        "lib/softwinner/lib/libVE.so"
        "lib/softwinner/lib/libglog.so.0"
        "lib/softwinner/lib/libcdx_base.so"
        "lib/softwinner/lib/lib_ise_mo.so"
        "lib/softwinner/lib/libcdc_base.so"
        "lib/softwinner/lib/libvideoengine.so"
        "lib/softwinner/lib/libawmjpegplus.so"
      ];
    };
    # libc.so raises issues during runtime, therefore link against libc.so.6
    patchelfFlags = [
      "--replace-needed libc.so libc.so.6"
    ];
    dontBuild = true;
    buildInputs = [
      libgcc
      stdenv.cc.cc.lib
      zlib
      alsa-lib
    ];
    nativeBuildInputs = [
      autoPatchelfHook
      breakpointHook
    ];
    installPhase = ''
      mkdir -p $out/lib
      cp -r lib/softwinner/lib/* $out/lib/
      mkdir -p $out/include
      for include in ${toString softwinnerIncludes}; do
        cp -r $include/* $out/include/
      done

      substituteInPlace $out/include/isp_comm.h \
        --replace-fail "../isp_version.h" "isp_version.h"
    '';
  };
in
stdenv.mkDerivation {
  pname = "hdzero-goggle";
  version = version;
  src = nix-filter.lib {
    root = hdzero-goggle-src;
    include = [
      "mkapp"
      "src"
      "CMakeLists.txt"
      "lib/esp-loader"
      "lib/linux"
      "lib/log"
      "lib/lvgl/CMakeLists.txt"
      "lib/lvgl/lv_conf.h"
      "lib/minIni/CMakeLists.txt"
    ];
  };
  passthru = {patchedLibs = softwinnerLibs;};
  nativeBuildInputs = [
    cmake
    mtdutils
    e2fsprogs
    autoPatchelfHook
    breakpointHook
    vim
    ripgrep
    which
  ];
  buildInputs = [
    stdenv.cc.cc.lib
    softwinnerLibs
    alsa-lib
    libxcrypt
    live555
    ffmpeg
    zlib
    ncurses5
  ];
  hardeningDisable = [
    "format"
    "stackprotector"
    "fortify"
    "fortify3"
    "fortify3"
    # "pic"
    "strictoverflow"
    "bindnow"
    "zerocallusedregs"
    "stackclashprotection"
  ];
  cmakeFlags = [
    "-DCMAKE_BUILD_TYPE=Release"
  ];
  # libc.so raises issues during runtime, therefore link against libc.so.6
  patchelfFlags = [
    "--replace-needed libc.so libc.so.6"
  ];
  postPatch = ''
    substituteInPlace ./mkapp/mkapp_ota.sh \
      --replace-fail "APP_VERSION=\$(get_app_version)" "APP_VERSION=${version}"
    patchShebangs ./mkapp/mkapp_ota.sh
    cp ${./CMakeLists-nix.txt} ./CMakeLists.txt

    # Disable the services installation hack that upstream uses
    # (it breaks the sd card on first boot)
    echo -e "#!/bin/sh\ntrue" > mkapp/app/services/install.sh
    echo -e "#!/bin/sh\ntrue" > mkapp/app/services/startup.sh

    substituteInPlace src/ui/page_common.h \
      --replace-fail \
        '#define WIFI_OFF      "/mnt/app/script/wlan_stop.sh"' \
        '#define WIFI_OFF      "true"' \
      --replace-fail \
        '#define WIFI_AP_ON    "/tmp/wlan_start_ap.sh"' \
        '#define WIFI_AP_ON    "true"' \
      --replace-fail \
        '#define WIFI_STA_ON   "/tmp/wlan_start_sta.sh"' \
        '#define WIFI_STA_ON   "true"' \
      --replace-fail \
        '#define SETTING_INI "/mnt/app/setting.ini"' \
        '#define SETTING_INI "/mnt/config/setting.ini"'

    cp -r ${lvgl-src} lib/lvgl/lvgl
    cp -r ${minIni-src}/dev lib/minIni/src
    chmod +w -R lib/{lvgl,minIni}
    rm lib/minIni/src/test*

    patch -d lib/lvgl/lvgl -p1 -i ${./0001-divimath-lvgl-changes.patch}
  '';
  preBuild =
    let
      ldflags = [
        # for the live555 libs
        "-lBasicUsageEnvironment"
        "-lgroupsock"
        "-lliveMedia"
        "-lUsageEnvironment"
        # for prebuilt ffmpeg
        "-lavcodec"
        "-lavformat"
        "-lavutil"
        # for prebuilt softwinner
        "-lmedia_mpp"
        "-lmpp_vi"
        "-lmpp_isp"
        "-lmpp_vo"
        # "-lz"
        # "-lc"
      ];
    in
    ''
      export CPATH="${live555}/include"
      for include in ${live555}/include/*; do
        export CPATH="$CPATH:$include"
      done
      # export NIX_CFLAGS_COMPILE="$NIX_CFLAGS_COMPILE -Wno-unused-result -fsanitize=address"
      export NIX_CFLAGS_COMPILE="$NIX_CFLAGS_COMPILE -Wno-unused-result"
      export NIX_LDFLAGS="$NIX_LDFLAGS ${toString ldflags}"
      export PATH="$PATH:${pkgsBuildBuild.binutils}/bin"
    '';
  postBuild = ''
    interpreter=$(echo ${glibc.out}/lib/ld-linux-*.so.*)
    echo "patching interpreter to $interpreter"
    patchelf --set-interpreter "$interpreter" ./HDZGOGGLE
  '';
  installPhase = ''
    mkdir -p $out/bin
    mv HDZGOGGLE record rtspLive $out/bin
    mv ../mkapp/app $out/
  '';
  # build the app.ext2 after binaries have been fixed
  postFixup = ''
    # build app.ext2
    mkfs.ext4 -d $out/app app.ext2 "100M"
    mv app.ext2 $out/
    fsck.ext4 -y $out/app.ext2
    cp $out/bin/HDZGOGGLE $out/app/app/HDZGOGGLE
  '';
}
