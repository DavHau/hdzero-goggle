// Minimal test module to verify the out-of-tree build and serial deploy
// workflow against the 4.9.118 vendor kernel.
#include <linux/init.h>
#include <linux/module.h>

static int __init hello_init(void)
{
	pr_info("hello: hdzero hello world module loaded\n");
	return 0;
}

static void __exit hello_exit(void)
{
	pr_info("hello: unloaded\n");
}

module_init(hello_init);
module_exit(hello_exit);

MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("Hello world module for deploy testing");
