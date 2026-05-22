// SPDX-License-Identifier: GPL-2.0
/*
 * Reimplementation of the vendor nct75.ko blob: IIO driver for the NCT75
 * temperature sensor at i2c address 0x48, exposing the temperature register
 * as two "voltage" channels (integer degrees * 10 plus the signed high
 * nibble of the LSB).  Symbol names follow the blob to keep decompiler diffs
 * small; channel layout and scaling must not change, the goggle app reads
 * the raw sysfs values directly.
 */

#include <linux/i2c.h>
#include <linux/iio/iio.h>
#include <linux/module.h>

struct nct75_state {
	struct i2c_client *client;
};

static const unsigned short normal_i2c[] = { 0x48, I2C_CLIENT_END };

static int ad7152_read_raw(struct iio_dev *indio_dev,
			   struct iio_chan_spec const *chan, int *val,
			   int *val2, long mask)
{
	struct nct75_state *st = iio_priv(indio_dev);
	struct i2c_client *client = st->client;
	int data;

	if (mask != IIO_CHAN_INFO_RAW)
		return -EINVAL;

	data = i2c_smbus_read_word_data(client, 0x00);
	if (data < 0)
		return data;

	/*
	 * The sensor sends MSB (integer degrees) first, so it ends up in the
	 * low byte of the smbus word; the fraction is the high nibble of the
	 * second byte.
	 */
	*val = (data & 0xff) * 10 + ((s8)(data >> 8) >> 4);
	return IIO_VAL_INT;
}

static const struct iio_info ad7152_info = {
	.driver_module = THIS_MODULE,
	.read_raw = ad7152_read_raw,
};

static const struct iio_chan_spec ad7152_channels[] = {
	{
		.type = IIO_VOLTAGE,
		.indexed = 1,
		.channel = 0,
		.info_mask_separate = BIT(IIO_CHAN_INFO_RAW),
	},
	{
		.type = IIO_VOLTAGE,
		.indexed = 1,
		.channel = 1,
		.info_mask_separate = BIT(IIO_CHAN_INFO_RAW),
	},
};

static int mir3da_detect(struct i2c_client *client,
			 struct i2c_board_info *info)
{
	strlcpy(info->type, "nct75", I2C_NAME_SIZE);
	return 0;
}

static int foo_probe(struct i2c_client *client,
		     const struct i2c_device_id *id)
{
	struct iio_dev *indio_dev;
	struct nct75_state *st;

	indio_dev = devm_iio_device_alloc(&client->dev, sizeof(*st));
	if (!indio_dev)
		return -ENOMEM;

	i2c_set_clientdata(client, indio_dev);
	st = iio_priv(indio_dev);
	st->client = client;

	indio_dev->name = id->name;
	indio_dev->dev.parent = &client->dev;
	indio_dev->info = &ad7152_info;
	indio_dev->channels = ad7152_channels;
	indio_dev->num_channels = ARRAY_SIZE(ad7152_channels);
	indio_dev->modes = INDIO_DIRECT_MODE;

	return devm_iio_device_register(&client->dev, indio_dev);
}

static const struct i2c_device_id foo_idtable[] = {
	{ "nct75", 0 },
	{ }
};
MODULE_DEVICE_TABLE(i2c, foo_idtable);

static struct i2c_driver foo_driver = {
	.class = I2C_CLASS_HWMON | I2C_CLASS_SPD,
	.driver = {
		.name = "nct75",
	},
	.probe = foo_probe,
	.id_table = foo_idtable,
	.detect = mir3da_detect,
	.address_list = normal_i2c,
};
module_i2c_driver(foo_driver);

MODULE_AUTHOR("wangkai");
MODULE_DESCRIPTION("divimath");
MODULE_LICENSE("GPL v2");
