THEOS ?= /home/ubuntu/workspace/upstream/theos
TARGET ?= iphone:clang:16.5:15.0
ARCHS ?= arm64

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = PrerecordedLiveUI
PrerecordedLiveUI_FILES = Tweak.xm
PrerecordedLiveUI_CFLAGS = -fobjc-arc
PrerecordedLiveUI_FRAMEWORKS = Foundation UIKit PhotosUI AVFoundation AVKit ReplayKit MediaPlayer
PrerecordedLiveUI_INSTALL_PATH = /Library/MobileSubstrate/DynamicLibraries

include $(THEOS_MAKE_PATH)/tweak.mk
