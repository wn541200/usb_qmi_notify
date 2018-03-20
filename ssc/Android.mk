LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)
LOCAL_MODULE := usb_notify
LOCAL_VENDOR_MODULE := true
LOCAL_SRC_FILES := usb_notify.c usb_notify_v01.c uevent.c
LOCAL_SHARED_LIBRARIES := libqmi_cci
LOCAL_C_INCLUDES := \
    $(QC_PROP_ROOT)/qmi-framework/inc
#LOCAL_INIT_RC := usb_notify.rc
include $(BUILD_EXECUTABLE)

include $(CLEAR_VARS)
LOCAL_MODULE := usb_notify_svc
LOCAL_VENDOR_MODULE := true
LOCAL_SRC_FILES := usb_notify_svc.c usb_notify_v01.c
LOCAL_SHARED_LIBRARIES := libqmi_csi
LOCAL_C_INCLUDES := \
    $(QC_PROP_ROOT)/qmi-framework/inc
include $(BUILD_EXECUTABLE)
