{
  binwalk,
  fetchzip,
  runCommand,
  sasquatch,
}:
let
  firmware = fetchzip {
    url = "https://www.hd-zero.com/_files/archives/967e02_9e6db8079a354f86979994a4ed28ab59.zip?dn=HDZEROGOGGLE_Rev20250319.zip";
    hash = "sha256-x/6MKHIr4tvItMR2/+B03jkaPL3fpaMrtrA0l++gJYM=";
    stripRoot=false;
  };
in
runCommand "hdzg-os-files"
  {
    nativeBuildInputs = [
      binwalk
      sasquatch
    ];
  }
  ''
    file=${firmware}/Recovery/HDZG_OS.bin
    binwalk $file -e -y squashfs
    # chown -R $(whoami):$(whoami) extractions
    cp -r extractions/HDZG_OS.bin.extracted/*/squashfs-root $out
''
