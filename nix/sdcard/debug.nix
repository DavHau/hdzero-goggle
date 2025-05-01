{
  stdenv,
  dos2unix,
  e2tools,
  e2fsprogs,
  genimage,
  util-linux,
  runCommand,
  dtc,
  writeText,
  mtools,

  # from this project
  goggle-app,
  hdzero-goggle-tools,
  hdzero-goggle-buildroot,
  kernel,
  rootfs,
  pkgsArm,

  # customization
  init ? "/init",
}:
let
  dtbDir = runCommand "hdzero-dtb" {} ''
    mkdir $out
    ${dtc}/bin/dtc -o $out/hdzero_goggle.dtb -O dtb ${./hdzero_goggle.dts}
  '';
  # appExt2File = "${goggle-app}/app.ext2";
  rootfsExt2File = runCommand "rootfs.ext2"
    {
      nativeBuildInputs = [
        e2fsprogs
      ];
    }
    ''
      mkdir -p fs/bin
      cp ${pkgsArm.pkgsStatic.busybox}/bin/sh fs/bin/
      mkfs.ext4 -d fs $out 10M
    '';
  appExt2File = runCommand "app.ext2"
    {
      nativeBuildInputs = [
        e2fsprogs
      ];
    }
    ''
      mkdir fs
      mkfs.ext4 -d fs $out 1M
    '';
  # uImage = "${kernel}/uImage";
  uImage = "${/home/grmpf/synced/projects/github/linux/arch/arm/boot}/uImage";
  env_cfg = writeText "env.cfg" (import ./env.cfg.nix {
    inherit init;
  });
in
stdenv.mkDerivation {
  name = "hdzero-goggle-sdcard";
  dontUnpack = true;
  dontConfigure = true;
  dontFixup = true;
  nativeBuildInputs = [
    dos2unix
    e2tools
    genimage
    hdzero-goggle-tools
    util-linux
    mtools
  ];
  buildPhase = ''
    runHook preBuild

    BOARD_DIR="${hdzero-goggle-buildroot}/board/hdzgoggle_sdcard"
    COMMON_BOARD_DIR="${hdzero-goggle-buildroot}/board/hdzgoggle_common"
    source $COMMON_BOARD_DIR/functions.sh

    cp -v $BOARD_DIR/image/{boot0,u-boot}.fex .
    cp -v ${rootfsExt2File} ./rootfs.ext2
    cp -v ${appExt2File} ./app.ext2
    cp -v ${uImage} .
    cp -v "${dtbDir}/hdzero_goggle.dtb" .
    # cp -v "${kernel}/dtbs/sun8iw16p1-soc.dtb" hdzero_goggle.dtb

    chmod +w app.ext2

    # TODO: fix this
    # modify default settings
    # e2cp ''${./setting.ini} app.ext2:/setting.ini\

    # override the app with our own build
    e2cp -vp ${goggle-app}/HDZGOGGLE app.ext2:/app/HDZGOGGLE

    u_boot_env_gen ${env_cfg} env.fex

    KERNEL_SIZE=$(stat -c%s uImage)
    ROOTFS_SIZE=$(stat -c%s rootfs.ext2)
    ENV_SIZE=$(stat -c%s env.fex)
    APP_SIZE=$(stat -c%s app.ext2)

    cat > mbr.fex << EOF
    [mbr]
    size = 16

    [partition_start]

    [partition]
        name         = env
        size         = $(($ENV_SIZE / 512))
        user_type    = 0x8000

    [partition]
        name         = boot
        size         = $(($KERNEL_SIZE / 512))
        user_type    = 0x8000

    [partition]
        name         = rootfs
        size         = $(($ROOTFS_SIZE / 512))
        user_type    = 0x8000

    [partition]
        name         = app
        size         = $(($APP_SIZE / 512))
        user_type    = 0x8000
    EOF

    unix2dos mbr.fex
    script mbr.fex
    update_mbr mbr.bin 1 mbr.fex

    cp -vr $COMMON_BOARD_DIR/image/{optee,scp,soc-cfg}.fex .
    dragonsecboot -pack "$COMMON_BOARD_DIR/boot_package.cfg"

    fallocate -l 16M config.fat32
    mformat -v  oz-config -i config.fat32 ::
    mcopy -i config.fat32 ${./setting.ini} ::/setting.ini

    BUILD_DIR="$PWD" \
      bash ${./genimage.sh} -c "${./genimage.cfg}"

    runHook postBuild
  '';
  installPhase = ''
    mkdir -p $out
    cp sdcard.img $out/
    cp app.ext2 $out/
  '';
}
