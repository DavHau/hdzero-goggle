{
  stdenv,
  dos2unix,
  genimage,
  util-linux,

  # from this project
  os-images,
  hdzero-goggle-tools,
  hdzero-goggle-buildroot,
}:
stdenv.mkDerivation {
  name = "hdzero-goggle-tools";
  dontUnpack = true;
  dontConfigure = true;
  dontFixup = true;
  nativeBuildInputs = [
    dos2unix
    genimage
    hdzero-goggle-tools
    util-linux
  ];
  buildPhase = ''
    BOARD_DIR="${hdzero-goggle-buildroot}/board/hdzgoggle_sdcard"
    COMMON_BOARD_DIR="${hdzero-goggle-buildroot}/board/hdzgoggle_common"
    source $COMMON_BOARD_DIR/functions.sh

    # pushd $BINARIES_DIR

    cp -v $BOARD_DIR/image/{boot0,u-boot}.fex .
    cp -v ${os-images}/images/{uImage,rootfs.ext2,app.ext2,hdzero_goggle.dtb} .

    u_boot_env_gen $BOARD_DIR/env.cfg env.fex

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

    cp -r $COMMON_BOARD_DIR/image/{optee,scp,soc-cfg}.fex .
    dragonsecboot -pack "$COMMON_BOARD_DIR/boot_package.cfg"

    BUILD_DIR="$PWD" \
      bash ${./genimage.sh} -c "$BOARD_DIR/genimage.cfg"
  '';
  installPhase = ''
    mkdir -p $out
    cp sdcard.img $out/
  '';
}
