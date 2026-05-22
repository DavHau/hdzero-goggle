# HDZero Goggle

Custom firmware for the HDZero FPV goggles (Allwinner sun8iw16p1 / armv7l,
kernel 4.9.118), built with Nix. Goal: re-implement the closed-source vendor
kernel modules.

## Closed-source kernel modules to re-implement

All `.ko` in `mkapp/app/ko/` are prebuilt vendor blobs; most have source in
the kernel fork. These do NOT:

| Blob                  | What it is                                              | Closest upstream base                |
|-----------------------|----------------------------------------------------------|--------------------------------------|
| `hdzero.ko`           | Divimath HDZero sensor driver (i2c, depends on `vin_io`) | none, reverse engineer               |
| `gpio_keys_hdzero.ko` | Modified gpio_keys, OF compatible `gpio-keys-hdzero`     | `drivers/input/keyboard/gpio_keys.c` |
| `nct75.ko`            | NCT75 temperature sensor (lm75 derivative)               | `drivers/hwmon/lm75.c`               |
| `w25q128.ko`          | SPI NOR flash for the FPGA (m25p80 derivative)           | `drivers/mtd/devices/m25p80.c`       |

References:
- `~/git/linux`: local checkout of the 4.9.118 vendor kernel (same rev as
  flake input `hdzero-goggle-linux-src`)
- `src/driver/`: userspace drivers (register maps, sequencing)
- `nix/sdcard/hdzero_goggle.dts`: compatibles, gpios, i2c addresses

## How modules end up in the image

- Blobs ship inside `app.ext2` (`nix/goggle-app-nix/`); the `hdzero` service
  (`machines/hdzero/modules/hdzero.nix`) insmods `/mnt/app/ko/*.ko` at boot.
- `nix/kernel-modules.nix` adds `gpio_keys_hdzero/hdzero/rotary_encoder.ko`
  blobs to the nix-built `lib/modules`, loaded via `boot.kernelModules`.
- `nix/sdcard/default.nix` assembles the image (u-boot, uImage, dtb,
  rootfs.ext2, app.ext2).

To replace a blob: wire the new module into `nix/kernel-modules.nix` /
`boot.kernelModules` and drop the blob from the copy list.

## Building

Run builds through pueue (slow). Full image: `nix build
.#packages.x86_64-linux.sdcard-nixos` — only needed for flashing, not for
module iteration.

## Module iteration (fast path, proven)

The goggle currently runs the **stock vendor firmware** (hostname `tina`,
minimal busybox). Our modules built from `~/git/linux` load there too
(vermagic `4.9.118 SMP preempt mod_unload ARMv7 thumb2 p2v8`).

```bash
nix develop .#kernel            # cross devshell (gcc 10, ARCH/CROSS_COMPILE set)
cd ~/git/linux
# one-time setup: cp <configfile printed by shellHook> .config
#                 touch .scmversion   # else vermagic gets a "+" suffix
make olddefconfig && make -j$(nproc) modules_prepare
make M=/path/to/hdzero-goggle/src/kmod/hello modules

scripts/goggle.py deploy-ko src/kmod/hello/hello.ko   # transfer + md5 + insmod + dmesg
```

Gotchas:
- Kernel source changes for the nix build: `--override-input
  hdzero-goggle-linux-src path:$HOME/git/linux`.
- `src/kmod/hello/` is the module template.

## Hardware access

- Serial console only, no network. Use `scripts/goggle.py` (stdlib-only,
  opens `/dev/ttyUSB0` directly): subcommands `run`, `push`, `pull`,
  `deploy-ko`, `dmesg`. Interactive: `tio /dev/ttyUSB0`. One process per
  port — stop tio before running goggle.py and vice versa.
- Console prompt `root@tina:/#` (stock fw, autologin). NixOS image: root
  password `openzero`.
- File transfer happens through the console (printf/hexdump on the goggle's
  minimal busybox), so it works on the stock firmware.
- Stock fw loads the blob modules at boot; `rmmod` before insmodding a
  replacement. On the NixOS image, `systemctl stop hdzero` first.
