# Mainline kernel port (Allwinner V536 / sun8iw16p1)

Status: research. Mainline has no V536 SoC support — only fallback
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
5. Everything else (display/VDPO, CSI/ISP, video engine, audio) is
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
