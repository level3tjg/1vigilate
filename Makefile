THEOS_DEVICE_IP = 192.168.1.75

ARCHS = arm64

INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = 1vigilate

1vigilate_FILES = Tweak.xm
1vigilate_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk
