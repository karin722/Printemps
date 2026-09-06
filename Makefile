SHELL=/bin/bash
# THEOS=${HOME}/theos
PACKAGE_VERSION=$(THEOS_PACKAGE_BASE_VERSION)

# Has to come before common.mk, which reads both of them as it is included.
export ARCHS = arm64 arm64e
# iPhoneOS16.5 is the newest SDK theos ships and the oldest one that can build
# the iOS 16 code paths. Xcode's own SDK carries no PrivateFrameworks, so it is
# pinned rather than left as `latest`.
export TARGET = iphone:clang:16.5:14.0

# rootless
THEOS_PACKAGE_SCHEME=rootless

include $(THEOS)/makefiles/common.mk

# SSH
# THEOS_DEVICE_IP = localhost
# THEOS_DEVICE_PORT = 2222

# simject
# export TARGET = simulator:clang::13.0
# export ARCHS = x86_64

TWEAK_NAME = Printemps
$(TWEAK_NAME)_FILES = Tweak.xm
$(TWEAK_NAME)_FRAMEWORKS = UIKit
$(TWEAK_NAME)_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -Wc++11-extensions -std=c++11

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += PrintempsPrefs
include $(THEOS_MAKE_PATH)/aggregate.mk

after-install::
	install.exec "killall -9 SpringBoard"
