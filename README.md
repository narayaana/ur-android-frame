# ur-android-frame

Shared Flutter/Dart component library for the ur-* Android ecosystem.

Consuming apps: ur-contender, ur-school, ur-dive-computer, etc.

## Prerequisites

- Flutter SDK (>=3.38)
- Android SDK (API 34+) with cmdline-tools
- KVM for Android emulator acceleration

## Setup

```bash
make install-prerequisites   # Install Flutter SDK if needed
make setup-android            # Accept Android licenses, create AVD
make build                    # Analyze library code
make test                     # Run all tests
```

## Dev

```bash
make dev                      # Run demo app on emulator/device
```
