export ARCHS = arm64 arm64e
export TARGET = iphone:clang:15.5:14.0

# rootless
THEOS_PACKAGE_SCHEME=rootless

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = PrintempsPrefs

PrintempsPrefs_FILES = PrintempsRootListController.m
PrintempsPrefs_FRAMEWORKS = UIKit
PrintempsPrefs_PRIVATE_FRAMEWORKS = Preferences
PrintempsPrefs_INSTALL_PATH = /Library/PreferenceBundles
PrintempsPrefs_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/bundle.mk
