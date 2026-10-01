TARGET := iphone:clang:latest:14.0
ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = InfuseControlMod
InfuseControlMod_FILES = Tweak.x
InfuseControlMod_CFLAGS = -fobjc-arc
InfuseControlMod_FRAMEWORKS = UIKit QuartzCore

include $(THEOS)/makefiles/tweak.mk
