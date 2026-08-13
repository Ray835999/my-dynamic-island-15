# iPhone 6s + iOS 15.8.8 (palera1n checkm8, rootful)
# SDK: 不强求具体文件名，让 Theos 在 $THEOS/sdks 自动选最匹配的 iOS 15 SDK
TARGET := iphone:clang:latest:15.0
INSTALL_TARGET_PROCESSES = SpringBoard

ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = DynamicIsland15

DynamicIsland15_FILES = Tweak.x DCIslandView.m
DynamicIsland15_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
DynamicIsland15_FRAMEWORKS = UIKit MediaPlayer CoreTelephony

include $(THEOS_MAKE_PATH)/tweak.mk
