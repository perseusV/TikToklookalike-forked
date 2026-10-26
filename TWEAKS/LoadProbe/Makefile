THEOS ?= /home/ubuntu/workspace/upstream/theos
TARGET ?= iphone:clang:16.5:15.0
# TikTok's extracted app executable is arm64. Keep the harmless probe arm64-only
# until the user's device and jailbreak ABI are confirmed; the bundled Linux
# toolchain emits an incompatible-ABI warning for arm64e.
ARCHS ?= arm64

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = TikTokLoadProbe
TikTokLoadProbe_FILES = Tweak.xm
TikTokLoadProbe_CFLAGS = -fobjc-arc
TikTokLoadProbe_FRAMEWORKS = Foundation
TikTokLoadProbe_INSTALL_PATH = /Library/MobileSubstrate/DynamicLibraries

include $(THEOS_MAKE_PATH)/tweak.mk
