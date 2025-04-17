{
  config,
  pkgs,
  lib,
  packages,
  ...
}: {
  imports = [
    ./modules/wifi.nix
    ./modules/hdzero.nix
    # ./modules/avahi.nix
  ];

  networking.hostName = "hdzero";

  # enables mdns
  services.resolved.enable = true;

  # no udev for now
  services.udev.enable = false;

  services.haveged.enable = true;
  systemd.services.systemd-random-seed.enable = false;

  # users / login
  users.users.root.initialPassword = "root";
  users.mutableUsers = true;
  services.getty.autologinUser = "root";

  # minify
  nixpkgs.flake.setFlakeRegistry = false;
  nixpkgs.flake.setNixPath = false;
  nix.registry = lib.mkForce { };
  documentation.doc.enable = false;
  documentation.man.enable = false;

  # needed for nixos-rebuild-switch to work
  system.build.installBootLoader = pkgs.writeShellScript "hdzero-switch-boot" ''
    ${pkgs.busybox}/bin/ln -sf $1/init /init
  '';

  # boot
  boot.loader.grub.enable = false;
  boot.initrd.enable = false;
  boot.kernelPackages = pkgs.linuxPackagesFor packages.kernel;
  boot.postBootCommands = ''
    # fans to max
    echo 0x0300B0fc 0x35517751 > /sys/class/sunxi_dump/write

    # This prevents spamming of warning of this kind:
    #   tina kern.warn kernel: [ 1213.053354] c=25,a=0x   8eb48,bs=    8,t=     2346us,sp=   1705KB/s
    echo 0 > /sys/devices/platform/soc/sdc0/sunxi_host_filter_w_speed
  '';

  # kernel
  # TODO: disable kernel instead of overriding initrd with garbage
  # boot.kernel.enable = false;
  system.build.initialRamdisk = "foo";
  system.boot.loader.initrdFile = "bar";
  system.build.initialRamdiskSecretAppender = "baz";
  # link kernel modules via systemd-tmpfiles
  systemd.tmpfiles.settings.kernel-modules."/lib/modules".L.argument =
    "${packages.kernel-modules}/lib/modules";
  systemd.services.systemd-modules-load.after = [ "systemd-tmpfiles-setup.service" ];


  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    autoResize = true;
    fsType = "ext4";
  };
  fileSystems."/mnt/config" = {
    device = "/dev/mmcblk0p3";
  };
  services.openssh.enable = true;
  services.openssh.settings.PermitRootLogin = "yes";
  networking.firewall.enable = false;
  environment.systemPackages = [
    packages.goggle-app-nix
    packages.hdzero-scripts
    packages.ini-read
    pkgs.bat
    # pkgs.haveged
    pkgs.hostapd
    pkgs.htop
    pkgs.i2c-tools
    pkgs.lrzsz
    pkgs.mtdutils
    pkgs.pciutils
    pkgs.strace
    pkgs.vim
    pkgs.wpa_supplicant
    pkgs.busybox
  ];
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
}
