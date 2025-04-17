{
  lib,
  pkgs,
  packages,
  ...
}:
let
  armbianFirmware = pkgs.fetchFromGitHub {
    owner = "armbian";
    repo = "firmware";
    rev = "4050e02da2dce2b74c97101f7964ecfb962f5aec";
    hash = "sha256-wc4xyNtUlONntofWJm8/w0KErJzXKHijOyh9hAYTCoU=";
  };

  xr819Firmware = pkgs.runCommand "xr819-firmware" {} ''
    mkdir -p $out/lib/firmware
    cp -r ${armbianFirmware}/xr819 $out/lib/firmware/xr819
  '';
in
{
  # override needed because we have no ipv6
  systemd.services.dhcpcd.serviceConfig.ReadWritePaths = lib.mkForce ["/proc/sys/net/ipv4"];
  # hardware.firmware is missing if udev is disabled
  systemd.tmpfiles.settings.xradio-firmware."/lib/firmware".L.argument =
    "${xr819Firmware}/lib/firmware";
  systemd.services.wifi = {
    description = "HDZero WiFi";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    path = [
      pkgs.kmod
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
      modprobe xradio-wlan
      ifconfig wlan0 up || :
      sleep 1
      wpa_supplicant -Dnl80211 -iwlan0 -c /tmp/wifi.conf
      # /mnt/app/app/record/rtspLive &
    '';
  };
}
