{
  bc,
  cacert,
  coreutils,
  cpio,
  e2fsprogs,
  file,
  flock,
  git,
  glibc,
  lib,
  libgcc,
  libxcrypt,
  mtdutils,
  perl,
  rsync,
  runCommand,
  stdenv,
  unzip,
  util-linux,
  wget,
  which,

  # from this project
  hdzero-goggle-src,
  hdzero-goggle-buildroot,
  hdzero-goggle-linux-src,
  toolchain,
}:
let
  inherit (lib)
    substring
    ;
  inherit (builtins) hashString;
  hdzero-goggle-linux-tarball = runCommand "hdzero-goggle-linux-tarball" {} ''
    mkdir -p $out
    tar -czf $out/hdzero-goggle-linux.tar.gz -C ${hdzero-goggle-linux-src} .
  '';
  buildrootOverrideFile = builtins.toFile "buildroot-config-override" ''
    LINUX_OVERRIDE_SRCDIR = ${hdzero-goggle-linux-src}
    LINUX_HEADERS_OVERRIDE_SRCDIR = ${hdzero-goggle-linux-src}
    HDZGOGGLE_OVERRIDE_SRCDIR = ${hdzero-goggle-src}
  '';
  os-buildroot-dl = stdenv.mkDerivation rec {
    name = let
      # append hash of buildroot to name in order to invalidate the cache if the buildroot changes
      inputHash = substring 0 10 (hashString "sha256" "${src}");
    in "os-buildroot-dl-${inputHash}";
    src = hdzero-goggle-buildroot;
    dontConfigure = true;
    dontInstall = true;
    outputHashMode = "recursive";
    outputHashAlgo = "sha256";
    outputHash = "sha256-cpg8KAuVUzS5br4DYH3VM9BK8PZ4oASSFNzsSTnH+1U=";
    nativeBuildInputs = [
      which
      perl
      wget
      cpio
      unzip
      rsync
      bc
      git
      flock
      cacert
      file
    ];
    hdzeroGoggleSrc = hdzero-goggle-src;
    postPatch = ''
      patchShebangs ./buildroot/support/{scripts,download}
      substituteInPlace ./buildroot/support/dependencies/dependencies.sh \
        --replace-fail "/usr/bin/file" "$(which file)"
      substituteInPlace ./package/hdzgoggle/hdzgoggle.mk \
        --replace-fail \
          'HDZGOGGLE_SITE = $(call github,bkleiner,hdzero-goggle,$(HDZGOGGLE_VERSION))' \
          "HDZGOGGLE_SITE = ${hdzero-goggle-src}${"\n"}HDZGOGGLE_SITE_METHOD = local"
      for defconfig in ./configs/hdzgoggle_{flash,sdcard}_defconfig; do
        substituteInPlace "$defconfig" \
          --replace-fail \
            'BR2_LINUX_KERNEL_CUSTOM_REPO_URL="https://github.com/bkleiner/hdzero-goggle-linux.git"' \
            'BR2_LINUX_KERNEL_CUSTOM_TARBALL_LOCATION="file://${hdzero-goggle-linux-tarball}/hdzero-goggle-linux.tar.gz"' \
          --replace-fail 'BR2_LINUX_KERNEL_CUSTOM_GIT=y' 'BR2_LINUX_KERNEL_CUSTOM_TARBALL=y' \
          --replace-fail BR2_LINUX_KERNEL_CUSTOM_REPO_VERSION= "" \
          --replace-fail BR2_PACKAGE_OPENSSH=y "" \
          --replace-fail BR2_PACKAGE_BASH=y "" \
          --replace-fail BR2_PACKAGE_GDB_SERVER=y "" \
          --replace-fail BR2_TOOLCHAIN_EXTERNAL_DOWNLOAD=y BR2_TOOLCHAIN_EXTERNAL_PREINSTALLED=y \
          --replace-fail \
            'BR2_TOOLCHAIN_EXTERNAL_URL="https://toolchains.bootlin.com/downloads/releases/toolchains/armv7-eabihf/tarballs/armv7-eabihf--musl--stable-2018.02-2.tar.bz2"' \
            'BR2_TOOLCHAIN_EXTERNAL_PATH="${toolchain}"'

        echo 'BR2_PACKAGE_OVERRIDE_FILE="${buildrootOverrideFile}"' >> "$defconfig"
      done
    '';
    buildPhase = ''
      echo "preparing dowload for flash image"
      make O=$PWD/output BR2_DL_DIR=$PWD/dl BR2_EXTERNAL=$PWD -C buildroot hdzgoggle_flash_defconfig
      make O=$PWD/output BR2_DL_DIR=$PWD/dl BR2_EXTERNAL=$PWD -C buildroot source -j8
      echo "preparing dowload for sdcard image"
      make O=$PWD/output BR2_DL_DIR=$PWD/dl BR2_EXTERNAL=$PWD -C buildroot hdzgoggle_sdcard_defconfig
      make O=$PWD/output BR2_DL_DIR=$PWD/dl BR2_EXTERNAL=$PWD -C buildroot source -j8
      mkdir $out
      rm -r dl/linux
      cp -r dl $out/dl
    '';
  };
in
stdenv.mkDerivation {
  name = "hdzero-goggle-os-images";
  src = "${hdzero-goggle-buildroot}";
  dontConfigure = true;
  dontInstall = true;
  dontFixup = true;
  nativeBuildInputs = os-buildroot-dl.nativeBuildInputs ++ [
    mtdutils
    e2fsprogs
    util-linux
  ];
  buildInputs = [
    libxcrypt
    libgcc.lib
  ];
  postPatch = os-buildroot-dl.postPatch + ''
    for file in $(find ./buildroot/package/ -type f); do
      sed -i "s|/bin/true|${coreutils}/bin/true|g" $file
    done
    # patch shebangs of custom build hooks
    patchShebangs ./board/*/*.sh
    # openssh is disabled by postPatch above, remove the setup
    substituteInPlace board/hdzgoggle_common/post-build.sh \
      --replace-fail 'ensure_line "PermitRootLogin yes" "$TARGET_DIR/etc/ssh/sshd_config"' ""
  '';
  # quite hacky, but it works. calling make multiple times and patching stuff in between
  buildPhase = ''
    # populate the dl directory which was built separately
    cp -r ${os-buildroot-dl}/dl ./dl
    chmod +w -R ./dl

    # configure buildroot for the flash image
    make O=$PWD/output BR2_DL_DIR=$PWD/dl BR2_EXTERNAL=$PWD -C buildroot hdzgoggle_flash_defconfig

    # build all target until stuff fails -> then patch some stuff -> then re-run make
    make O=$PWD/output BR2_DL_DIR=$PWD/dl BR2_EXTERNAL=$PWD -C buildroot -j$NIX_BUILD_CORES --keep-going || true

    # patch shebangs
    patchShebangs ./output/build/host-*
    for makefile in ./output/build/host-hdzero-tools-*/**/Makefile; do
      substituteInPlace "$makefile" --replace-quiet " -static" " "
    done
    # patch mkapp_ota.sh to include version and fix paths
    substituteInPlace ./output/build/hdzgoggle-main/mkapp/mkapp_ota.sh \
      --replace-fail "APP_VERSION=\$(get_app_version)" "APP_VERSION=\$(cat ${hdzero-goggle-src + "/VERSION"})"
    patchShebangs ./output/build/hdzgoggle-main/mkapp/mkapp_ota.sh
    # fix bug in script.c
    substituteInPlace ./output/build/host-hdzero-tools-*/script/script.c \
      --replace-fail 'dest[src_length - 0] = NULL;' "dest[src_length - 1] = '\\0';"
    # fix missing includes in hdzero-tools
    sed -i '1i #include <stdlib.h>' ./output/build/host-hdzero-tools-*/create_mbr/update_mbr.c
    sed -i '1i #include <stdlib.h>' ./output/build/host-hdzero-tools-*/parser_mbr/parser_mbr.c

    # re-run build with patches/fixes from above
    make O=$PWD/output BR2_DL_DIR=$PWD/dl BR2_EXTERNAL=$PWD -C buildroot -j$NIX_BUILD_CORES --keep-going || true
    # chown $(whoami) -R output/build/openssh*
    # fix interpreter of helper program
    patchelf --set-interpreter ${glibc}/lib64/ld-linux-x86-64.so.2 ./output/host/bin/hdz-u_boot_env_gen

    # continue build
    make O=$PWD/output BR2_DL_DIR=$PWD/dl BR2_EXTERNAL=$PWD -C buildroot -j$NIX_BUILD_CORES

    # configure buildroot for the sdcard image and build it
    make O=$PWD/output BR2_DL_DIR=$PWD/dl BR2_EXTERNAL=$PWD -C buildroot hdzgoggle_sdcard_defconfig
    make O=$PWD/output BR2_DL_DIR=$PWD/dl BR2_EXTERNAL=$PWD -C buildroot -j$NIX_BUILD_CORES

    mv output $out
  '';
}
