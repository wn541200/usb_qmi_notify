/*====*====*====*====*====*====*====*====*====*====*====*====*====*====*====*

                        S S C _ L O G _ M S G _ V 0 1  . C

GENERAL DESCRIPTION
  This is the file which defines the ssc_log_print service Data structures.

  

  
 *====*====*====*====*====*====*====*====*====*====*====*====*====*====*====*/
/*====*====*====*====*====*====*====*====*====*====*====*====*====*====*====*
 *THIS IS AN AUTO GENERATED FILE. DO NOT ALTER IN ANY WAY
 *====*====*====*====*====*====*====*====*====*====*====*====*====*====*====*/

/* This file was generated with Tool version 6.14.9 
   It was generated on: Mon Feb 26 2018 (Spin 0)
   From IDL File: ssc_log_msg_v01.idl */

#include "stdint.h"
#include "qmi_idl_lib_internal.h"
#include "ssc_log_msg_v01.h"


/*Type Definitions*/
/*Message Definitions*/
static const uint8_t ssc_log_print_req_msg_data_v01[] = {
  0x01,
  QMI_IDL_FLAGS_IS_ARRAY |  QMI_IDL_GENERIC_1_BYTE,
  QMI_IDL_OFFSET8(ssc_log_print_req_msg_v01, buf),
  32,

  QMI_IDL_TLV_FLAGS_LAST_TLV | 0x02,
   QMI_IDL_GENERIC_1_BYTE,
  QMI_IDL_OFFSET8(ssc_log_print_req_msg_v01, len)
};

static const uint8_t ssc_log_print_resp_msg_data_v01[] = {
  QMI_IDL_TLV_FLAGS_LAST_TLV | 0x01,
   QMI_IDL_GENERIC_1_BYTE,
  QMI_IDL_OFFSET8(ssc_log_print_resp_msg_v01, result)
};

/* Type Table */
/* No Types Defined in IDL */

/* Message Table */
static const qmi_idl_message_table_entry ssc_log_print_message_table_v01[] = {
  {sizeof(ssc_log_print_req_msg_v01), ssc_log_print_req_msg_data_v01},
  {sizeof(ssc_log_print_resp_msg_v01), ssc_log_print_resp_msg_data_v01}
};

/* Range Table */
/* Predefine the Type Table Object */
static const qmi_idl_type_table_object ssc_log_print_qmi_idl_type_table_object_v01;

/*Referenced Tables Array*/
static const qmi_idl_type_table_object *ssc_log_print_qmi_idl_type_table_object_referenced_tables_v01[] =
{&ssc_log_print_qmi_idl_type_table_object_v01};

/*Type Table Object*/
static const qmi_idl_type_table_object ssc_log_print_qmi_idl_type_table_object_v01 = {
  0,
  sizeof(ssc_log_print_message_table_v01)/sizeof(qmi_idl_message_table_entry),
  1,
  NULL,
  ssc_log_print_message_table_v01,
  ssc_log_print_qmi_idl_type_table_object_referenced_tables_v01,
  NULL
};

/*Arrays of service_message_table_entries for commands, responses and indications*/
static const qmi_idl_service_message_table_entry ssc_log_print_service_command_messages_v01[] = {
  {QMI_SSC_LOG_PRINT_REQ_V01, QMI_IDL_TYPE16(0, 0), 39}
};

static const qmi_idl_service_message_table_entry ssc_log_print_service_response_messages_v01[] = {
  {QMI_SSC_LOG_PRINT_RESP_V01, QMI_IDL_TYPE16(0, 1), 4}
};

/*Service Object*/
struct qmi_idl_service_object ssc_log_print_qmi_idl_service_object_v01 = {
  0x06,
  0x01,
  0x0876,
  39,
  { sizeof(ssc_log_print_service_command_messages_v01)/sizeof(qmi_idl_service_message_table_entry),
    sizeof(ssc_log_print_service_response_messages_v01)/sizeof(qmi_idl_service_message_table_entry),
    0 },
  { ssc_log_print_service_command_messages_v01, ssc_log_print_service_response_messages_v01, NULL},
  &ssc_log_print_qmi_idl_type_table_object_v01,
  0x01,
  NULL
};

/* Service Object Accessor */
qmi_idl_service_object_type ssc_log_print_get_service_object_internal_v01
 ( int32_t idl_maj_version, int32_t idl_min_version, int32_t library_version ){
  if ( SSC_LOG_PRINT_V01_IDL_MAJOR_VERS != idl_maj_version || SSC_LOG_PRINT_V01_IDL_MINOR_VERS != idl_min_version
       || SSC_LOG_PRINT_V01_IDL_TOOL_VERS != library_version)
  {
    return NULL;
  }
  return (qmi_idl_service_object_type)&ssc_log_print_qmi_idl_service_object_v01;
}

