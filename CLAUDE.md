# HDZero Goggle

Custom firmware for the HDZero FPV goggles (Allwinner sun8iw16p1 / armv7l,
kernel 4.9.118), built with Nix. Goal: re-implement the closed-source vendor
kernel modules.

## Reimplemented vendor kernel modules

All `.ko` in `mkapp/app/ko/` are prebuilt vendor blobs; most have source in
the kernel fork. The four without source are reimplemented in `src/kmod/`
(verified on hardware against the blobs, except w25q128 which targets our
kernel only — the stock kernel uses a newer spi-nor API):

| Blob                  | What it is                                                | Replacement                  |
|-----------------------|------------------------------------------------------------|------------------------------|
| `hdzero.ko`           | sunxi-vin sensor driver for the HDZero baseband (BT.1120)  | `src/kmod/hdzero/`           |
| `gpio_keys_hdzero.ko` | gpio_keys renamed to OF compatible `gpio-keys-hdzero`      | `src/kmod/gpio_keys_hdzero/` |
| `nct75.ko`            | NCT75 temperature sensor as IIO "voltage" channels         | `src/kmod/nct75/`            |
| `w25q128.ko`          | m25p80 trimmed to Winbond parts (FPGA SPI NOR)             | `src/kmod/w25q128/`          |

Still closed: `libota-burnboot.so` (userspace).

They are built as `packages.hdzero-kmods` (out-of-tree against the nix
kernel) and land in the image via `nix/kernel-modules.nix` and the `hdzero`
service (`machines/hdzero/modules/hdzero.nix`).

References:
- `~/git/linux`: local checkout of the 4.9.118 vendor kernel (same rev as
  flake input `hdzero-goggle-linux-src`)
- `src/driver/`: userspace drivers (register maps, sequencing)
- `nix/sdcard/hdzero_goggle.dts`: compatibles, gpios, i2c addresses

## How modules end up in the image

- `nix/kernel-modules.nix` = in-tree modules from the nix kernel +
  `hdzero-kmods` + the remaining `rotary_encoder.ko` blob, loaded via
  `boot.kernelModules` and the `hdzero` service preStart.
- Remaining blobs ship inside `app.ext2` (`nix/goggle-app-nix/`); the
  `hdzero` service still insmods `/mnt/app/ko/mcp3021.ko` from there.
- `nix/sdcard/default.nix` assembles the image (u-boot, uImage, dtb,
  rootfs.ext2, app.ext2).

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
