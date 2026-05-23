# HDZero Goggle

Custom firmware for the HDZero FPV goggles (Allwinner sun8iw16p1 / armv7l,
kernel 4.9.118), built with Nix. The closed-source vendor kernel modules are
reimplemented in `src/kmod/`; remaining kernel blob: `mcp3021.ko` (vendor
IIO driver, unused on this hardware, the battery voltage comes from the SoC
ADC). The Allwinner userspace media stack in `lib/softwinner/` is still
prebuilt.

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
  `hdzero-kmods`, loaded via `boot.kernelModules` (hdzero must come before
  vin_v4l2, which registers sensors at probe) and the `hdzero` service
  preStart. rotary_encoder is built into the kernel (CONFIG_ROTARY_ENCODER).
- Remaining blobs ship inside `app.ext2` (`nix/goggle-app-nix/`); the
  `hdzero` service still insmods `/mnt/app/ko/mcp3021.ko` from there.
- `nix/sdcard/default.nix` assembles the image (u-boot, uImage, dtb,
  rootfs.ext2, app.ext2).

## Building

Run builds through pueue (slow). Full image: `nix build
.#packages.x86_64-linux.sdcard-nixos` — only needed for flashing, not for
module iteration.

## Mainline kernel port (boot testing only)

- Port lives on the `v536-port` branch of https://github.com/Mic92/linux
  (local checkout: `~/git/linux-v536`); status in `docs/mainline.md`.
- Reproducible uImage from the pinned source: `nix build .#kernel-mainline`
  (`nix/kernel-mainline/default.nix`).
- Iteration: `nix develop .#kernel-mainline` +
  `scripts/build-mainline-uimage.sh` (uses `sun8i_v536_defconfig`,
  KERNEL_DIR overrides the checkout path).

## Module iteration (fast path, proven)

The goggle runs the **NixOS image** (hostname `hdzero`); modules built from
`~/git/linux` load on it and on the stock vendor firmware (hostname `tina`),
both use vermagic `4.9.118 SMP preempt mod_unload ARMv7 thumb2 p2v8`.

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
  port — stop tio before running goggle.py and vice versa. Handles both the
  stock busybox prompt and the NixOS bash prompt.
- NixOS image: root password `openzero`, app runs as the `hdzero` systemd
  service (`systemctl stop hdzero` before swapping modules, `journalctl -u
  hdzero` for app logs). Run `dmesg -n 1` first, kernel log spam on the
  console corrupts goggle.py output.
- Stock fw: prompt `root@tina:/#`, autologin; the blob modules are loaded at
  boot, `rmmod` before insmodding a replacement.
- File transfer happens through the console (printf/hexdump), so it works
  even on the stock firmware's minimal busybox.
