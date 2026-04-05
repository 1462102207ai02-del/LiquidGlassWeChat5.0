TARGET := iphone:clang:latest:14.0
ARCHS = arm64
INSTALL_TARGET_PROCESSES = WeChat

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = LiquidGlassWeChat

LiquidGlassWeChat_FILES = Tweak.xm
LiquidGlassWeChat_FILES += Settings/Settings.m

LiquidGlassWeChat_FRAMEWORKS = UIKit QuartzCore

after-install::
	$(ECHO_NOTHING) mkdir -p $(THEOS_STAGING_DIR)/Library/Preferences/com.example.LiquidGlassWeChat
	$(ECHO_NOTHING) cp $(THEOS)/obj/LiquidGlassWeChat/Settings/Settings.plist $(THEOS_STAGING_DIR)/Library/Preferences/com.example.LiquidGlassWeChat/Settings.plist

include $(THEOS_MAKE_PATH)/tweak.mk
