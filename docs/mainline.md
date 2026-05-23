# Mainline kernel port (Allwinner V536 / sun8iw16p1)

Status: boots NixOS on the goggle. The port lives on the
`v536-port` branch of https://github.com/Mic92/linux (based on stable
v7.0.9, 25 patches): machine support, PIO/R-PIO pinctrl, CCU + PRCM
(sunxi-ng), DMA, SID efuse, thermal sensor + throttling, RTC (provides
LOSC/IOSC), USB (phy + MUSB peripheral mode), AXP2101 PMIC over RSB (mfd +
regulators), cpufreq (OPP 600-1104 MHz, DCDC2 supply), GPADC (RSSI input,
not battery), and a devicetree with uart0, mmc0/1, i2c0-3 + RSB, spi0
(FPGA flash), watchdog. Verified on hardware: serial console, SD card
rootfs, systemd + sshd, PMIC regulators, RTC, watchdog, thermal,
SPI-NOR probe. Bring-up findings: the PMIC sits on the RSB bus (boot0
switches it away from I2C) and the RSB interrupt is GIC SPI 114, not the
140 claimed by the BSP devicetree.
Build the flashable image with `nix build .#sdcard-nixos-mainline`
(kernel package: `.#kernel-mainline-nixos`), or use
`nix develop .#kernel-mainline` + `scripts/build-mainline-uimage.sh`
(KERNEL_DIR points to a local checkout of that branch) for iterative
development. The vendor boot chain is kept; u-boot loads the kernel
from partition 1 and the devicetree from the config FAT partition
(`kernel.dtb`) and applies the bootargs from env.cfg to it (the BSP
u-boot ignores bootm's fdt argument, so the image overwrites the
staging buffer at 0x7cfd1b20 in boot_normal).

## NixOS image with the mainline kernel

The mainline kernel is also packaged as a real NixOS kernel
(`nix build .#kernel-mainline-nixos`, `nix/kernel-mainline-nixos/`): the
board defconfig is expanded to a full `.config` and merged with a small
NixOS/systemd fragment (`nixos.config`: CRYPTO_HMAC/SHA256, TMPFS_XATTR,
namespaces, ext4 ACL/security xattrs, loop, /proc/config.gz). The
`hdzero-mainline` nixosConfiguration
(`machines/hdzero-mainline/configuration.nix`) uses it via
`boot.kernelPackages` and drops everything vendor specific (goggle app,
hdzero/xradio kernel modules, sunxi_dump pokes); what remains is a serial
console getty, sshd and basic tools. There is no initrd
(`boot.initrd.enable = false`), the kernel mounts root=/dev/mmcblk0p2
directly like the product image.

Build the SD card image with `nix build .#sdcard-nixos-mainline`; the
layout is identical to the product image (vendor boot0 + u-boot, uImage
on partition 1, NixOS rootfs on partition 2, config FAT on partition 3).
The DTB ships as `kernel.dtb` on the config FAT, not appended to the
uImage (`nix/kernel-mainline-nixos/uimage.nix`).

What works (verified on hardware): serial console, SD card rootfs,
systemd + sshd, PMIC (AXP2101 over RSB) with regulators, watchdog,
thermal, RTC, SPI-NOR probe, cpufreq. A `topfan` oneshot service spins
the top fan at a fixed duty since the goggle app is not running. What
does not: display/VDPO, video pipeline (CSI/ISP/VE), audio, the goggle
app and the xradio wifi - all of these need the vendor 4.9 stack.

Previous findings: Mainline has no V536 SoC support — only fallback
compatibles for individual IP blocks ("allwinner,sun8i-v536-i2c",
"...-mbus" referenced by H616/A100/D1). The earlier 6.12 boot attempt
stalled because pinctrl waits for the "pio"/"cpurpio" clocks and nothing
provides them (see misc/notes_davhau.txt); the SD card never probes as a
consequence, not as the root cause.

## What has to be written

1. CCU driver (sunxi-ng style) for the main clock unit, translated from
   the vendor table driver `drivers/clk/sunxi/clk-sun8iw16{.c,.h,_tbl.c}`.
2. PRCM/R-CCU driver (cpurpio, r_pio, cpus clocks).
3. Pin tables `pinctrl-sun8i-v536.c` and the R variant, translated from
   `drivers/pinctrl/sunxi/pinctrl-sun8iw16p1{,-r}.c` (mechanical).
4. `sun8i-v536.dtsi` + hdzero goggle board dts. Minimal first target:
   uart0 console, mmc0 rootfs, gic, timers.
5. Still missing / open questions: SoC PWM driver (new multi-channel IP,
   no mainline match - but the goggle does not use it, the fan is on I2C
   0x64 / DM5680), audio codec, battery readout (external MCP3021 on I2C,
   not the SoC GPADC), AXP2101 power-key/NMI interrupt (not wired up yet),
   thermal calibration (efuse not burned), USB gadget test, config
   slimming.
6. Everything else (display/VDPO, CSI/ISP, video engine) is
   vendor-specific and a separate, much larger effort.

## Reference data

- `docs/hw-reference/`: dumps from the running vendor 4.9 kernel
  (clk_summary, pinmux, gpio, iomem, interrupts, mmc ios).
- Vendor 4.9 sources: clk-sun8iw16, pinctrl-sun8iw16p1, sunxi-mmc,
  arch/arm/boot/dts/sun8iw16p1.dtsi (in the kernel fork).
- mmc0 (SD slot) runs at 50 MHz, 4-bit, 3.3 V, sd high-speed; sdmmc0_mod
  clock 100 MHz from pll_periph1x2; controller at 0x04020000, irq 46.
- CCU at 0x03001000, PRCM at 0x07010000, pio at 0x0300b000,
  r_pio at 0x07022000, uart0 at 0x05000000.
- PMIC is an AXP2101 (regulator/charger, see regulators-4.9.txt); cpufreq
  OPPs 600-1104 MHz on dcdc2. Not needed for the first boot milestone,
  but check mainline AXP2101 support before touching cpufreq/charging.
