# This file is the entry point used by the nix package manager.
# It declares package builds and development environments.
# See https://wiki.nixos.org/wiki/Flakes for more information on the `flake.nix` format.
# In case of questions, feel free to ask @DavHau
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs_22_05.url = "github:nixos/nixpkgs/nixos-22.05";
    nix-filter.url = "github:numtide/nix-filter";
    hdzero-goggle-buildroot.url = "git+https://github.com/bkleiner/hdzero-goggle-buildroot?shallow=1&submodules=1";
    hdzero-goggle-buildroot.flake = false;  # this input doesn't contain a flake.nix
    hdzero-goggle-linux-src.url = "git+https://github.com/DavHau/hdzero-goggle-linux?shallow=true&ref=hdzero";
    hdzero-goggle-linux-src.flake = false;  # this input doesn't contain a flake.nix
  };
  outputs = {
    self,
    nixpkgs,
    nixpkgs_22_05,
    nix-filter,
    hdzero-goggle-buildroot,
    hdzero-goggle-linux-src,
  }: let
    # Currently can only support x86_64-linux builders, due to the hardcoded toolchain
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
    # Source code without the nix directory and flake files to improve build caching
    hdzero-goggle-src = nix-filter.lib {
      root = ./.;
      exclude = [ "nix" "flake.nix" "flake.lock" ];
    };
  in
  {
    # Packages that can be built via `nix build .#<name>`
    packages.${system} = {

      # the goggle app including the jffs2 image with service binaries
      goggle-app = pkgs.callPackage ./nix/goggle-app.nix {
        inherit hdzero-goggle-src;
        inherit (self.packages.${system}) toolchain;
      };

      # make the goggle app the default package
      default = self.packages.${system}.goggle-app;

      # patched toolchain to make compatible with nix build sandbox
      toolchain = pkgs.callPackage ./nix/toolchain.nix {};

      # the goggle emulator app to run on the dev machine
      goggle-app-emu = pkgs.callPackage ./nix/goggle-app-emu.nix {
        inherit hdzero-goggle-src;
      };

      # legacy: this is simply wrapping the full buildroot build from https://github.com/bkleiner/hdzero-goggle-buildroot
      # better use .#sdcard output instead
      # contains sdcard.img bootable image, as well as HDZ_OS.bin
      os-images = pkgs.callPackage ./nix/os-images.nix {
        inherit hdzero-goggle-src hdzero-goggle-buildroot hdzero-goggle-linux-src;
        inherit (self.packages.${system}) toolchain;
      };

      # only the rootfs etx2 image built by wrapping buildroot
      rootfs = pkgs.callPackage ./nix/rootfs {
        inherit hdzero-goggle-buildroot nix-filter;
        inherit (self.packages.${system}) kernel toolchain;
      };

      # tools for creating a bootable image
      hdzero-goggle-tools = pkgs.callPackage ./nix/hdzero-goggle-tools.nix {};

      # the kernel built with nix
      kernel =
      # builtins.trace pkgsArm.stdenv.hostPlatform.linux-kernel.target
      nixpkgs_22_05.legacyPackages.${system}.pkgsCross.armv7l-hf-multiplatform.callPackage ./nix/kernel {
        inherit hdzero-goggle-linux-src;
        breakpointHook = pkgs.breakpointHook;
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
      };
    };

    # a dev environment which can be entered via `nix develop .`
    devShells.${system}.default = pkgs.callPackage ./nix/devShell.nix {
      inherit (self.packages.${system}) toolchain;
    };
  };
}
