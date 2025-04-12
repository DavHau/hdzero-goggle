{
  pkgs,
  packages,
  ...
}: {
  systemd.services.hdzero = {
    description = "hdzero goggle app";
    wantedBy = [ "multi-user.target" ];
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
      modprobe videobuf2-core
      modprobe videobuf2-memops
      modprobe videobuf2-dma-contig
      modprobe videobuf2-v4l2
      modprobe vin_io
      modprobe tp9950
      modprobe imx415_mipi
      insmod /mnt/app/ko/hdzero.ko || :
      modprobe vin_v4l2
      modprobe sunxi-wlan
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
