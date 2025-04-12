{
  python3,
  rsync,
  e2fsprogs,
  pkgs,
  stdenv,
  lib,
  fetchFromGitHub,

  # flake inputs
  hdzero-goggle-buildroot,
  nix-filter,

  # from this project
  breakpointHook,
  goggle-app,
  kernel,
  hdzero-scripts,
}:
let
  machine = pkgs.nixos {
    services.udev.enable = false;

    boot.kernelPackages = pkgs.linuxPackagesFor kernel;
    boot.initrd.enable = false;
    boot.kernel.enable = false;
    boot.loader.grub.enable = false;
    fileSystems."/" = {
      device = "/dev/disk/by-label/nixos";
      autoResize = true;
      fsType = "ext4";
    };
    # virtualisation.docker.enable = true;
    users.users.root.initialPassword = "root";
    users.mutableUsers = true;
    services.openssh.enable = true;
    services.openssh.settings.PermitRootLogin = "yes";
    networking.firewall.enable = false;
    services.getty.autologinUser = "root";
    systemd.services.systemd-random-seed.enable = false;
    environment.systemPackages = [
      goggle-app
      hdzero-scripts
      pkgs.bat
      pkgs.haveged
      pkgs.hostapd
      pkgs.htop
      pkgs.i2c-tools
      pkgs.lrzsz
      pkgs.mtdutils
      pkgs.pciutils
      pkgs.strace
      pkgs.vim
      pkgs.wpa_supplicant
    ];
    nix.settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
    systemd.services.hdzero = {
      description = "hdzero goggle app";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Restart = "always";
        RestartSec = 5;
        ExecStart = "${goggle-app}/bin/HDZGOGGLE";
      };
      path = [
        pkgs.busybox
        hdzero-scripts
      ];
      preStart = ''
        modprobe videobuf2-core
        modprobe videobuf2-memops
        modprobe videobuf2-dma-contig
        modprobe videobuf2-v4l2
        modprobe vin_io
        modprobe tp9950
        modprobe imx415_mipi
        insmod /mnt/app/ko/hdzero.ko
        modprobe vin_v4l2
        modprobe sunxi-wlan
        usleep 200000
        echo 0x0300B098 0x00775577 > /sys/class/sunxi_dump/write
        echo 0x0300B0D8 0x22777777 > /sys/class/sunxi_dump/write
        echo 0x0300B0fc 0x35517751 > /sys/class/sunxi_dump/write  # fans to max
        insmod /mnt/app/ko/gpio_keys_hdzero.ko
	      insmod /mnt/app/ko/rotary_encoder.ko
        dispw -x
	      dispw -s vdpo 1080p50

        # load driver
        sleep 1
        insmod /mnt/app/ko/mcp3021.ko
        usleep 2000
        insmod /mnt/app/ko/nct75.ko
        usleep 2000

        # set Microphone Bias Control Register
        aww 0x050967c0 0x110e6100

        # #record process
        # source /mnt/app//app/record/record-env.sh
        # if [ -e /mnt/extsd/RECORD.log ]; then
        #   /mnt/app/app/record/record > /mnt/extsd/RECORD.log 2>&1 &
        # else
        #   /mnt/app/app/record/record &
        # fi

        # /mnt/app/script/sdstat_log_backup.sh

        # #system led
        # /mnt/app/script/system_daemon.sh &
      '';
    };
    boot.postBootCommands = ''
      # fans to max
      echo 0x0300B0fc 0x35517751 > /sys/class/sunxi_dump/write

      # This prevents spamming of warning of this kind:
      #   tina kern.warn kernel: [ 1213.053354] c=25,a=0x   8eb48,bs=    8,t=     2346us,sp=   1705KB/s
      echo 0 > /sys/devices/platform/soc/sdc0/sunxi_host_filter_w_speed
    '';
    # systemd.services."serial-getty@" = {
    #   path = [
    #     pkgs.bash
    #     pkgs.util-linux
    #     pkgs.coreutils
    #     pkgs.findutils
    #     pkgs.busybox
    #     pkgs.htop
    #     pkgs.openssh
    #   ];
    #   serviceConfig.ExecStart = lib.mkForce [
    #     "" # override upstream default with an empty ExecStart
    #     ("/bin/sh")
    #   ];
    #   restartIfChanged = false;
    # };
    # boot.isContainer = true;
    # system.activationScripts.etc-post.deps = ["etc"];
    # system.activationScripts.users.deps = ["etc-post"];
    # system.build.etcActivationCommands = lib.mkForce "PATH=${lib.makeBinPath [
    #   pkgs.coreutils
    #   pkgs.bash
    #   pkgs.findutils
    #   pkgs.busybox
    #   (pkgs.perl.withPackages (p: [ p.FileSlurp ]))
    # ]} /bin/sh";
  };

  koDir = nix-filter.lib {
    root = ../../mkapp/app/ko;
  };

  arbianFirmware = fetchFromGitHub {
    owner = "armbian";
    repo = "firmware";
    rev = "4050e02da2dce2b74c97101f7964ecfb962f5aec";
    hash = "sha256-wc4xyNtUlONntofWJm8/w0KErJzXKHijOyh9hAYTCoU=";
  };

  toplevel = machine.config.system.build.toplevel;
in
  stdenv.mkDerivation {
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
      python3
      rsync
      e2fsprogs
      breakpointHook
    ];
    buildPhase = ''
      rsync -a ${toplevel}/ fs
      chmod +w -R fs

      mkdir -p fs/nix/store
      paths="$(python3 -c 'import json; [print(x["path"]) for x in json.load(open(".attrs.json"))["closure"]]' | sort | uniq)"
      rsync -a $paths fs/nix/store/

      # mkdir fs/{dev,proc,run,sys,tmp,var}
      chmod +w fs
      rm fs/etc

      mkdir fs/mnt
      cp -r ${goggle-app}/app fs/mnt/app

      ln -s ${pkgs.bash}/bin/bash fs/bin/sh

      # install custom scripts from bkleiner/hdzero-goggle-buildroot

      # copy some shell scripts to /bin
      chmod +w fs/bin
      rm -r fs/bin
      mkdir fs/bin
      cp ${hdzero-goggle-buildroot}/board/hdzgoggle_common/rootfs_overlay/usr/sbin/* fs/bin/

      # install /etc/vclk_phase.cfg
      mkdir fs/etc
      cp ${../rootfs/vclk_phase.cfg} fs/etc/vclk_phase.cfg

      # install kernel modules
      mkdir -p fs/lib/modules
      filelist=$(find ${kernel}/lib/modules/ -type f)
      for file in $filelist; do
        # remove the ''${kernel} prefix
        target=$(echo $file | sed "s|${kernel}||")
        echo "installing kernel module $file to $target"
        mkdir -p $(dirname fs/$target)
        cp -v $file fs/$target
      done

      # add kernel module binaries from this repo, only if they are not already present
      for ko in ${koDir}/*.ko; do
        location=$(find ${kernel}/lib/modules -name "$(basename "$ko")")
        if [ -z "$location" ]; then
          cp "$ko" "fs/lib/modules/$(basename "$ko")"
        else
          echo "skipping $ko, already exists at $location"
        fi
      done

      mkdir -p fs/etc/firmware
      cp ${arbianFirmware}/xr819/*.bin fs/etc/firmware/

      mkdir $out
      mkfs.ext4 -d fs $out/rootfs.ext2 1200M \
        -E root_owner=0:0

      chmod +w -R fs
      mv fs $out/fs
    '';
  }
