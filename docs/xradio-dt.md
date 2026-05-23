# XR819 devicetree requirements (mainline kernel)

The XR819 wifi chip sits on SDIO bus mmc1. The vendor kernel uses a
platform driver (`sunxi-wlan`) for power sequencing; mainline uses
standard `mmc-pwrseq-simple` instead.

## Hardware facts (from `docs/hw-reference/`)

| Signal        | Vendor GPIO | Pin  | Direction | Notes                              |
|---------------|-------------|------|-----------|------------------------------------|
| wlan_regon    | gpio-200    | PG8  | out, hi   | Module enable / reset (active-low) |
| wlan_hostwake | gpio-201    | PG9  | in, hi    | Wake interrupt (EINT, mul-sel=6)   |

- **SDIO bus**: mmc1, pins PG0–PG5 (sdc1 function)
- **Bus number**: 1 (`wlan_busnum`)
- **Power**: `io_regulator_name = vcc33-wifi` in vendor dts, but no
  regulator is actually instantiated (dmesg: "dummy supplies not
  allowed"). The 3.3 V rail is `axp2101_dcdc1` (always-on, 3300 mV).
  No separate LDO for wifi — `wlan_power_num = -1`.
- **Clock**: none (`clk_name` is empty); XR819 has an internal oscillator.
- **chip_en**: not present ("get gpio chip_en failed").

## Required DT snippet

Add to the mainline dts (e.g. `sun8i-v536-hdzero-goggle.dts`):

```dts
/ {
	wifi_pwrseq: wifi-pwrseq {
		compatible = "mmc-pwrseq-simple";
		/* PG8 active-low: assert to reset, deassert to enable */
		reset-gpios = <&pio 6 8 GPIO_ACTIVE_LOW>;
	};
};

&mmc1 {
	pinctrl-names = "default";
	pinctrl-0 = <&mmc1_pins>;
	vmmc-supply = <&reg_dcdc1>;   /* axp2101_dcdc1, 3.3 V */
	bus-width = <4>;
	non-removable;
	keep-power-in-suspend;
	mmc-pwrseq = <&wifi_pwrseq>;
	status = "okay";

	xr819: wifi@1 {
		reg = <1>;
		compatible = "xradio,xr819";
		interrupt-parent = <&pio>;
		/* PG9 / pg_eint9, active-high edge */
		interrupts = <6 9 IRQ_TYPE_EDGE_RISING>;
		interrupt-names = "host-wake";
	};
};
```

The `mmc1_pins` node (PG0–PG5, function 2 = mmc1) should already exist
or be added to the pinctrl section:

```dts
&pio {
	mmc1_pins: mmc1-pins {
		pins = "PG0", "PG1", "PG2", "PG3", "PG4", "PG5";
		function = "mmc1";
		drive-strength = <30>;
		bias-pull-up;
	};
};
```

## Kernel config additions

The mainline kernel (`nix/kernel-mainline-nixos/nixos.config`) already
enables CFG80211 and MAC80211. Additional options needed:

```
CONFIG_MMC_PWRSEQ_SIMPLE=y
```

Verify these are set (likely already `=y` from `sun8i_v536_defconfig`):

```
CONFIG_MMC_SUNXI=y       # Allwinner MMC host
CONFIG_CFG80211=m        # already in nixos.config
CONFIG_MAC80211=m        # already in nixos.config
```

## Notes

- The vendor `sunxi-wlan` driver toggles `wlan_regon` (PG8) high to
  power-on the module before SDIO scan. The mainline `mmc-pwrseq-simple`
  does the same via `reset-gpios` (active-low polarity = deassert-high
  on probe).
- `wlan_hostwake` (PG9) is the out-of-band SDIO interrupt. The xradio
  driver uses it for host wakeup; without it, wifi still works but
  suspend/resume may not.
- `vcc33-wifi` may need a fixed-regulator node if `reg_dcdc1` is not
  available as a supply. On this board dcdc1 is the main 3.3 V rail
  powering everything, so a `regulator-always-on` fixed-regulator alias
  works fine as vmmc-supply.
