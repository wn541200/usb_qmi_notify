#include <string.h>
#include <poll.h>
#include <stdio.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <linux/netlink.h>
#include <errno.h>
#include <stdbool.h>
#include <string.h>
#include <strings.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>

#include "uevent.h"

static event_cb _cb = NULL;
static void *_userdata = NULL;

static bool isMatch(const char *buf, int length, const char *match)
{
    const char *field = buf;
    const char *end = buf + length + 1;

    do {
        if (strstr(field, match))
            return true;
        field += strlen(field) + 1;
    } while (field < end);

    return false;
}

static const char *getKey(const char *buf, int length, const char *key)
{
    const char *field = buf;
    const char *end = buf + length + 1;

    do {
        if (strstr(field, key)) {
            const char *equal = strchr(field, '=');
            if (equal)
                return equal + 1;
        }

        field += strlen(field) + 1;
    } while (field < end);

    return NULL;
}

static void dump(const char *buf, int length)
{
    const char *field = buf;
    const char *end = buf + length + 1;

    INFO("\n+++\n");
    do {
        INFO("* %s\n", field);
        field += strlen(field) + 1;
    } while (field < end);
    INFO("---\n");
}

static void usb_connect()
{
    INFO("USB CONNECTED\n");
    if (_cb != NULL)
        _cb(1, _userdata);
}

static void usb_disconnect()
{
    INFO("USB DISCONNECTED\n");
    if (_cb)
        _cb(0, _userdata);
}

static int uevent_init()
{
	struct sockaddr_nl addr;
	int sz = 64 * 1024;
    int on = 1;
	int fd;

	memset(&addr, 0, sizeof(addr));
	addr.nl_family = AF_NETLINK;
	addr.nl_pid = getpid();
	addr.nl_groups = 0xffffffff;

	fd = socket(PF_NETLINK, SOCK_DGRAM, NETLINK_KOBJECT_UEVENT);
	if (fd < 0) {
		ERROR("Failed to create socket !\n");
		return -1;
	}
	setsockopt(fd, SOL_SOCKET, SO_RCVBUFFORCE, &sz, sizeof(sz));
	setsockopt(fd, SOL_SOCKET, SO_PASSCRED, &on, sizeof(on));

	if (bind(fd, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
		ERROR("Failed to bind socket !\n");
		close(fd);
		return -1;
	}
	return fd;
}

int uevent_loop(event_cb cb, void *data)
{
	int fd, n;
	char buf[1024] = { 0 };
    bool debug = false;
#if 1
    const char *match = "DEVPATH=/devices/virtual/android_usb/android0";
    const char *key = "USB_STATE";
    const char *connected = "CONNECTED";
    const char *disconnected = "DISCONNECTED";
#else
    const char *match = "cpu3";
    const char *key = "ACTION";
    const char *connected = "online";
    const char *disconnected = "offline";
#endif

    _cb = cb;
    _userdata = data;

	fd = uevent_init();
	if(fd < 0) {
		ERROR("Failed to exec uevent_init !\n");
		return -1;
	}

	while ((n = recv(fd, buf, sizeof(buf)-1, 0)) > 0) {
        if (isMatch(buf, n, match)) {
            const char *value = getKey(buf, n, key);
            if (strcmp(value, connected) == 0) {
                usb_connect();
            } else if (strcmp(value, disconnected) == 0) {
                usb_disconnect();
            }
        }
		memset(buf, 0, sizeof(buf));
	}

	return 0;
}

