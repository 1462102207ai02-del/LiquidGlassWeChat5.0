TARGET := iphone:clang:latest:14.0
INSTALL_TARGET_PROCESSES = WeChat

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = LiquidGlassWeChat

LiquidGlassWeChat_FILES = Tweak.xm
LiquidGlassWeChat_FRAMEWORKS = UIKit QuartzCore
