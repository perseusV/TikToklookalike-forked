THEOS ?= /home/ubuntu/workspace/upstream/theos
TARGET ?= iphone:clang:16.5:15.0
# The extracted TikTok executable and extension are arm64.
ARCHS ?= arm64

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = PrerecordedPipelineProbe
PrerecordedPipelineProbe_FILES = Tweak.xm
PrerecordedPipelineProbe_CFLAGS = -fobjc-arc
PrerecordedPipelineProbe_FRAMEWORKS = Foundation CoreMedia AVFoundation
PrerecordedPipelineProbe_INSTALL_PATH = /Library/MobileSubstrate/DynamicLibraries

include $(THEOS_MAKE_PATH)/tweak.mk
