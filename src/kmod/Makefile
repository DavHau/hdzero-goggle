obj-m += nct75/
obj-m += w25q128/
obj-m += gpio_keys_hdzero/
obj-m += hdzero/

KERNELDIR ?= /lib/modules/$(shell uname -r)/build

modules modules_install clean:
	$(MAKE) -C $(KERNELDIR) M=$(CURDIR) $@
