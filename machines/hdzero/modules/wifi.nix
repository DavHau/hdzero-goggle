{
  pkgs,
  packages,
  ...
}:
let
  koDir = "${../../../mkapp/app/ko}";
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
      packages.ini-read
    ];
    serviceConfig.Restart = "on-failure";
    serviceConfig.RestartSec = 3;
    script = ''
      set -x
      if ! ini-read /mnt/config/setting.ini "wifi" "enable"; then
        echo "WiFi is disabled in setting.ini"
        exit 0
      fi
      sta_ssid=$(ini-read /mnt/config/setting.ini "wifi" "sta_ssid")
      sta_passwd=$(ini-read /mnt/config/setting.ini "wifi" "sta_passwd")

      # write wpa_supplicant.conf
      cat > /tmp/wifi.conf << EOF
      ctrl_interface=/var/run/wpa_supplicant
      update_config=1
      network={
        ssid="$sta_ssid"
        psk="$sta_passwd"
      }
      EOF

      modprobe sunxi-wlan
      insmod ${koDir}/xradio_mac.ko || :
      insmod ${koDir}/xradio_core.ko || :
      insmod ${koDir}/xradio_wlan.ko || :
      ifconfig wlan0 up || :
      udhcpc -x hostname:HDZero -x 0x3d:76931FAC9DAB2B -r 192.168.2.122 -i wlan0 -f || : &
      wpa_supplicant -Dnl80211 -iwlan0 -c /tmp/wifi.conf
      # /mnt/app/app/record/rtspLive &
    '';
  };
}
