# This file is the entry point used by the nix package manager.
# It declares package builds and development environments.
# See https://wiki.nixos.org/wiki/Flakes for more information on the `flake.nix` format.
# In case of questions, feel free to ask @DavHau
{
  inputs = {
    # nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs.url = "git+https://github.com/DavHau/nixpkgs?shallow=1&ref=dave";
    nixpkgs_22_05.url = "github:nixos/nixpkgs/nixos-22.05";
    nix-filter.url = "github:numtide/nix-filter";
    hdzero-goggle-buildroot.url = "git+https://github.com/bkleiner/hdzero-goggle-buildroot?shallow=1&submodules=1";
    hdzero-goggle-buildroot.flake = false;  # this input doesn't contain a flake.nix
    hdzero-goggle-linux-src.url = "git+https://github.com/DavHau/hdzero-goggle-linux?shallow=true&ref=hdzero";
    hdzero-goggle-linux-src.flake = false;
    # A similar board with several supported kernels.
    tinyvision-src.url = "git+https://github.com/YuzukiHD/TinyVision?shallow=true";
    tinyvision-src.flake = false;
  };
  outputs = {
    self,
    nixpkgs,
    nixpkgs_22_05,
    nix-filter,
    hdzero-goggle-buildroot,
    hdzero-goggle-linux-src,
    tinyvision-src,
  }: let
    # Currently can only support x86_64-linux builders, due to the hardcoded toolchain
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
    pkgsArm = import nixpkgs {
      system = "x86_64-linux";
      crossSystem = "armv7l-linux";
      config.pulseaudio = false;
      overlays = [(curr: prev: {
        ffmpeg = curr.ffmpeg_6-headless.override {
          withVaapi = false;
        };
        mpg123 = prev.mpg123.override {
          withPulse = false;
          withJack = false;
        };
        docker-compose = prev.docker-compose.overrideAttrs (old: {
          vendorHash = "sha256-6KLdDBuPiB/qh+3IfABu8Gvopu5ucTrNg9jh7G+cMss=";
        });
      })];
    };
    # Source code without the nix directory and flake files to improve build caching
    hdzero-goggle-src = nix-filter.lib {
      root = ./.;
      exclude = [ "nix" "flake.nix" "flake.lock" ];
    };
  in
  {
    # Packages that can be built via `nix build .#<name>`
    packages.${system} = {

      # make the goggle app the default package
      default = self.packages.${system}.goggle-app;

      # the goggle app including the jffs2 image with service binaries
      goggle-app = pkgs.callPackage ./nix/goggle-app.nix {
        inherit hdzero-goggle-src;
        inherit (self.packages.${system}) toolchain;
      };

      goggle-app-nix = pkgsArm.callPackage ./nix/goggle-app-nix {
        inherit hdzero-goggle-src nix-filter;
      };

      emulate = pkgs.callPackage ./nix/emulate {
        rootfs = self.packages.${system}.rootfs-nixos;
        pkgsLinux = nixpkgs_22_05.legacyPackages.${system}.pkgsCross.armv7l-hf-multiplatform;
        inherit (self.packages.${system}) kernel;
        # inherit hdzero-goggle-linux-src;
      };

      # the kernel built with nix
      kernel = nixpkgs_22_05.legacyPackages.${system}.pkgsCross.armv7l-hf-multiplatform.callPackage ./nix/kernel {
        inherit hdzero-goggle-linux-src;
        breakpointHook = pkgs.breakpointHook;
      };

      # linux kernel version 4.9.191 from a similar board which is properly open sourced
      kernel-tinyvision = nixpkgs_22_05.legacyPackages.${system}.pkgsCross.armv7l-hf-multiplatform.callPackage ./nix/kernel-tinyvision {
        inherit tinyvision-src;
        breakpointHook = pkgs.breakpointHook;
      };

      # only the rootfs etx2 image built by wrapping buildroot
      rootfs = pkgs.callPackage ./nix/rootfs {
        inherit hdzero-goggle-buildroot nix-filter;
        inherit (self.packages.${system}) kernel toolchain;
      };

      rootfs-nix = pkgs.callPackage ./nix/rootfs-nix {
        inherit (self.packages.${system}) hdzg-os-files;
        inherit hdzero-goggle-buildroot nix-filter;
        kernel = self.packages.${system}.kernel;
        goggle-app = self.packages.${system}.goggle-app-nix;
      };

      rootfs-nixos = pkgsArm.callPackage ./nix/rootfs-nixos {
        inherit hdzero-goggle-buildroot nix-filter;
        inherit (self.packages.${system}) hdzero-scripts;
        kernel = self.packages.${system}.kernel;
        goggle-app = self.packages.${system}.goggle-app-nix;
      };

      # sdcard containing:
      # - nix built kernel
      # - nix built goggle app
      # - buildroot built rootfs
      sdcard = pkgs.callPackage ./nix/sdcard {
        inherit hdzero-goggle-buildroot;
        inherit (self.packages.${system})
          goggle-app
          hdzero-goggle-tools
          kernel
          rootfs
          ;
        init = "/linuxrc";
      };

      # sdcard containing:
      # - nix built kernel
      # - nix built goggle app
      # - nix built rootfs
      sdcard-nix = self.packages.${system}.sdcard.override {
        goggle-app = self.packages.${system}.goggle-app-nix;
        rootfs = self.packages.${system}.rootfs-nix;
      };

      # sdcard with full blown nixos system
      sdcard-nixos = self.packages.${system}.sdcard.override {
        goggle-app = self.packages.${system}.goggle-app-nix;
        rootfs = self.packages.${system}.rootfs-nixos;
        init = "/init";
      };

      # filesystem extracted from the original HDZG_OS.bin
      hdzg-os-files = pkgs.callPackage ./nix/hdzg-os-files.nix {};

      # some bash scripts which teh goggle app depends on
      hdzero-scripts = pkgs.callPackage ./nix/hdzero-scripts {};

      # tools for creating a bootable image
      hdzero-goggle-tools = pkgs.callPackage ./nix/hdzero-goggle-tools.nix {};

      # legacy: patched upstream toolchain to make compatible with nix build sandbox
      toolchain = pkgs.callPackage ./nix/toolchain.nix {};

      # legacy: this is simply wrapping the full buildroot build from https://github.com/bkleiner/hdzero-goggle-buildroot
      # better use .#sdcard output instead
      # contains sdcard.img bootable image, as well as HDZ_OS.bin
      os-images = pkgs.callPackage ./nix/os-images.nix {
        inherit hdzero-goggle-src hdzero-goggle-buildroot hdzero-goggle-linux-src;
        inherit (self.packages.${system}) toolchain;
      };

      # webrtc library (experiment)
      libpeer = pkgs.callPackage ./nix/libpeer.nix {};

      # tools to extract files from ext images. currently not used.
      extfstools = pkgs.callPackage ./nix/extfstools.nix { };
    };

    # a dev environment which can be entered via `nix develop .`
    devShells.${system}.default = pkgs.callPackage ./nix/devShell.nix {
      inherit (self.packages.${system}) toolchain;
    };
  };
}
