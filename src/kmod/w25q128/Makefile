obj-m += w25q128.o

KERNELDIR ?= /lib/modules/$(shell uname -r)/build

modules modules_install clean:
	$(MAKE) -C $(KERNELDIR) M=$(CURDIR) $@
