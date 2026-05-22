{
  pkgs,
  packages,
  ...
}:
{
  boot.extraModulePackages = [
    packages.kernel-modules
  ];
  boot.kernelModules = [
    "videobuf2-core"
    "videobuf2-memops"
    "videobuf2-dma-contig"
    "videobuf2-v4l2"
    "vin_io"
    "tp9950"
    "imx415_mipi"
    # sensor modules must be loaded before vin_v4l2, it registers them at probe
    "hdzero"
    "vin_v4l2"
    "sunxi-wlan"
    "gpio_keys"
    "gpio_keys_hdzero"
  ];
  systemd.services.hdzero = {
    description = "hdzero goggle app";
    wantedBy = [ "multi-user.target" ];
    before = [ "systemd-sysctl.service" ];
    # the app needs the vin/v4l2 modules from boot.kernelModules
    after = [ "systemd-modules-load.service" ];
    wants = [ "systemd-modules-load.service" ];
    unitConfig.DefaultDependencies = false;
    serviceConfig = {
      Restart = "always";
      RestartSec = 5;
      ExecStart = "${packages.goggle-app-nix}/bin/HDZGOGGLE";
    };
    path = [
      pkgs.busybox
      packages.hdzero-scripts
    ];
    preStart = ''
      echo 0x0300B098 0x00775577 > /sys/class/sunxi_dump/write
      echo 0x0300B0D8 0x22777777 > /sys/class/sunxi_dump/write
      echo 0x0300B0fc 0x35517751 > /sys/class/sunxi_dump/write  # fans to max
      dispw -x
      dispw -s vdpo 1080p50

      # load driver
      sleep 1
      insmod /mnt/app/ko/mcp3021.ko || :
      usleep 2000
      insmod ${packages.kernel-modules}/lib/modules/${packages.kernel.modDirVersion}/nct75.ko || :
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
}
