{
  python3,
  rsync,
  e2fsprogs,
  pkgs,
  stdenv,
  lib,
  fetchFromGitHub,
  nix,
  fakeroot,

  # flake inputs
  nix-filter,

  # from this project
  breakpointHook,
  goggle-app,
  kernel,
  machine,
}:
let

  koDir = nix-filter.lib {
    root = ../../mkapp/app/ko;
  };

  armbianFirmware = fetchFromGitHub {
    owner = "armbian";
    repo = "firmware";
    rev = "4050e02da2dce2b74c97101f7964ecfb962f5aec";
    hash = "sha256-wc4xyNtUlONntofWJm8/w0KErJzXKHijOyh9hAYTCoU=";
  };

  toplevel = machine.config.system.build.toplevel;
in
  stdenv.mkDerivation (finalAttrs: {
    name = "hdzero-goggle-nixos-ext4";
    passthru.config = machine.config;
    __structuredAttrs = true;
    exportReferencesGraph.closure = toplevel;
    dontUnpack = true;
    dontPatch = true;
    dontConfigure = true;
    dontInstall = true;
    dontFixup = true;
    nativeBuildInputs = [
      breakpointHook
      e2fsprogs
      nix
      python3
      rsync
      fakeroot
    ];
    closureInfo = pkgs.closureInfo {
      rootPaths = toplevel;
    };
    buildPhase = ''
      mkdir fs
      ln -s ${toplevel}/init fs/init

      mkdir -p fs/nix/store
      paths="$(python3 -c 'import json; [print(x["path"]) for x in json.load(open(".attrs.json"))["closure"]]' | sort | uniq)"
      rsync -a $paths fs/nix/store/
      nix-store --load-db --store ./fs < "$closureInfo/registration"

      mkdir fs/mnt
      cp -r ${goggle-app}/app fs/mnt/app

      # install /etc/vclk_phase.cfg
      mkdir fs/etc
      cp ${../rootfs/vclk_phase.cfg} fs/etc/vclk_phase.cfg

      mkdir $out

      fakeroot bash -c "
        chown -R 0:0 ./fs
        mkfs.ext4 -d ./fs $out/rootfs.ext2 2G
      "

      chmod +w -R fs
      mv fs $out/fs
    '';
  })
