{
  runCommand,
  pkgsCross,
  python3,
  rsync,
  e2fsprogs,
  autoPatchelfHook,
  lib,
  fetchFromGitHub,

  # inputs
  nix-filter,

  # from this project
  breakpointHook,
  goggle-app,
  hdzero-goggle-buildroot,
  kernel,
  hdzg-os-files,
}:
let
  inherit (lib)
    getBin;
  pkgs = pkgsCross.armv7l-hf-multiplatform;
  koDir = nix-filter.lib {
    root = ../../mkapp/app/ko;
  };
  busybox = pkgs.pkgsStatic.busybox;
  armbianFirmware = fetchFromGitHub {
    owner = "armbian";
    repo = "firmware";
    rev = "4050e02da2dce2b74c97101f7964ecfb962f5aec";
    hash = "sha256-wc4xyNtUlONntofWJm8/w0KErJzXKHijOyh9hAYTCoU=";
  };
  includedPrograms = map getBin [
    busybox
    pkgs.haveged
    pkgs.wpa_supplicant
    pkgs.eudev
    pkgs.strace
    pkgs.hostapd
    pkgs.lrzsz
    pkgs.i2c-tools
    pkgs.mtdutils
    pkgs.glibc
    pkgs.file
    goggle-app
    # pkgs.util-linux
    # pkgs.diffutils
    # pkgs.gnutar
    # pkgs.dosfstools
    # pkgs.alsa-utils  # gigantic dep tree, let's try without
  ];
  patchedLibs = pkgsCross.armv7l-hf-multiplatform.stdenv.mkDerivation {
    name = "hdzero-extracted-rootfs-libs-patched";
    src = "${hdzg-os-files}";
    dontConfigure = true;
    nativeBuildInputs = [
      autoPatchelfHook
    ];
    dontBuild = true;
    installPhase = ''
      mkdir -p $out/lib
      cp -r lib/* usr/lib/* $out/lib/
    '';
  };
in
runCommand "rootfs-nix" {
  nativeBuildInputs = [
    breakpointHook
    rsync
    python3
    e2fsprogs
  ];
  __structuredAttrs = true;
  exportReferencesGraph.closure = includedPrograms;
  passthru = {inherit patchedLibs;};
} ''
  mkdir -p fs/bin
  # symlink bins to the rootfs
  for store_path in ${toString includedPrograms}; do
    for bin in $(find $store_path/bin -type f -or -type l); do
      echo "linking $bin"
      ln -fs $bin fs/bin/$(basename $bin)
    done
  done

  mkdir -p fs/nix/store
  paths="$(python3 -c 'import json; [print(x["path"]) for x in json.load(open(".attrs.json"))["closure"]]' | sort | uniq)"
  rsync -a $paths fs/nix/store/

  mkdir fs/lib

  binfiles=$(find ${hdzg-os-files}/{bin,sbin,usr/bin,usr/sbin} -type f -or -type l)
  for binfile in $binfiles; do
    # check if the files exists in the new rootfs
    if [ ! -e "fs/bin/$(basename $binfile)" ]; then
      echo missing bin: $binfile
      echo $binfile >> missing-files
    fi
  done
  libfiles=$(find ${hdzg-os-files}/{lib,usr/lib} -type f)
  for lib in $libfiles; do
    # check if the files exists in the new rootfs
    if [ ! -e "fs/lib/$(basename $lib)" ]; then
      echo missing lib: $lib
      echo $lib >> missing-files
    fi
  done
  ignore=()
  for file in $binfiles $libfiles; do
    ignore+=($file)
  done

  # link /sbin, /usr/bin, /usr/sbin to /bin
  for dir in fs/{sbin,usr/bin,usr/sbin}; do
    mkdir -p $(dirname $dir)
    ln -s /bin $dir
  done

  # create /proc /dev /sys /mnt
  mkdir -p fs/{proc,dev,/sys,/mnt}

  rsync -a ${goggle-app}/app fs/mnt/

  # symlink /var to /tmp
  mkdir -p fs/tmp
  ln -s /tmp fs/var

  # install custom scripts from bkleiner/hdzero-goggle-buildroot
  chmod +w -R fs
  # copy some shell scripts to /bin
  cp ${hdzero-goggle-buildroot}/board/hdzgoggle_common/rootfs_overlay/usr/sbin/* fs/bin/

  rsync -a ${hdzero-goggle-buildroot}/board/hdzgoggle_common/rootfs_overlay/ fs/ \
    --exclude usr/sbin \
    --exclude 'usr/sbin/*'
  chmod +w -R fs

  # install local custom files
  rsync -a ${./overlay}/ fs/
  chmod +w -R fs

  # install /etc/vclk_phase.cfg
  cp ${../rootfs/vclk_phase.cfg} fs/etc/vclk_phase.cfg

  # create /linuxrc
  cp ${busybox}/bin/busybox fs/linuxrc

  # install kernel modules
  mkdir -p fs/lib/modules
  filelist=$(find ${kernel}/lib/modules/ -type f)
  for file in $filelist; do
    # remove the ''${kernel} prefix
    target=$(echo $file | sed "s|${kernel}||")
    echo "installing kernel module $file to $target"
    mkdir -p $(dirname fs/$target)
    cp -v $file fs/$target
  done

  # add kernel module binaries from this repo, only if they are not already present
  for ko in ${koDir}/*.ko; do
    location=$(find ${kernel}/lib/modules -name "$(basename "$ko")")
    if [ -z "$location" ]; then
      cp "$ko" "fs/lib/modules/$(basename "$ko")"
    else
      echo "skipping $ko, already exists at $location"
    fi
  done

  mkdir -p fs/etc/firmware
  cp ${armbianFirmware}/xr819/*.bin fs/etc/firmware/

  for path in $(find ${hdzg-os-files} ! -type d); do
    # continue if path in ignore
    if [[ ''${ignore[@]} =~ $path ]]; then
      continue
    fi
    # strip /nix/store from path
    spath=$(echo $path | sed 's|/nix/store/[^/]*||')
    if [ -e "fs$spath" ]; then
      continue
    fi
    echo "path missing: $path"
  done

  chmod +w -R fs
  mkfs.ext4 -d ./fs rootfs.ext2 "1024M"

  mkdir $out
  mv rootfs.ext2 $out/
  mv fs $out/fs
  mv missing-files $out/missing-files
''
