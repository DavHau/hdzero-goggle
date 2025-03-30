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
  e2tools,

  # flake input
  nix-filter,

  # from this project
  hdzero-goggle-buildroot,
  hdzero-goggle-linux-src,
  toolchain,
  kernel,

  # debug
  breakpointHook,
  vim,
  ripgrep,
}:
let
  inherit (lib)
    substring
    ;
  inherit (builtins) hashString;
  src = nix-filter.lib {
    root = ../../.;
    exclude = [ "app" "nix" "flake.nix" "flake.lock" ];
  };
  libDir = nix-filter.lib {
    root = ../../lib;
  };
  hdzero-goggle-linux-tarball = runCommand "hdzero-goggle-linux-tarball" {} ''
    mkdir -p $out
    tar -czf $out/hdzero-goggle-linux.tar.gz -C ${hdzero-goggle-linux-src} .
  '';
  buildrootOverrideFile = builtins.toFile "buildroot-config-override" ''
    LINUX_OVERRIDE_SRCDIR = ${hdzero-goggle-linux-src}
    LINUX_HEADERS_OVERRIDE_SRCDIR = ${hdzero-goggle-linux-src}
    HDZGOGGLE_OVERRIDE_SRCDIR = ${src}
    KERNEL_HEADERS_OVERRIDE_SRCDIR = ${hdzero-goggle-linux-src}
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
    postPatch = ''
      patchShebangs ./buildroot/support/{scripts,download}
      substituteInPlace ./buildroot/support/dependencies/dependencies.sh \
        --replace-fail "/usr/bin/file" "$(which file)"
      substituteInPlace ./package/hdzgoggle/hdzgoggle.mk \
        --replace-fail \
          'HDZGOGGLE_SITE = $(call github,bkleiner,hdzero-goggle,$(HDZGOGGLE_VERSION))' \
          "HDZGOGGLE_SITE = ${src}${"\n"}HDZGOGGLE_SITE_METHOD = local"
      for defconfig in ./configs/hdzgoggle_*_defconfig; do
        substituteInPlace "$defconfig" \
          --replace-fail BR2_LINUX_KERNEL=y BR2_LINUX_KERNEL=n \
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
  baseFs =
    stdenv.mkDerivation {
      name = "hdzero-rootfs-base";
      src = "${hdzero-goggle-buildroot}";
      dontConfigure = true;
      dontInstall = true;
      dontFixup = true;
      nativeBuildInputs = os-buildroot-dl.nativeBuildInputs ++ [
        mtdutils
        e2fsprogs
        util-linux
        breakpointHook
        vim
        ripgrep
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
        cp ${./hdzgoggle_rootfs_defconfig} ./configs/hdzgoggle_rootfs_defconfig
        substituteInPlace ./configs/hdzgoggle_rootfs_defconfig \
          --replace-fail BR2_TOOLCHAIN_EXTERNAL_DOWNLOAD=y BR2_TOOLCHAIN_EXTERNAL_PREINSTALLED=y \
          --replace-fail \
            'BR2_TOOLCHAIN_EXTERNAL_URL="https://toolchains.bootlin.com/downloads/releases/toolchains/armv7-eabihf/tarballs/armv7-eabihf--musl--stable-2018.02-2.tar.bz2"' \
            'BR2_TOOLCHAIN_EXTERNAL_PATH="${toolchain}"' \
          --replace-fail BR2_KERNEL_HEADERS_CUSTOM_TARBALL_LOCATION= BR2_KERNEL_HEADERS_CUSTOM_TARBALL_LOCATION=${hdzero-goggle-linux-src}
        # cat Config.in | head -n1 > Config.in.new
        # mv Config.in.new Config.in
        echo "" > Config.in
        rm -r ./package/hdzero-tools
      '';
      # NIX_CFLAGS_COMPILE = [
      #   "-Wno/-implicit-function-declaration"
      # ];
      # quite hacky, but it works. calling make multiple times and patching stuff in between
      buildPhase = ''
        # populate the dl directory which was built separately
        cp -r ${os-buildroot-dl}/dl ./dl
        chmod +w -R ./dl

        # configure buildroot for the flash image
        make O=$PWD/output BR2_DL_DIR=$PWD/dl BR2_EXTERNAL=$PWD -C buildroot hdzgoggle_rootfs_defconfig
        make O=$PWD/output BR2_DL_DIR=$PWD/dl BR2_EXTERNAL=$PWD -C buildroot source

        # build all target until stuff fails -> then patch some stuff -> then re-run make
        make O=$PWD/output BR2_DL_DIR=$PWD/dl BR2_EXTERNAL=$PWD -C buildroot -j$NIX_BUILD_CORES --keep-going || true

        # patch shebangs
        patchShebangs ./output/build/host-*
        # patch mkapp_ota.sh to include version and fix paths
        # substituteInPlace ./output/build/hdzgoggle-main/mkapp/mkapp_ota.sh \
        #   --replace-fail "APP_VERSION=\$(get_app_version)" "APP_VERSION=\$(cat ${src + "/VERSION"})"
        # patchShebangs ./output/build/hdzgoggle-main/mkapp/mkapp_ota.sh

        export NIX_CFLAGS_COMPILE="$NIX_CFLAGS_COMPILE -Wno-implicit-function-declaration"

        substituteInPlace ./output/build/host-util-linux-*/Makefile \
          --replace-fail "chmod 4755" "chmod 755"

        # re-run build with patches/fixes from above
        make O=$PWD/output BR2_DL_DIR=$PWD/dl BR2_EXTERNAL=$PWD -C buildroot -j$NIX_BUILD_CORES --keep-going || true
        make O=$PWD/output BR2_DL_DIR=$PWD/dl BR2_EXTERNAL=$PWD -C buildroot -j$NIX_BUILD_CORES --keep-going || true

        # continue build
        # make O=$PWD/output BR2_DL_DIR=$PWD/dl BR2_EXTERNAL=$PWD -C buildroot -j$NIX_BUILD_CORES

        mkdir $out
        mv output/images/rootfs.ext2 $out/
      '';
    };
in
# baseFs
  runCommand "hdzero-rootfs"
    {
      nativeBuildInputs = [
        e2tools
      ];
    }
    ''
      rootfs="$PWD/rootfs.ext2"
      cp ${baseFs}/rootfs.ext2 "$rootfs"
      chmod +w "$rootfs"
      for lib in ${libDir}/*/lib/*; do
        e2cp "$lib" "$rootfs:/usr/lib/$(basename "$lib")"
      done
      pushd "${kernel}"
      filelist=$(find lib/modules -type f)
      echo "$filelist" | e2cp -apv -d "$rootfs":/
      popd
      mkdir $out
      mv rootfs.ext2 $out/
    ''
