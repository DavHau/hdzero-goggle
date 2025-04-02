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
  toolchain,
  kernel,

  # debug
  breakpointHook,
  vim,
  ripgrep,
  pkgs,
}:
let
  inherit (lib)
    substring
    ;
  inherit (builtins) hashString;
  libDir = nix-filter.lib {
    root = ../../lib;
  };
  koDir = nix-filter.lib {
    root = ../../mkapp/app/ko;
  };
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
    outputHash = "sha256-EW2jpgrXHvlAs5m+MTYBsuHCP/2afsyogStK7QLoXO4=";
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
          # --replace-fail BR2_KERNEL_HEADERS_CUSTOM_TARBALL_LOCATION= BR2_KERNEL_HEADERS_CUSTOM_TARBALL_LOCATION=${hdzero-goggle-linux-src}
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
            'BR2_TOOLCHAIN_EXTERNAL_PATH="${toolchain}"'
        # cat Config.in | head -n1 > Config.in.new
        # mv Config.in.new Config.in
        echo "" > Config.in
        rm -r ./package/hdzero-tools
      '';
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

        # patch shebangs of buildroot built host tools
        patchShebangs ./output/build/host-*

        # compilation fails without ignoring this error
        # TODO: fix this properly
        export NIX_CFLAGS_COMPILE="$NIX_CFLAGS_COMPILE -Wno-implicit-function-declaration"

        # setting setuid not possible in nix sandbox
        substituteInPlace ./output/build/host-util-linux-*/Makefile \
          --replace-fail "chmod 4755" "chmod 755"

        # re-run build with patches/fixes from above
        make O=$PWD/output BR2_DL_DIR=$PWD/dl BR2_EXTERNAL=$PWD -C buildroot -j$NIX_BUILD_CORES --keep-going

        mkdir $out
        mv output/images/rootfs.ext2 $out/
      '';
    };
in
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

      # add kernel module from the kernel build
      filelist=$(find lib/modules/ -type f)
      echo "$filelist" | e2cp -apv -d "$rootfs":/

      # add kernel module binaries from this repo, only if they are not already present
      for ko in ${koDir}/*.ko; do
        location=$(find lib/modules -name "$(basename "$ko")")
        if [ -z "$location" ]; then
          e2cp "$ko" "$rootfs:/lib/modules/$(basename "$ko")"
        else
          echo "skipping $ko, already exists at $location"
        fi
      done

      popd

      # add some apps
      e2cp -vp "${pkgs.pkgsCross.armv7l-hf-multiplatform.pkgsStatic.gdb}/bin/gdb" "$rootfs:/bin/gdb"
      e2cp -vp "${pkgs.pkgsCross.armv7l-hf-multiplatform.pkgsStatic.util-linux}/bin/dmesg" "$rootfs:/bin/dmesg"

      # add vclk_phase.cfg
      e2cp -vp "${./vclk_phase.cfg}" "$rootfs:/etc/vclk_phase.cfg"

      mkdir $out
      mv rootfs.ext2 $out/
    ''
