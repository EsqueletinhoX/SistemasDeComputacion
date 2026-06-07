#include <linux/module.h>
#include <linux/init.h>
#include <linux/fs.h>
#include <linux/cdev.h>
#include <linux/device.h>
#include <linux/uaccess.h>
#include <linux/timer.h>
#include <linux/jiffies.h>
#include <linux/spinlock.h>

#define DEVICE_NAME "SdeC_drv5"
#define CLASS_NAME  "SdeC_class"
#define ADC_MAX     4095          /* sensor simulado de 12 bits */

MODULE_LICENSE("GPL");
MODULE_AUTHOR("Juan");
MODULE_DESCRIPTION("CDD TP5 - 2 senales, timer 1s, seleccion de canal");

static dev_t dev_num;
static struct cdev my_cdev;
static struct class *my_class;

static struct timer_list sample_timer;
static spinlock_t lock;

static int channel;               /* 0 o 1: senal seleccionada */
static int latest;                /* ultimo valor muestreado */
static unsigned long tick;        /* segundos transcurridos */

/* Valor crudo de cada senal en el segundo t */
static int signal_value(int ch, unsigned long t)
{
    if (ch == 0)
        return (int)((t % 16) * 256);          /* diente de sierra */
    else
        return ((t % 10) < 5) ? 500 : 3500;    /* onda cuadrada */
}

/* Se ejecuta cada 1 s: muestrea el canal activo y se re-arma */
static void sample_cb(struct timer_list *t)
{
    spin_lock(&lock);
    tick++;
    latest = signal_value(channel, tick);
    spin_unlock(&lock);

    mod_timer(&sample_timer, jiffies + HZ);    /* HZ jiffies = 1 segundo */
}

static int my_open(struct inode *inode, struct file *file) { return 0; }
static int my_release(struct inode *inode, struct file *file) { return 0; }

static ssize_t my_read(struct file *file, char __user *buf, size_t len, loff_t *off)
{
    char tmp[16];
    int val, n;

    if (*off > 0)                 /* ya entregamos el valor en esta apertura */
        return 0;                 /* -> EOF, para que cat termine */

    spin_lock_bh(&lock);
    val = latest;
    spin_unlock_bh(&lock);

    n = scnprintf(tmp, sizeof(tmp), "%d\n", val);
    if (len < (size_t)n)
        return -EINVAL;
    if (copy_to_user(buf, tmp, n))
        return -EFAULT;

    *off += n;
    return n;
}

static ssize_t my_write(struct file *file, const char __user *buf, size_t len, loff_t *off)
{
    char c;

    if (len < 1)
        return -EINVAL;
    if (copy_from_user(&c, buf, 1))
        return -EFAULT;
    if (c != '0' && c != '1') {
        pr_warn("SdeC_drv5: canal invalido (use 0 o 1)\n");
        return -EINVAL;
    }

    spin_lock_bh(&lock);
    channel = c - '0';
    tick = 0;                     /* reiniciamos la fase de la nueva senal */
    latest = signal_value(channel, tick);
    spin_unlock_bh(&lock);

    pr_info("SdeC_drv5: canal seleccionado = %d\n", channel);
    return len;
}

static const struct file_operations fops = {
    .owner   = THIS_MODULE,
    .open    = my_open,
    .release = my_release,
    .read    = my_read,
    .write   = my_write,
};

static int __init drv_init(void)
{
    int ret;

    spin_lock_init(&lock);

    ret = alloc_chrdev_region(&dev_num, 0, 1, DEVICE_NAME);
    if (ret < 0)
        return ret;
    pr_info("SdeC_drv5: major=%d minor=%d\n", MAJOR(dev_num), MINOR(dev_num));

    cdev_init(&my_cdev, &fops);
    my_cdev.owner = THIS_MODULE;
    ret = cdev_add(&my_cdev, dev_num, 1);
    if (ret < 0) {
        unregister_chrdev_region(dev_num, 1);
        return ret;
    }

    my_class = class_create(CLASS_NAME);
    if (IS_ERR(my_class)) {
        cdev_del(&my_cdev);
        unregister_chrdev_region(dev_num, 1);
        return PTR_ERR(my_class);
    }
    device_create(my_class, NULL, dev_num, NULL, DEVICE_NAME);

    timer_setup(&sample_timer, sample_cb, 0);
    mod_timer(&sample_timer, jiffies + HZ);

    pr_info("SdeC_drv5: cargado, muestreando canal %d cada 1s\n", channel);
    return 0;
}

static void __exit drv_exit(void)
{
    del_timer_sync(&sample_timer);
    device_destroy(my_class, dev_num);
    class_destroy(my_class);
    cdev_del(&my_cdev);
    unregister_chrdev_region(dev_num, 1);
    pr_info("SdeC_drv5: descargado\n");
}

module_init(drv_init);
module_exit(drv_exit);
