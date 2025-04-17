{
  pkgs,
  packages,
  ...
}: {
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
    "vin_v4l2"
    "sunxi-wlan"
  ];
  systemd.services.hdzero = {
    description = "hdzero goggle app";
    wantedBy = [ "multi-user.target" ];
    after = ["mnt-config.mount" "systemd-modules-load.service" "systemd-tmpfiles-setup.service"];
    before = ["systemd-sysctl.service"];
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
      insmod /mnt/app/ko/hdzero.ko || :
      usleep 200000
      echo 0x0300B098 0x00775577 > /sys/class/sunxi_dump/write
      echo 0x0300B0D8 0x22777777 > /sys/class/sunxi_dump/write
      echo 0x0300B0fc 0x35517751 > /sys/class/sunxi_dump/write  # fans to max
      insmod /mnt/app/ko/gpio_keys_hdzero.ko || :
      insmod /mnt/app/ko/rotary_encoder.ko || :
      dispw -x
      dispw -s vdpo 1080p50

      # load driver
      sleep 1
      insmod /mnt/app/ko/mcp3021.ko || :
      usleep 2000
      insmod /mnt/app/ko/nct75.ko || :
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
