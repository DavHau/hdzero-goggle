{
  pkgs,
  ...
}:
let
  koDir = "${../../../mkapp/app/ko}";
  wpaSupplicantConf = pkgs.writeText "wpa_supplicant.conf" ''
    ctrl_interface=/var/log/wpa_supplicant
    update_config=1
    network={
      ssid="MySSID"
      psk="MyPassword"
    }
  '';
in
{
  systemd.services.wifi = {
    description = "HDZero WiFi";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    path = [
      pkgs.bash
      pkgs.busybox
      pkgs.wpa_supplicant
    ];
    serviceConfig.Restart = "always";
    serviceConfig.RestartSec = 3;
    script = ''
      set -x
      modprobe sunxi-wlan
      insmod ${koDir}/xradio_mac.ko || :
      insmod ${koDir}/xradio_core.ko || :
      insmod ${koDir}/xradio_wlan.ko || :
      ifconfig wlan0 up || :
      udhcpc -x hostname:HDZero -x 0x3d:76931FAC9DAB2B -r 192.168.2.122 -i wlan0 -f || : &
      wpa_supplicant -Dnl80211 -iwlan0 -c ${wpaSupplicantConf}
      # /mnt/app/app/record/rtspLive &
    '';
  };
}
