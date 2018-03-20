#include <stdlib.h>
#include <stdio.h>
#include <sys/select.h>
#include <sys/time.h>
#include <sys/types.h>
#include <unistd.h>

#include "qmi_idl_lib.h"
#include "qmi_csi.h"

#include "ssc_log_msg_v01.h"

struct ssc_log_svc {
    qmi_csi_os_params os_params;
    qmi_csi_service_handle service_handle;
};

qmi_csi_cb_error ssc_log_svc_req_cb
(
 void                     *connection_handle,
 qmi_req_handle           req_handle,
 int                      msg_id,
 void                     *req_c_struct,
 int                      req_c_struct_len,
 void                     *service_cookie
 )
{
    ssc_log_print_req_msg_v01 *req = (ssc_log_print_req_msg_v01 *)req_c_struct;
    ssc_log_print_resp_msg_v01 resp;

    fprintf(stdout, "ID:%d log:%s\n", msg_id, req->buf);
    fflush(stdout);

    resp.result = 1;

    return qmi_csi_send_resp(req_handle, msg_id, &resp, sizeof(resp));
}

qmi_csi_cb_error ssc_log_svc_connect_cb
(
 qmi_client_handle         client_handle,
 void                      *service_cookie,
 void                      **connection_handle
)
{
    fprintf(stdout, "%s\n", __func__);
    fflush(stdout);

    return QMI_CSI_CB_NO_ERR;
}

void ssc_log_svc_disconnect_cb
(
 void *connection_handle,
 void *service_cookie
 )
{
    fprintf(stdout, "%s\n", __func__);
    fflush(stdout);
}

int qmi_init(struct ssc_log_svc *svc)
{
    int ret;
    qmi_idl_service_object_type svc_obj;

    svc_obj = ssc_log_print_get_service_object_v01();
    if (!svc_obj) {
        fprintf(stderr, "ERROR: ssc_log_print_get_service_object_v01()\n");
        fflush(stdout);
        return -1;
    }

    ret = qmi_csi_register(svc_obj,
            ssc_log_svc_connect_cb, ssc_log_svc_disconnect_cb,
            (qmi_csi_process_req)ssc_log_svc_req_cb,
            svc, &svc->os_params, &svc->service_handle);
    if (ret != QMI_NO_ERR) {
        fprintf(stderr, "ERROR: qmi_csi_register()\n");
        fflush(stdout);
        return -1;
    }

    return 0;
}

int qmi_exit(struct ssc_log_svc *svc)
{
    if (qmi_csi_unregister(svc->service_handle) != QMI_NO_ERR)
        return -1;
    return 0;
}

void qmi_loop(struct ssc_log_svc *svc)
{
    fd_set fds;
    qmi_csi_os_params os_params_in;
    char buf[10];

    while (1) {
        fds = svc->os_params.fds;
        FD_SET(STDIN_FILENO, &fds);
        select(svc->os_params.max_fd+1, &fds, NULL, NULL, NULL);
        if (FD_ISSET(STDIN_FILENO, &fds)) {
            if (read(STDIN_FILENO, buf, sizeof(buf)) <= 0)
                break;
        }

        os_params_in.fds = fds;
        qmi_csi_handle_event(svc->service_handle, &os_params_in);
    }
}

int main()
{
    struct ssc_log_svc svc;

    memset(&svc, 0, sizeof(svc));

    if (qmi_init(&svc) < 0) {
        fprintf(stderr, "ERROR: qmi_init()\n");
        fflush(stdout);
        return -1;
    }

    qmi_loop(&svc);

    qmi_exit(&svc);

    return 0;
}
