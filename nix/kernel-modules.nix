{
  runCommand,

  # flake inputs
  nix-filter,

  # from this project
  hdzero-goggle-src,
  hdzero-kmods,
  kernel,
}:
let
  koDir = nix-filter.lib {
    root = "${hdzero-goggle-src}/mkapp/app/ko";
  };
in
runCommand "kernel-modules" {} ''
  installDir=$out/lib/modules/${kernel.modDirVersion}
  mkdir -p $installDir
  cp -r ${kernel}/lib/modules/${kernel.modDirVersion}/* $installDir
  chmod +w -R $installDir
  cp ${koDir}/rotary_encoder.ko $installDir/
  cp \
    ${hdzero-kmods}/lib/modules/${kernel.modDirVersion}/extra/*/*.ko \
    $installDir/
''
