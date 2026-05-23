# Minimal HDZero Goggle on the mainline kernel (Linux 7.0.9 + V536 port).
# No vendor video stack, goggle app or xradio wifi; serial console, sshd
# and basic tools only. Vendor boot chain and SD layout unchanged.
{
  config,
  pkgs,
  lib,
  packages,
  ...
}:
{
  networking.hostName = "hdzero-mainline";

  # enables mdns
  services.resolved.enable = true;

  # no udev for now
  services.udev.enable = false;

  services.haveged.enable = true;
  systemd.services.systemd-random-seed.enable = false;

  # users / login
  users.users.root.initialPassword = "openzero";
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

  # boot: u-boot loads the uImage from partition 1 and passes
  # root=/dev/mmcblk0p2 init=/init, no initrd
  boot.loader.grub.enable = false;
  boot.initrd.enable = false;
  boot.kernelPackages = pkgs.linuxPackagesFor packages.kernel-mainline-nixos;

  # TODO: disable kernel instead of overriding initrd with garbage
  system.build.initialRamdisk = "foo";
  system.boot.loader.initrdFile = "bar";
  system.build.initialRamdiskSecretAppender = "baz";

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };
  fileSystems."/mnt/config" = {
    device = "/dev/mmcblk0p3";
  };

  services.openssh.enable = true;
  services.openssh.settings.PermitRootLogin = "yes";
  networking.firewall.enable = false;

  environment.systemPackages = [
    pkgs.htop
    pkgs.i2c-tools
    pkgs.strace
    pkgs.usbutils
    pkgs.vim
    pkgs.busybox
  ];

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
}
