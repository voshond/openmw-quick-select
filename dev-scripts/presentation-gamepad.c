#define _GNU_SOURCE

#include <errno.h>
#include <fcntl.h>
#include <linux/input-event-codes.h>
#include <linux/uinput.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <unistd.h>

static void fail(const char *message)
{
    perror(message);
    exit(EXIT_FAILURE);
}

static void enable_key(int fd, int key)
{
    if (ioctl(fd, UI_SET_KEYBIT, key) < 0)
        fail("UI_SET_KEYBIT");
}

static void enable_axis(int fd, int axis, int minimum, int maximum)
{
    struct uinput_abs_setup setup = {
        .code = axis,
        .absinfo = {
            .minimum = minimum,
            .maximum = maximum,
            .flat = 0,
        },
    };

    if (ioctl(fd, UI_SET_ABSBIT, axis) < 0)
        fail("UI_SET_ABSBIT");
    if (ioctl(fd, UI_ABS_SETUP, &setup) < 0)
        fail("UI_ABS_SETUP");
}

static void emit(int fd, int type, int code, int value)
{
    struct input_event event = {
        .type = type,
        .code = code,
        .value = value,
    };

    if (write(fd, &event, sizeof(event)) != sizeof(event))
        fail("write input event");
}

static void press_button(int fd, int button)
{
    emit(fd, EV_KEY, button, 1);
    emit(fd, EV_SYN, SYN_REPORT, 0);
    usleep(50000);
    emit(fd, EV_KEY, button, 0);
    emit(fd, EV_SYN, SYN_REPORT, 0);
}

int main(void)
{
    const int keys[] = {
        BTN_SOUTH, BTN_EAST, BTN_NORTH, BTN_WEST,
        BTN_TL, BTN_TR, BTN_SELECT, BTN_START, BTN_MODE,
        BTN_THUMBL, BTN_THUMBR,
    };
    const int axes[] = {
        ABS_X, ABS_Y, ABS_RX, ABS_RY, ABS_Z, ABS_RZ,
    };
    sigset_t signals;
    struct uinput_setup setup = {
        .id = {
            .bustype = BUS_USB,
            .vendor = 0x045e,
            .product = 0x028e,
            .version = 0x0114,
        },
    };
    int fd;
    int received;

    sigemptyset(&signals);
    sigaddset(&signals, SIGUSR1);
    sigaddset(&signals, SIGINT);
    sigaddset(&signals, SIGTERM);
    if (sigprocmask(SIG_BLOCK, &signals, NULL) < 0)
        fail("sigprocmask");

    fd = open("/dev/uinput", O_WRONLY | O_NONBLOCK);
    if (fd < 0)
        fail("open /dev/uinput");

    if (ioctl(fd, UI_SET_EVBIT, EV_KEY) < 0)
        fail("UI_SET_EVBIT EV_KEY");
    if (ioctl(fd, UI_SET_EVBIT, EV_ABS) < 0)
        fail("UI_SET_EVBIT EV_ABS");

    for (size_t i = 0; i < sizeof(keys) / sizeof(keys[0]); ++i)
        enable_key(fd, keys[i]);
    for (size_t i = 0; i < sizeof(axes) / sizeof(axes[0]); ++i)
        enable_axis(fd, axes[i], 0, 32767);
    enable_axis(fd, ABS_HAT0X, -1, 1);
    enable_axis(fd, ABS_HAT0Y, -1, 1);

    snprintf(setup.name, UINPUT_MAX_NAME_SIZE, "VQS Presentation Controller");
    if (ioctl(fd, UI_DEV_SETUP, &setup) < 0)
        fail("UI_DEV_SETUP");
    if (ioctl(fd, UI_DEV_CREATE) < 0)
        fail("UI_DEV_CREATE");

    usleep(300000);
    puts("VQS_PRESENTATION_GAMEPAD_READY");
    fflush(stdout);

    for (;;) {
        if (sigwait(&signals, &received) != 0)
            fail("sigwait");
        if (received == SIGUSR1)
            press_button(fd, BTN_TR);
        else
            break;
    }

    if (ioctl(fd, UI_DEV_DESTROY) < 0 && errno != ENODEV)
        fail("UI_DEV_DESTROY");
    close(fd);
    return EXIT_SUCCESS;
}
