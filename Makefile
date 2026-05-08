# UR Android Frame — development Makefile
#
# Usage:  make <target>
#         make help          list all targets with descriptions
#
# First-time setup on a fresh machine:
#   make install-prerequisites    install Flutter SDK + Android SDK
#   make setup-android            accept licenses, create AVD
#
# Daily workflow:
#   make dev                      run demo app on Android emulator
#   make test                     run library + demo tests

PROJECT_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
DEMO_DIR     = $(PROJECT_DIR)demo
FLUTTER      = /media/narayaana/data/dev/flutter/bin/flutter
DART         = /media/narayaana/data/dev/flutter/bin/dart
ANDROID_HOME = /home/narayaana/Android/Sdk
SDKMANAGER   = $(ANDROID_HOME)/cmdline-tools/latest/bin/sdkmanager
AVDMANAGER   = $(ANDROID_HOME)/cmdline-tools/latest/bin/avdmanager
EMULATOR     = $(ANDROID_HOME)/emulator/emulator
ADB          = $(ANDROID_HOME)/platform-tools/adb

export ANDROID_HOME
export ANDROID_SDK_ROOT = $(ANDROID_HOME)

.PHONY: help \
        install-prerequisites setup-android setup-all \
        build build-demo \
        test test-lib test-demo \
        dev dev-android \
        create-avd avd-start \
        check clean

# ── Help ─────────────────────────────────────────────────────────────────────

help: ## Show this help
	@echo "Usage: make <target>"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
	  awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2}' | sort

# ── Setup ────────────────────────────────────────────────────────────────────

install-prerequisites: ## Install Flutter SDK + Android SDK if not present
	@if [ ! -x $(FLUTTER) ]; then \
		echo "Flutter SDK not found — downloading..."; \
		cd /tmp && curl -sL "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.38.6-stable.tar.xz" -o flutter.tar.xz && \
		tar xf flutter.tar.xz -C /media/narayaana/data/dev/ --no-same-owner && \
		rm flutter.tar.xz && \
		echo "Flutter SDK installed."; \
	fi
	@if [ ! -x $(SDKMANAGER) ]; then \
		echo "Android SDK cmdline-tools not found — downloading..."; \
		mkdir -p $(ANDROID_HOME)/cmdline-tools && \
		cd /tmp && curl -sL "https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip" -o cmdline-tools.zip && \
		cd $(ANDROID_HOME)/cmdline-tools && unzip -qo /tmp/cmdline-tools.zip && \
		mv cmdline-tools latest 2>/dev/null || true && \
		rm /tmp/cmdline-tools.zip && \
		echo "Android SDK cmdline-tools installed."; \
	fi
	$(FLUTTER) config --android-sdk $(ANDROID_HOME)
	$(FLUTTER) config --no-analytics 2>/dev/null || true
	$(FLUTTER) doctor

setup-android: ## Accept Android SDK licenses + install platform & emulator
	yes | $(SDKMANAGER) --sdk_root=$(ANDROID_HOME) --licenses
	$(SDKMANAGER) --sdk_root=$(ANDROID_HOME) \
		"platform-tools" "build-tools;34.0.0" "platforms;android-34" \
		"system-images;android-34;default;x86_64" "emulator"
	$(FLUTTER) doctor

setup-all: install-prerequisites setup-android ## Full first-time setup

# ── Build ────────────────────────────────────────────────────────────────────

build: ## Analyze library Dart code (no compile step needed for package)
	cd $(PROJECT_DIR) && $(FLUTTER) analyze

build-demo: ## Build demo APK (debug)
	cd $(DEMO_DIR) && $(FLUTTER) build apk --debug

# ── Test ─────────────────────────────────────────────────────────────────────

test-lib: ## Run library unit + widget tests
	cd $(PROJECT_DIR) && $(FLUTTER) test

test-demo: ## Run demo app tests
	cd $(DEMO_DIR) && $(FLUTTER) test

test: test-lib test-demo ## Run all tests

# ── Dev ──────────────────────────────────────────────────────────────────────

dev: ## Run demo app on Android emulator
	@if ! $(ADB) devices 2>/dev/null | grep -q emulator; then \
		echo "Starting Android emulator..."; \
		$(FLUTTER) emulators --launch pixel6_api34 & \
		echo "Waiting for emulator to boot..."; \
		$(ADB) wait-for-device; \
		sleep 10; \
	fi
	cd $(DEMO_DIR) && $(FLUTTER) run

dev-android: dev ## Alias for dev

# ── Emulator ─────────────────────────────────────────────────────────────────

create-avd: ## Create a Pixel 6 AVD (API 34) for testing with KVM
	@echo "Creating Pixel 6 AVD (API 34)..."
	$(AVDMANAGER) create avd -n pixel6_api34 -k "system-images;android-34;default;x86_64" -d pixel_6 --force

avd-start: ## Launch the AVD (must run in a visible terminal)
	$(EMULATOR) -avd pixel6_api34 -netdelay none -netspeed full &

# ── Quality ──────────────────────────────────────────────────────────────────

check: ## Run flutter analyze on library + demo
	cd $(PROJECT_DIR) && $(FLUTTER) analyze
	cd $(DEMO_DIR) && $(FLUTTER) analyze

clean: ## Clean all build artefacts
	cd $(PROJECT_DIR) && $(FLUTTER) clean 2>/dev/null || true
	cd $(DEMO_DIR) && $(FLUTTER) clean 2>/dev/null || true
