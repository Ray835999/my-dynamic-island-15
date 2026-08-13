# iPhone 6s + iOS 15.8.8 (palera1n checkm8, rootful)
# SDK 指向 15.5，部署目标 15.0
TARGET := iphone:clang:15.5:15.0
INSTALL_TARGET_PROCESSES = SpringBoard

ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = DynamicIsland15

DynamicIsland15_FILES = Tweak.x DCIslandView.m
DynamicIsland15_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
DynamicIsland15_FRAMEWORKS = UIKit MediaPlayer CoreTelephony
DynamicIsland15_PRIVATE_FRAMEWORKS = SpringBoardUI

include $(THEOS_MAKE_PATH)/tweak.mk
