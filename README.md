# Custom HDZero Goggle Firmware

This project is a fork of [hd-zero/hdzero-goggle](https://github.com/hd-zero/hdzero-goggle)

The motivation of this project is to build an open source based firmware, unlike the original which is largely closed.

The following software components have never been publicly released by hdzero:
- the source of the custom linux kernel
- drivers / kernel modules
- the kernel build configuration
- tools or scripts to build a working root fs
- tools or scripts to build a bootable image

In order to make this project work, as of now, the above components are either replaced by open source alternatives from similar projects or by re-using binaries extracted from the original firmware. This is far from optimal. Many things can hardly be improved without access to the original source code.

A lot of foundational work was taken from these projects:
- [bkleiner/hdzero-goggle-buildroot](https://github.com/bkleiner/hdzero-goggle-buildroot)
- [bkleiner/hdzero-goggle-linux](https://github.com/bkleiner/hdzero-goggle-linux)

Currently Not Working:
- wifi

## Features of this firmware
This firmware includes all features of the original firmware, plus:
- declarative configuration: settings can be modified on PC via sdcard
- mDNS: connect to goggle via `hdzero.local` instead of `192.168.X.X`

## Contents of this repo
TODO

## Using this firmware

Build a bootable image and flash it to an sd-card (see below).
This way, the internal rootfs stays untouched and you can revert back to the original OS at any time by simply unplugging the sd-card.

## Building the firmware

The nix build system is used to build the firmware.
Make sure that nix [is installed](https://nixos.org/download/), and the [flakes feature](https://wiki.nixos.org/wiki/Flakes) is enabled.  

### Build bootable sd-card image

Use this command to build a bootable image to flash to an sd-card

```shellSession
nix build .#sdcard
```

The image can be found under `./result/sd-card.img` 

### Build firmware app only

When developing on the firmware app, reflashing the whole sdacrd image each time would be tedious.
Use this command to build only the firmware app:

```shellSession
nix build .#goggle-app
```

Tha app can be found under `./result/HDZGOGGLE` and be copied onto to the goggles.

### Execute the firmware app via ssh

Use the script `./utilities/ssh-deploy.sh` inside this repo to temporarily run a custom build of the `HDZGOGGLE` executable on the goggles.

Setup:

1. Have the [HDZero Expansion Module](https://www.hd-zero.com/product-page/hdzero-goggle-expansion-module) installed, as this provides wifi capabilities
2. Enable the wifi via the goggle menu and connect it to a network which is reachable from the dev machine
3. Enter the wifi menu again on the goggle to find its IP address (for example `192.168.1.5`)
3. Execute `./utilities/ssh-deploy.sh <host> <HDZGOGGLE_binary>`

Example:
```shellSession
./utilities/ssh-deploy.sh root@192.168.1.5 ./build/HDZGOGGLE
```

A powercycle will switch the goggles back to the builtin `HDZGOGGLE`.

