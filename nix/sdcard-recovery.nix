{
  runCommand,
  mtools,
  genimage,
  util-linux,

  # from this project
  upstream-firmware-archive,
}:
runCommand "sdcard-recovery"
  {
    buildInputs = [
      mtools
      genimage
      util-linux
    ];
  }
  ''
    # make recovery.fat32 image
    fallocate -l 128M recovery.fat32
    mformat -i recovery.fat32 -v HZ_RECOVERY
    mcopy -i recovery.fat32 -s ${upstream-firmware-archive}/Recovery/{HDZGOGGLE_RX,HDZGOGGLE_VA,HDZG_OS}.bin ::/

    # write genimage config
    cat > genimage.cfg <<EOF
    image sdcard.img {
      hdimage {}
      partition boot {
        partition-type = 0x83
        image = "recovery.fat32"
      }
    }
    EOF

    mkdir $out

    BUILD_DIR=$PWD genimage \
      --config genimage.cfg \
      --inputpath "$PWD" \
      --outputpath "$out"
  ''
