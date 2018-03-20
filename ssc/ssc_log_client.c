#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

#include "qmi_client.h"
#include "ssc_log_msg_v01.h"


struct ssc_log_client {
    qmi_client_type client;
};

int qmi_init(struct ssc_log_client *client)
{
    int ret;
    qmi_idl_service_object_type svc_obj;
    qmi_cci_os_signal_type os_params;

    svc_obj =  ssc_log_print_get_service_object_v01();
    if (!svc_obj) {
        return -1;
    }

    ret = qmi_client_init_instance(svc_obj, QMI_CLIENT_INSTANCE_ANY,
            NULL, NULL, &os_params, 0, &(client->client));
    if (ret != QMI_NO_ERR) {
        return -1;
    }

    return 0;
}

int qmi_exit(struct ssc_log_client *client)
{
    qmi_client_release(client->client);
    return 0;
}

int send_log(struct ssc_log_client *client, char *buf)
{
    ssc_log_print_req_msg_v01 req = { 0 };
    ssc_log_print_resp_msg_v01 resp = { 0 };
    int ret;

    req.len = strcpy(req.buf, buf);

    ret = qmi_client_send_msg_sync(client->client, QMI_SSC_LOG_PRINT_REQ_V01,
            &req, sizeof(req),
            &resp, sizeof(resp),
            0);
    if (ret != QMI_NO_ERR) {
        return -1;
    }

    return 0;
}


int main()
{
    struct ssc_log_client client;

    if (qmi_init(&client) < 0)
        return -1;

    send_log(&client, "xxxxxxxxxx");

    qmi_exit(&client);

    return 0;
}
