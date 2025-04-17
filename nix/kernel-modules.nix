{
  runCommand,

  # flake inputs
  nix-filter,

  # from this project
  hdzero-goggle-src,
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
  cp \
    ${koDir}/{disp,gpio_keys_hdzero,hdzero,mcp3021,nct75,rotary_encoder,w25q128,xradio_core,xradio_mac}.ko \
    $installDir/
''
