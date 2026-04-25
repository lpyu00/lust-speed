TARGET = iphone:clang:latest:15.0
ARCHS = arm64 arm64e
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

LIBRARY_NAME = LustSpeed
LustSpeed_FILES = Tweak.x
LustSpeed_FRAMEWORKS = UIKit Foundation
LustSpeed_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/library.mk
