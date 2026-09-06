SHELL=/bin/bash
# THEOS=${HOME}/theos
PACKAGE_VERSION=$(THEOS_PACKAGE_BASE_VERSION)

# rootless
THEOS_PACKAGE_SCHEME=rootless

include $(THEOS)/makefiles/common.mk

export ARCHS = arm64 arm64e
# The deployment target stays at 14.0 so the iOS 14/15 code paths keep building;
# `latest` picks whatever SDK the build machine has, which has to be 16 or newer
# for the iOS 16 layout.
export TARGET = iphone:clang:latest:14.0

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
