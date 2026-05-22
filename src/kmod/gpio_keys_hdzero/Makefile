obj-m += gpio_keys_hdzero.o

KERNELDIR ?= /lib/modules/$(shell uname -r)/build

modules modules_install clean:
	$(MAKE) -C $(KERNELDIR) M=$(CURDIR) $@
