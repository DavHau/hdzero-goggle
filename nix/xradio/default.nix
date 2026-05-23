# Out-of-tree XR819 wifi driver (fifteenhex/xradio) built against an
# arbitrary kernel.  The goggle's XR819 is on SDIO bus mmc1; this driver
# needs CFG80211 + MAC80211 enabled in the kernel config.
{
  stdenv,
  lib,
  fetchFromGitHub,
  kernel,
}:

stdenv.mkDerivation {
  pname = "xradio";
  version = "0-unstable-2025-05-07";

  src = fetchFromGitHub {
    owner = "fifteenhex";
    repo = "xradio";
    rev = "43992a7e7ed95ff815cf6d8ba81cef1085e50ab9";
    hash = "sha256-ZqTg0gA8GxGo08z6G8p2Te8J3DoUKpYBkbm7t06+u34=";
  };

  nativeBuildInputs = kernel.moduleBuildDependencies;

  KERNELDIR = "${kernel.dev}/lib/modules/${kernel.modDirVersion}/build";

  # Filter out O=$(buildRoot) from kernel.makeFlags — it is meant for
  # in-tree builds and breaks out-of-tree module compilation.
  makeFlags = lib.filter (f: !(lib.hasPrefix "O=" f)) kernel.makeFlags;

  buildPhase = ''
    runHook preBuild
    make -C $KERNELDIR M=$(pwd) ''${makeFlags[@]} modules
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -D xradio_wlan.ko $out/lib/modules/${kernel.modDirVersion}/extra/xradio_wlan.ko
    runHook postInstall
  '';

  meta = with lib; {
    description = "XR819 SDIO wifi driver (out-of-tree, fifteenhex fork)";
    license = licenses.gpl2Only;
    platforms = platforms.linux;
  };
}
