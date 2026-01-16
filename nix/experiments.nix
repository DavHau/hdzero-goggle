{
  inputs,
  self,
  system,
  pkgs,
  pkgsArm,
}:
{
  sdcard-debug = pkgs.callPackage ../nix/sdcard/debug.nix {
    inherit (inputs) hdzero-goggle-buildroot;
    inherit pkgsArm;
    inherit (self.packages.${system})
      hdzero-goggle-tools
      kernel
      rootfs
      ;
    goggle-app = self.packages.${system}.goggle-app-nix;
    init = "/bin/sh";
  };

  kernel_6_12 =
    (pkgsArm.linux_6_12.override {
      defconfig = "sunxi_defconfig";
      autoModules = false;
      extraConfig = ''
        CONFIG_SERIAL_8250 y
        CONFIG_SERIAL_8250_CONSOLE y
        CONFIG_SERIAL_EARLYCON y
        CONFIG_EARLY_PRINTK y
      '';
    }).overrideAttrs
      (old: {
        installTargets = old.installTargets ++ [ "uinstall" ];
        buildFlags = old.buildFlags ++ [
          "uImage"
          "LOADADDR=0x40008000"
        ];
      });

  # experiment with kernel 5.4
  kernel_5_4 =
    inputs.nixpkgs_22_05.legacyPackages.${system}.pkgsCross.armv7l-hf-multiplatform.callPackage
      ../nix/kernel_5_4
      {
        inherit (inputs) kernel-5-4-src;
        breakpointHook = pkgs.breakpointHook;
      };

  # webrtc library (experiment)
  libpeer = pkgs.callPackage ../nix/libpeer.nix { };

  # legacy: this is simply wrapping the full buildroot build from https://github.com/bkleiner/hdzero-goggle-buildroot
  # better use .#sdcard output instead
  # contains sdcard.img bootable image, as well as HDZ_OS.bin
  os-images = pkgs.callPackage ../nix/os-images.nix {
    inherit (inputs) hdzero-goggle-src hdzero-goggle-buildroot hdzero-goggle-linux-src;
    inherit (self.packages.${system}) toolchain;
  };

  # legacy: patched upstream toolchain to make compatible with nix build sandbox
  toolchain = pkgs.callPackage ../nix/toolchain.nix { };

  # downstream driver for the wifi chip
  xradio-driver = pkgsArm.callPackage ../nix/xradio-driver {
    inherit (self.packages.${system}) kernel;
  };

  # sdcard containing:
  # - nix built kernel
  # - nix built goggle app
  # - buildroot built rootfs
  sdcard = pkgs.callPackage ../nix/sdcard {
    inherit (inputs) hdzero-goggle-buildroot;
    inherit (self.packages.${system})
      goggle-app
      hdzero-goggle-tools
      kernel
      rootfs
      ;
    init = "/linuxrc";
  };

  # only the rootfs etx2 image built by wrapping buildroot
  rootfs = pkgs.callPackage ../nix/rootfs {
    inherit (inputs) hdzero-goggle-buildroot nix-filter;
    inherit (self.packages.${system}) kernel toolchain;
  };

  # the goggle app including the jffs2 image with service binaries
  goggle-app = pkgs.callPackage ../nix/goggle-app.nix {
    inherit (inputs) hdzero-goggle-src;
    inherit (self.packages.${system}) toolchain;
  };

  # attempt on generating an actual emulator to test the goggle OS
  # (not working yet)
  emulate = pkgs.callPackage ../nix/emulate {
    rootfs = self.packages.${system}.rootfs-nixos;
    pkgsLinux = inputs.nixpkgs_22_05.legacyPackages.${system}.pkgsCross.armv7l-hf-multiplatform;
    inherit (self.packages.${system}) kernel;
    # inherit hdzero-goggle-linux-src;
  };

  emulate_5_4 = pkgs.callPackage ../nix/emulate_5_4 {
    inherit pkgsArm;
    kernel = self.packages.${system}.kernel;
  };

  # tools to extract files from ext images. currently not used.
  extfstools = pkgs.callPackage ../nix/extfstools.nix { };
}
