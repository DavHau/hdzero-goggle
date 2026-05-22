{
  runCommand,

  # from this project
  hdzero-kmods,
  kernel,
}:
runCommand "kernel-modules" {} ''
  installDir=$out/lib/modules/${kernel.modDirVersion}
  mkdir -p $installDir
  cp -r ${kernel}/lib/modules/${kernel.modDirVersion}/* $installDir
  chmod +w -R $installDir
  cp \
    ${hdzero-kmods}/lib/modules/${kernel.modDirVersion}/extra/*/*.ko \
    $installDir/
''
