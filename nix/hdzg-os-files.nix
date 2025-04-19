{
  binwalk,
  fetchzip,
  runCommand,
  sasquatch,

  # from this project
  upstream-firmware-archive,
}:
runCommand "hdzg-os-files"
  {
    nativeBuildInputs = [
      binwalk
      sasquatch
    ];
  }
  ''
    file=${upstream-firmware-archive}/Recovery/HDZG_OS.bin
    binwalk $file -e -y squashfs
    # chown -R $(whoami):$(whoami) extractions
    cp -r extractions/HDZG_OS.bin.extracted/*/squashfs-root $out
''
