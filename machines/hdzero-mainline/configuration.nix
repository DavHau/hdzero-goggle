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

  # The top fan controller (DM5680 companion MCU at 0x64 on the i2c2 bus,
  # register 0x83 = duty 0-100) is normally driven by the goggle app.
  # Without it the SoC has no airflow, so spin the fan at a fixed duty.
  systemd.services.topfan = {
    description = "Set top fan speed";
    wantedBy = [ "multi-user.target" ];
    serviceConfig.Type = "oneshot";
    script = ''
      for dev in /sys/bus/i2c/devices/i2c-*; do
        case "$(readlink -f "$dev/of_node")" in
        *i2c@5002800)
          ${pkgs.i2c-tools}/bin/i2cset -y "''${dev##*-}" 0x64 0x83 41
          exit 0
          ;;
        esac
      done
      echo "i2c2 bus not found" >&2
      exit 1
    '';
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
