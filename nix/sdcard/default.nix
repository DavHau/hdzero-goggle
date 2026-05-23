{
  lib,
  stdenv,
  dos2unix,
  e2tools,
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

  # customization
  init ? "/init",
  # Optional DTB for the config FAT partition. When set, boot_normal
  # overwrites boot0's staged fdt at 0x7cfd1b20 with it before bootm,
  # so u-boot applies the env.cfg bootargs to our devicetree. Used by
  # the mainline image; the vendor kernel uses boot0's built-in DTB.
  bootDtb ? null,
}:
let
  # dtbDir = "${os-images}/images";
  # appExt2File = "${os-images}/images/app.ext2";
  # rootfsExt2File = "${os-images}/images/rootfs.ext2";
  # uImage = "${os-images}/images/uImage";

  dtbDir = runCommand "hdzero-dtb" {} ''
    mkdir $out
    ${dtc}/bin/dtc -o $out/hdzero_goggle.dtb -O dtb ${./hdzero_goggle.dts}
  '';
  appExt2File = "${goggle-app}/app.ext2";
  rootfsExt2File = "${rootfs}/rootfs.ext2";
  uImage = "${kernel}/uImage";
  env_cfg = writeText "env.cfg" (import ./env.cfg.nix {
    inherit init;
    # The BSP u-boot ignores bootm's fdt argument and 'fdt addr'; it
    # always uses the DTB boot0 staged at 0x7cfd1b20. Overwrite that
    # buffer with ours so u-boot applies env.cfg bootargs to it.
    bootNormal =
      if bootDtb == null then
        "sunxi_flash read 45000000 boot;bootm 45000000"
      else
        "fatload mmc 0:3 46000000 kernel.dtb;cp.b 46000000 7cfd1b20 \${filesize};sunxi_flash read 45000000 boot;bootm 45000000";
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
    cp -v ${rootfsExt2File} .
    cp -v ${appExt2File} .
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
    ${lib.optionalString (bootDtb != null) ''
      mcopy -i config.fat32 ${bootDtb} ::/kernel.dtb
    ''}

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
