#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

#include "qmi_client.h"
#include "usb_notify_v01.h"

#include "uevent.h"

struct usb_notify {
    qmi_client_type client;
};

int qmi_init(struct usb_notify *notify)
{
    int ret;
    qmi_idl_service_object_type svc_obj;
    qmi_cci_os_signal_type os_params;

    svc_obj = usb_notify_get_service_object_v01();
    if (!svc_obj) {
        return -1;
    }

    ret = qmi_client_init_instance(svc_obj, QMI_CLIENT_INSTANCE_ANY,
            NULL, NULL, &os_params, 0, &(notify->client));
    if (ret != QMI_NO_ERR) {
        return -1;
    }

    return 0;
}

int qmi_exit(struct usb_notify *notify)
{
    qmi_client_release(notify->client);
    return 0;
}

int send_usb_state(struct usb_notify *notify, int state)
{
    usb_state_req_msg_v01 req = { 0 };
    usb_state_resp_msg_v01 resp = { 0 };
    int ret;

    req.state = state;

    ret = qmi_client_send_msg_sync(notify->client, QMI_USB_STATE_REQ_V01,
            &req, sizeof(req),
            &resp, sizeof(resp),
            0);
    if (ret != QMI_NO_ERR) {
        return -1;
    }

    return 0;
}

void usb_state_callback(int state, void *data)
{
    struct usb_notify *notify = data;
    send_usb_state(notify, state);
}

int main()
{
    struct usb_notify notify;

    if (qmi_init(&notify) < 0)
        return -1;

    uevent_loop(usb_state_callback, &notify);

    qmi_exit(&notify);

    return 0;
}
