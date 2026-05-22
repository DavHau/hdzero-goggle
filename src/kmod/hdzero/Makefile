obj-m += hdzero.o

# Full kernel source for the sunxi-vin headers; the pruned $(srctree) of the
# nix kernel dev output lacks drivers/, so the nix build overrides this.
LINUX_SRC ?= $(srctree)
ccflags-y += -I$(LINUX_SRC)/drivers/media/platform/sunxi-vin/modules/sensor
ccflags-y += -I$(LINUX_SRC)/drivers/media/platform/sunxi-vin
# for include/linux/ion.h, which includes drivers/staging/... relative paths
ccflags-y += -I$(LINUX_SRC)/include/linux

KERNELDIR ?= /lib/modules/$(shell uname -r)/build

modules modules_install clean:
	$(MAKE) -C $(KERNELDIR) M=$(CURDIR) $@
