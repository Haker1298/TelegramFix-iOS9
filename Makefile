ARCHS = armv7 arm64
TARGET = iphone:clang:latest:9.0
INSTALL_TARGET_PROCESSES = Telegram

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = TelegramFix

TelegramFix_FILES = Tweak.xm
TelegramFix_CFLAGS = -fobjc-arc -Wno-unused-function -Wno-unused-variable
TelegramFix_FRAMEWORKS = Foundation Security UIKit
TelegramFix_LIBRARIES = substrate

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 Telegram"