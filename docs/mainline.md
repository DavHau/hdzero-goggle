# Mainline kernel port (Allwinner V536 / sun8iw16p1)

Status: drivers written, untested on hardware. The port lives on the
`v536-port` branch of https://github.com/Mic92/linux (based on stable
v7.0.9, 25 patches): machine support, PIO/R-PIO pinctrl, CCU + PRCM
(sunxi-ng), DMA, SID efuse, thermal sensor + throttling, RTC (provides
LOSC/IOSC), USB (phy + MUSB peripheral mode), AXP2101 PMIC (mfd +
regulators), cpufreq (OPP 600-1104 MHz, DCDC2 supply), GPADC (RSSI input,
not battery), and a devicetree with uart0, mmc0/1, i2c0-3 + R_I2C, spi0
(FPGA flash), watchdog. Everything is compile-tested only; an adversarial
review round against the BSP sources and the hardware register dumps fixed
the known bugs (MMC clock gate, watchdog IRQ, i2c3 pins, MUSB endpoints).
Build with
`nix develop .#kernel-mainline` + `scripts/build-mainline-uimage.sh`
(KERNEL_DIR points to a local checkout of that branch), boot via the
vendor u-boot (`loady` + `bootm`, or repack the SD image).

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
   not the SoC GPADC), AXP2101 power-key IRQ polarity (vendor uses GIC SPI
   104 level, needs hardware test), thermal calibration (efuse not burned),
   config slimming, nix packaging, hardware boot test.
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
