{
  init ? "/init",
}:
''
initcall_debug=0
console=ttyS0,115200
init=${init}
loglevel=8
cma=32M
ion_carveout_list=512M@1024M

nand_root=/dev/nandd
mmc_root=/dev/mmcblk0p2
nor_root=/dev/mtdblock2

setargs_nor=setenv bootargs initcall_debug=''${initcall_debug} console=''${console} loglevel=''${loglevel} root=''${nor_root}  init=''${init} partitions=''${partitions} cma=''${cma} ion_carveout_list=''${ion_carveout_list}
setargs_nand=setenv bootargs initcall_debug=''${initcall_debug} console=''${console} loglevel=''${loglevel} root=''${nand_root} init=''${init} partitions=''${partitions} cma=''${cma} ion_carveout_list=''${ion_carveout_list}
setargs_mmc=setenv bootargs initcall_debug=''${initcall_debug} console=''${console} loglevel=''${loglevel} root=''${mmc_root} init=''${init} partitions=''${partitions} cma=''${cma} ion_carveout_list=''${ion_carveout_list} rootwait

boot_normal=sunxi_flash read 45000000 boot;bootm 45000000
boot_recovery=sunxi_flash read 45000000 recovery;bootm 45000000 recovery

bootdelay=5
bootcmd=run setargs_mmc boot_normal
''
