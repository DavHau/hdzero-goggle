obj-m += hdzero.o

ccflags-y += -I$(srctree)/drivers/media/platform/sunxi-vin/modules/sensor
ccflags-y += -I$(srctree)/drivers/media/platform/sunxi-vin

KERNELDIR ?= /lib/modules/$(shell uname -r)/build

modules modules_install clean:
	$(MAKE) -C $(KERNELDIR) M=$(CURDIR) $@
