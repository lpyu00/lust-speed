# 目标 iOS 版本和架构 (注入 IPA 通常用 arm64 兼容性最好)
TARGET := iphone:clang:latest:14.0
ARCHS := arm64

# 【绝对不要加 THEOS_PACKAGE_SCHEME = rootless】

include $(THEOS)/makefiles/common.mk

# 【关键修复】必须是 TWEAK_NAME，不能是 LIBRARY_NAME
TWEAK_NAME = LustSpeed
LustSpeed_FILES = Tweak.x
LustSpeed_FRAMEWORKS = UIKit Foundation
LustSpeed_CFLAGS = -fobjc-arc -Wno-deprecated-declarations

# 【关键修复】必须 include tweak.mk
include $(THEOS_MAKE_PATH)/tweak.mk
