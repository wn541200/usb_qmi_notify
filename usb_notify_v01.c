/*====*====*====*====*====*====*====*====*====*====*====*====*====*====*====*

                        U S B _ N O T I F Y _ V 0 1  . C

GENERAL DESCRIPTION
  This is the file which defines the usb_notify service Data structures.

  

  
 *====*====*====*====*====*====*====*====*====*====*====*====*====*====*====*/
/*====*====*====*====*====*====*====*====*====*====*====*====*====*====*====*
 *THIS IS AN AUTO GENERATED FILE. DO NOT ALTER IN ANY WAY
 *====*====*====*====*====*====*====*====*====*====*====*====*====*====*====*/

/* This file was generated with Tool version 6.14.9 
   It was generated on: Fri Feb  2 2018 (Spin 0)
   From IDL File: usb_notify_v01.idl */

#include "stdint.h"
#include "qmi_idl_lib_internal.h"
#include "usb_notify_v01.h"


/*Type Definitions*/
/*Message Definitions*/
static const uint8_t usb_state_req_msg_data_v01[] = {
  QMI_IDL_TLV_FLAGS_LAST_TLV | 0x01,
   QMI_IDL_GENERIC_1_BYTE,
  QMI_IDL_OFFSET8(usb_state_req_msg_v01, state)
};

static const uint8_t usb_state_resp_msg_data_v01[] = {
  QMI_IDL_TLV_FLAGS_LAST_TLV | 0x01,
   QMI_IDL_GENERIC_1_BYTE,
  QMI_IDL_OFFSET8(usb_state_resp_msg_v01, result)
};

/* Type Table */
/* No Types Defined in IDL */

/* Message Table */
static const qmi_idl_message_table_entry usb_notify_message_table_v01[] = {
  {sizeof(usb_state_req_msg_v01), usb_state_req_msg_data_v01},
  {sizeof(usb_state_resp_msg_v01), usb_state_resp_msg_data_v01}
};

/* Range Table */
/* Predefine the Type Table Object */
static const qmi_idl_type_table_object usb_notify_qmi_idl_type_table_object_v01;

/*Referenced Tables Array*/
static const qmi_idl_type_table_object *usb_notify_qmi_idl_type_table_object_referenced_tables_v01[] =
{&usb_notify_qmi_idl_type_table_object_v01};

/*Type Table Object*/
static const qmi_idl_type_table_object usb_notify_qmi_idl_type_table_object_v01 = {
  0,
  sizeof(usb_notify_message_table_v01)/sizeof(qmi_idl_message_table_entry),
  1,
  NULL,
  usb_notify_message_table_v01,
  usb_notify_qmi_idl_type_table_object_referenced_tables_v01,
  NULL
};

/*Arrays of service_message_table_entries for commands, responses and indications*/
static const qmi_idl_service_message_table_entry usb_notify_service_command_messages_v01[] = {
  {QMI_USB_STATE_REQ_V01, QMI_IDL_TYPE16(0, 0), 4}
};

static const qmi_idl_service_message_table_entry usb_notify_service_response_messages_v01[] = {
  {QMI_USB_STATE_RESP_V01, QMI_IDL_TYPE16(0, 1), 4}
};

/*Service Object*/
struct qmi_idl_service_object usb_notify_qmi_idl_service_object_v01 = {
  0x06,
  0x01,
  0x08FF,
  4,
  { sizeof(usb_notify_service_command_messages_v01)/sizeof(qmi_idl_service_message_table_entry),
    sizeof(usb_notify_service_response_messages_v01)/sizeof(qmi_idl_service_message_table_entry),
    0 },
  { usb_notify_service_command_messages_v01, usb_notify_service_response_messages_v01, NULL},
  &usb_notify_qmi_idl_type_table_object_v01,
  0x01,
  NULL
};

/* Service Object Accessor */
qmi_idl_service_object_type usb_notify_get_service_object_internal_v01
 ( int32_t idl_maj_version, int32_t idl_min_version, int32_t library_version ){
  if ( USB_NOTIFY_V01_IDL_MAJOR_VERS != idl_maj_version || USB_NOTIFY_V01_IDL_MINOR_VERS != idl_min_version
       || USB_NOTIFY_V01_IDL_TOOL_VERS != library_version)
  {
    return NULL;
  }
  return (qmi_idl_service_object_type)&usb_notify_qmi_idl_service_object_v01;
}

