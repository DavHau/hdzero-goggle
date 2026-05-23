# This file is the entry point used by the nix package manager.
# It declares package builds and development environments.
# See https://wiki.nixos.org/wiki/Flakes for more information on the `flake.nix` format.
# In case of questions, feel free to ask @DavHau
{
  inputs = {
    # from nixos-25.11 on, systemd is incompatible with the outdated kernel 4.9 used by hdzero
    nixpkgs.url = "git+https://github.com/nixos/nixpkgs?shallow=1&ref=nixos-25.05";
    nixpkgs_unstable.url = "git+https://github.com/nixos/nixpkgs?shallow=1&ref=nixos-unstable";
    nixpkgs_22_05.url = "github:nixos/nixpkgs/nixos-22.05";
    nix-filter.url = "github:numtide/nix-filter";
    hdzero-goggle-buildroot.url = "git+https://github.com/bkleiner/hdzero-goggle-buildroot?shallow=1&submodules=1";
    hdzero-goggle-buildroot.flake = false; # this input doesn't contain a flake.nix
    hdzero-goggle-linux-src.url = "git+https://github.com/DavHau/hdzero-goggle-linux?shallow=1&ref=hdzero";
    hdzero-goggle-linux-src.flake = false;
    kernel-5-4-src.url = "git+https://github.com/DavHau/hdzero-goggle-linux?shallow=1&ref=tina54";
    kernel-5-4-src.flake = false;
    lvgl-src.url = "git+https://github.com/lvgl/lvgl?shallow=1&ref=refs/tags/v8.3.5";
    lvgl-src.flake = false;
    minIni-src.url = "git+https://github.com/compuphase/minIni?shallow=1";
    minIni-src.flake = false;
    # A similar board with several supported kernels.
    tinyvision-src.url = "git+https://github.com/YuzukiHD/TinyVision?shallow=1";
    tinyvision-src.flake = false;
  };
  outputs =
    {
      self,
      nixpkgs,
      nixpkgs_unstable,
      nixpkgs_22_05,
      nix-filter,
      hdzero-goggle-buildroot,
      hdzero-goggle-linux-src,
      lvgl-src,
      minIni-src,
      ...
    }:
    let
      # Currently can only support x86_64-linux builders, due to the hardcoded toolchain
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      lib = nixpkgs.lib;
      pkgsArm = import nixpkgs {
        system = "x86_64-linux";
        crossSystem = "armv7l-linux";
        config.pulseaudio = false;
        overlays = [
          (curr: prev: {
            ffmpeg = curr.ffmpeg_6-headless.override {
              withVaapi = false;
            };
            # patch needed for nixpkgs 25.11 (not yet used because systemd incompatibility)
            # ffmpeg =
            #   (curr.ffmpeg_6-headless.override {
            #     withVaapi = false;
            #   }).overrideAttrs
            #     (old: {
            #       patches = lib.filter (
            #         patch: !(lib.hasInfix "binutils" "${patch}" || lib.hasInfix "nvccflags-cpp14" "${patch}")
            #       ) prev.ffmpeg_6-headless.patches;
            #     });
            mpg123 = prev.mpg123.override {
              withPulse = false;
              withJack = false;
            };
          })
        ];
      };
      # Source code without the nix directory and flake files to improve build caching
      hdzero-goggle-src = nix-filter.lib {
        root = ./.;
        include = [
          "conf"
          "lib"
          "src"
          "CMakeLists.txt"
          "VERSION"
          "mkapp"
        ];
      };
    in
    {
      # Packages that can be built via `nix build .#<name>`
      packages.${system} = {

        # make the nix built goggle app the default package
        default = self.packages.${system}.goggle-app-nix;

        # goggle app built with nix
        goggle-app-nix = pkgsArm.callPackage ./nix/goggle-app-nix {
          inherit
            hdzero-goggle-src
            nix-filter
            minIni-src
            lvgl-src
            ;
        };

        # /lib/modules content: in-tree modules + hdzero-kmods + the
        # remaining rotary_encoder blob
        kernel-modules = pkgs.callPackage ./nix/kernel-modules.nix {
          inherit (self.packages.${system}) kernel hdzero-kmods;
        };

        # reimplemented vendor kernel modules (src/kmod)
        hdzero-kmods =
          nixpkgs_22_05.legacyPackages.${system}.pkgsCross.armv7l-hf-multiplatform.callPackage
            ./nix/hdzero-kmods
            {
              inherit hdzero-goggle-src hdzero-goggle-linux-src;
              inherit (self.packages.${system}) kernel;
            };

        # the kernel built with nix
        kernel =
          nixpkgs_22_05.legacyPackages.${system}.pkgsCross.armv7l-hf-multiplatform.callPackage ./nix/kernel
            {
              inherit hdzero-goggle-linux-src;
              breakpointHook = pkgs.breakpointHook;
            };

        # a busybox based rootfs ported to the nix build system
        # boots fast, but harder to extend (no nixos modules)
        rootfs-nix = pkgs.callPackage ./nix/rootfs-nix {
          inherit (self.packages.${system}) hdzg-os-files;
          inherit hdzero-goggle-buildroot nix-filter;
          kernel = self.packages.${system}.kernel;
          goggle-app = self.packages.${system}.goggle-app-nix;
        };

        # a actual nixos based rootfs
        # - TODO: fix slow boot time
        # - the nixos module system can be used to extend it
        rootfs-nixos = pkgsArm.callPackage ./nix/rootfs-nixos {
          inherit nix-filter;
          kernel = self.packages.${system}.kernel;
          goggle-app = self.packages.${system}.goggle-app-nix;
          machine = self.nixosConfigurations.hdzero;
        };

        # bootable sdcard image containing:
        # - nix built kernel
        # - nix built goggle app
        # - nix built rootfs
        sdcard-nix = pkgs.callPackage ./nix/sdcard {
          inherit hdzero-goggle-buildroot;
          inherit (self.packages.${system})
            hdzero-goggle-tools
            kernel
            ;
          goggle-app = self.packages.${system}.goggle-app-nix;
          rootfs = self.packages.${system}.rootfs-nix;
        };

        # sdcard with full blown nixos system
        sdcard-nixos = pkgs.callPackage ./nix/sdcard {
          inherit hdzero-goggle-buildroot;
          inherit (self.packages.${system})
            hdzero-goggle-tools
            kernel
            ;
          goggle-app = self.packages.${system}.goggle-app-nix;
          rootfs = self.packages.${system}.rootfs-nixos;
          init = "/init";
        };

        # useful to restore FPGA flash, if it got wiped for some reason (eg. no video)
        sdcard-recovery = pkgs.callPackage ./nix/sdcard-recovery.nix {
          inherit (self.packages.${system}) upstream-firmware-archive;
        };

        # used to extract files for different purposes
        upstream-firmware-archive = pkgs.fetchzip {
          url = "https://www.hd-zero.com/_files/archives/967e02_9e6db8079a354f86979994a4ed28ab59.zip?dn=HDZEROGOGGLE_Rev20250319.zip";
          hash = "sha256-x/6MKHIr4tvItMR2/+B03jkaPL3fpaMrtrA0l++gJYM=";
          stripRoot = false;
        };

        # filesystem extracted from the original HDZG_OS.bin
        hdzg-os-files = nixpkgs_unstable.legacyPackages.x86_64-linux.callPackage ./nix/hdzg-os-files.nix {
          inherit (self.packages.${system}) upstream-firmware-archive;
        };

        # some bash scripts which the goggle app depends on
        hdzero-scripts = pkgs.callPackage ./nix/hdzero-scripts { };

        # tools for creating a bootable image
        hdzero-goggle-tools = pkgs.callPackage ./nix/hdzero-goggle-tools.nix { };

        # tiny cli tool to query ini options via shell scripts
        # useful to write systemd services depending on ini settings
        ini-read = pkgsArm.callPackage ./packages/ini-read {
          inherit minIni-src;
        };

        # mainline kernel (v7.0.9 + V536 port) — boot-test uImage only
        kernel-mainline = pkgsArm.callPackage ./nix/kernel-mainline { };
      };

      # check all packages in CI-pipeline
      checks.${system} = self.packages.${system};

      # a dev environment which can be entered via `nix develop .`
      devShells.${system} = {
        default = pkgs.callPackage ./nix/devShell.nix {
          # inherit (self.packages.${system}) toolchain;
        };

        # cross dev shell for building a mainline kernel for the V536 port:
        # `nix develop .#kernel-mainline`
        kernel-mainline = pkgsArm.callPackage ./nix/devShell-kernel-mainline.nix { };

        # cross dev shell for building the vendor kernel / modules in a local
        # kernel checkout: `nix develop .#kernel`
        kernel =
          nixpkgs_22_05.legacyPackages.${system}.pkgsCross.armv7l-hf-multiplatform.callPackage
            ./nix/devShell-kernel.nix
            {
              inherit (self.packages.${system}) kernel;
            };
      };

      # the nixos configuration for the nixos based version of the goggle os
      nixosConfigurations.hdzero = lib.nixosSystem {
        specialArgs = {
          packages = self.packages.${system};
        };
        modules = [
          {
            nixpkgs.pkgs = pkgsArm;
            nixpkgs.system = "armv7l-linux";
            imports = [ ./machines/hdzero/configuration.nix ];
          }
        ];
      };

      # different experiments non essential to the main build
      # kept for future reference and debuggin purposes only
      experiments.${system} = import ./nix/experiments.nix {
        inherit
          self
          pkgs
          pkgsArm
          system
          ;
        inherit (self) inputs;
      };
    };
}
