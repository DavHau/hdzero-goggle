// SPDX-License-Identifier: GPL-2.0
/*
 * Reimplementation of the vendor hdzero.ko blob: sunxi-vin sensor driver for
 * the Divimath HDZero baseband, which feeds BT.1120 video into the V4L2
 * capture pipeline.  There is no register access; the driver only describes
 * the two timings (1280x720@60, 1920x1080@30, UYVY 16-bit bus) and hooks up
 * the cci/sensor_helper plumbing from vin_io.ko.  Symbol names and data
 * tables follow the blob.
 */

#include <linux/init.h>
#include <linux/module.h>
#include <linux/slab.h>
#include <linux/i2c.h>
#include <linux/delay.h>
#include <linux/videodev2.h>
#include <linux/io.h>
#include <media/v4l2-ctrls.h>
#include <media/v4l2-device.h>
#include <media/v4l2-mediabus.h>

#include "camera.h"
#include "sensor_helper.h"

MODULE_AUTHOR("lr");
MODULE_DESCRIPTION("A low-level driver for HDZero sensors");
MODULE_LICENSE("GPL");

#define DBG_INFO(format, args...) \
	(printk("[HDZERO INFO] LINE:%04d-->%s:" format, __LINE__, __func__, ##args))

#define SENSOR_FRAME_RATE 60
#define SENSOR_NAME "hdzero"

static struct cci_driver cci_drv = {
	.name = SENSOR_NAME,
	.addr_width = CCI_BITS_8,
	.data_width = CCI_BITS_8,
};

static int sensor_g_ctrl(struct v4l2_ctrl *ctrl)
{
	return -EINVAL;
}

static int sensor_s_ctrl(struct v4l2_ctrl *ctrl)
{
	return -EINVAL;
}

static int sensor_reset(struct v4l2_subdev *sd, u32 val)
{
	return 0;
}

static int sensor_detect(struct v4l2_subdev *sd)
{
	DBG_INFO("hdzero detect ok !!!\n");
	return 0;
}

static int sensor_init(struct v4l2_subdev *sd, u32 val)
{
	struct sensor_info *info = to_state(sd);

	sensor_detect(sd);

	info->focus_status = 0;
	info->low_speed = 0;
	info->width = HD720_WIDTH;
	info->height = HD720_HEIGHT;
	info->hflip = 0;
	info->vflip = 0;
	info->tpf.numerator = 1;
	info->tpf.denominator = SENSOR_FRAME_RATE;
	info->preview_first_flag = 1;

	return 0;
}

static int sensor_power(struct v4l2_subdev *sd, int on)
{
	switch (on) {
	case PWR_ON:
		DBG_INFO("CSI_SUBDEV_PWR_ON!\n");
		break;
	case PWR_OFF:
		DBG_INFO("CSI_SUBDEV_PWR_OFF!\n");
		break;
	case STBY_OFF:
	case STBY_ON:
		break;
	default:
		return -EINVAL;
	}

	return 0;
}

static long sensor_ioctl(struct v4l2_subdev *sd, unsigned int cmd, void *arg)
{
	struct sensor_info *info = to_state(sd);

	switch (cmd) {
	case GET_CURRENT_WIN_CFG:
		if (info->current_wins == NULL) {
			sensor_err("empty wins!\n");
			return -1;
		}
		memcpy(arg, info->current_wins,
		       sizeof(struct sensor_win_size));
		break;
	case SET_FPS:
		break;
	case VIDIOC_VIN_SENSOR_CFG_REQ:
		break;
	default:
		return -EINVAL;
	}

	return 0;
}

static int sensor_g_mbus_config(struct v4l2_subdev *sd,
				struct v4l2_mbus_config *cfg)
{
	cfg->type = V4L2_MBUS_BT656;
	cfg->flags = V4L2_MBUS_PCLK_SAMPLE_FALLING | CSI_CH_0;

	return 0;
}

static struct sensor_format_struct sensor_formats[] = {
	{
		.desc = "BT1120 1CH",
		.mbus_code = MEDIA_BUS_FMT_UYVY8_1X16,
		.regs = NULL,
		.regs_size = 0,
		.bpp = 1,
	},
};
#define N_FMTS ARRAY_SIZE(sensor_formats)

static struct sensor_win_size sensor_win_sizes[] = {
	{
		.width = HD720_WIDTH,
		.height = HD720_HEIGHT,
		.fps_fixed = 60,
		.regs = NULL,
		.regs_size = 0,
		.set_size = NULL,
	},
	{
		.width = HD1080_WIDTH,
		.height = HD1080_HEIGHT,
		.fps_fixed = 30,
		.regs = NULL,
		.regs_size = 0,
		.set_size = NULL,
	},
};
#define N_WIN_SIZES (ARRAY_SIZE(sensor_win_sizes))

static int sensor_s_stream(struct v4l2_subdev *sd, int enable)
{
	struct sensor_info *info = to_state(sd);
	struct sensor_win_size *wsize = info->current_wins;

	if (wsize == NULL || info->fmt == NULL) {
		sensor_err("empty wins!\n");
		return -EINVAL;
	}

	DBG_INFO("%s on = %d, %d*%d fps: %d code: %x\n", __func__, enable,
		 wsize->width, wsize->height, wsize->fps_fixed,
		 info->fmt->mbus_code);

	if (!enable)
		return 0;

	if (info->fmt->regs)
		sensor_write_array(sd, info->fmt->regs, info->fmt->regs_size);
	if (wsize->regs)
		sensor_write_array(sd, wsize->regs, wsize->regs_size);
	if (wsize->set_size)
		wsize->set_size(sd);

	info->width = wsize->width;
	info->height = wsize->height;

	return 0;
}

/* ----------------------------------------------------------------------- */

static const struct v4l2_ctrl_ops sensor_ctrl_ops = {
	.g_volatile_ctrl = sensor_g_ctrl,
	.s_ctrl = sensor_s_ctrl,
};

static const struct v4l2_subdev_core_ops sensor_core_ops = {
	.init = sensor_init,
	.reset = sensor_reset,
	.ioctl = sensor_ioctl,
	.s_power = sensor_power,
};

static const struct v4l2_subdev_video_ops sensor_video_ops = {
	.s_stream = sensor_s_stream,
	.g_parm = sensor_g_parm,
	.s_parm = sensor_s_parm,
	.g_mbus_config = sensor_g_mbus_config,
};

static const struct v4l2_subdev_pad_ops sensor_pad_ops = {
	.enum_mbus_code = sensor_enum_mbus_code,
	.enum_frame_size = sensor_enum_frame_size,
	.get_fmt = sensor_get_fmt,
	.set_fmt = sensor_set_fmt,
};

static const struct v4l2_subdev_ops sensor_ops = {
	.core = &sensor_core_ops,
	.video = &sensor_video_ops,
	.pad = &sensor_pad_ops,
};

/* ----------------------------------------------------------------------- */

static int sensor_probe(struct i2c_client *client,
			const struct i2c_device_id *id)
{
	struct v4l2_subdev *sd;
	struct sensor_info *info;
	struct v4l2_ctrl_handler *handler;
	struct v4l2_ctrl *ctrl;
	int ret;

	info = kzalloc(sizeof(struct sensor_info), GFP_KERNEL);
	if (info == NULL)
		return -ENOMEM;
	sd = &info->sd;

	ret = cci_dev_probe_helper(sd, client, &sensor_ops, &cci_drv);
	if (ret) {
		kfree(info);
		return ret;
	}

	handler = &info->handler;
	v4l2_ctrl_handler_init(handler, 2);

	v4l2_ctrl_new_std(handler, &sensor_ctrl_ops, V4L2_CID_GAIN,
			  1 * 1600, 256 * 1600, 1, 1 * 1600);
	ctrl = v4l2_ctrl_new_std(handler, &sensor_ctrl_ops, V4L2_CID_EXPOSURE,
				 0, 65536 * 16, 1, 0);
	if (ctrl != NULL)
		ctrl->flags |= V4L2_CTRL_FLAG_VOLATILE;

	if (handler->error) {
		ret = handler->error;
		v4l2_ctrl_handler_free(handler);
		cci_dev_remove_helper(client, &cci_drv);
		kfree(info);
		return ret;
	}

	sd->ctrl_handler = handler;

	mutex_init(&info->lock);

	info->fmt = &sensor_formats[0];
	info->fmt_pt = &sensor_formats[0];
	info->win_pt = &sensor_win_sizes[0];
	info->fmt_num = N_FMTS;
	info->win_size_num = N_WIN_SIZES;
	info->sensor_field = V4L2_FIELD_NONE;
	info->af_first_flag = 1;

	return 0;
}

static int sensor_remove(struct i2c_client *client)
{
	struct v4l2_subdev *sd;
	struct sensor_info *info;

	sd = cci_dev_remove_helper(client, &cci_drv);
	info = to_state(sd);
	v4l2_ctrl_handler_free(&info->handler);
	kfree(info);

	return 0;
}

static const struct i2c_device_id sensor_id[] = {
	{SENSOR_NAME, 0},
	{}
};
MODULE_DEVICE_TABLE(i2c, sensor_id);

static struct i2c_driver sensor_driver = {
	.driver = {
		.owner = THIS_MODULE,
		.name = SENSOR_NAME,
	},
	.probe = sensor_probe,
	.remove = sensor_remove,
	.id_table = sensor_id,
};

static __init int init_sensor(void)
{
	return cci_dev_init_helper(&sensor_driver);
}

static __exit void exit_sensor(void)
{
	cci_dev_exit_helper(&sensor_driver);
}

module_init(init_sensor);
module_exit(exit_sensor);
