# Climb Endurance

A local-first Flutter app for recording spray wall endurance sessions.

## Features

- Android-first Flutter UI, ready for iOS later.
- Local SQLite database using `sqflite`.
- Routes, workout sessions, and sets.
- Climb timer and rest countdown that continues negative until the next set starts.
- Edit the current workout while resting.
- Raw data editor for sessions and sets.
- Charts for route progress, falloff, rest relationship, and average speed.

## Run

### Prerequisites

- Install Flutter and Android SDK.
- Ensure `flutter doctor` reports no critical errors.
- From this repository root, install Dart/Flutter packages:

```bash
flutter pub get
```


## Build and Test on Ubuntu

Use these steps when developing directly on a native Ubuntu desktop.

### Ubuntu Prerequisites

Install Flutter, then install the Linux desktop build toolchain:

```bash
sudo apt-get update
sudo apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev lld libsqlite3-dev
```

Enable Flutter Linux desktop support and verify the toolchain:

```bash
flutter config --enable-linux-desktop
flutter doctor -v
```

Install project dependencies from the repository root:

```bash
flutter pub get
```

### Static Checks and Tests

Run the analyzer:

```bash
flutter analyze
```

Run the widget/unit test suite:

```bash
flutter test
```

### Run on Ubuntu Desktop

If the repository does not have a `linux/` directory yet, generate the Linux runner once:

```bash
flutter create --platforms=linux .
```

List desktop devices:

```bash
flutter devices
```

Run the app on the native Linux desktop target:

```bash
flutter run -d linux
```

### Build a Linux Bundle

Build a release bundle:

```bash
flutter build linux --release
```

The executable bundle is written under:

```text
build/linux/x64/release/bundle/
```

Run the built app directly:

```bash
build/linux/x64/release/bundle/climb_endurance
```

### Snap Flutter Linker Error

If `flutter run -d linux` fails with an error like this:

```text
Failed to find any of [ld.lld, ld] in LocalDirectory: '/snap/flutter/.../usr/lib/llvm-10/bin'
```

then the Dart code has compiled far enough to hit a Flutter Snap toolchain
problem. This project pins `sqflite_common_ffi` to `2.3.6` and overrides
`sqlite3` to `2.7.6` to avoid the newer Dart native-assets linker path that
triggers this Snap failure. Keep those pins unless you are also moving off the
Snap Flutter SDK or have confirmed the native-assets linker works locally.

For Linux desktop builds, prefer the official Flutter SDK archive or git install
instead of the Snap package:

```bash
mkdir -p ~/development
git clone https://github.com/flutter/flutter.git -b stable ~/development/flutter
echo 'export PATH="$HOME/development/flutter/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
which flutter
flutter doctor -v
```

`which flutter` should point at `~/development/flutter/bin/flutter`, not
`/snap/bin/flutter`. After switching SDKs, rerun:

```bash
flutter pub get
flutter run -d linux
```

### Build the App

To build for Android:

```bash
flutter build apk --release
```

To build a debug APK for quick testing:

```bash
flutter build apk --debug
```

### Test with Emulator

1. List available emulators:

```bash
flutter emulators
```

2. Launch one:

```bash
flutter emulators --launch <emulator_id>
```

3. Confirm the emulator is available:

```bash
flutter devices
```

4. Run the app on the emulator:

```bash
flutter run
```

The app will install and launch on the active emulator.

### Test on Android Device with ADB

1. Enable Developer Options on the phone.
2. Turn on USB debugging.
3. Connect the phone to your computer via USB.
4. On the phone select `USB Preferences` and select `File Transfer / Android Auto`
5. Verify the device is connected:

```bash
adb devices
```

6. Build the APK:

```bash
flutter build apk --debug
```

7. Install the APK on the device:

```bash
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

8. Launch from the phone or use:

```bash
adb shell am start -n com.example.climb_endurance/com.example.climb_endurance.MainActivity
```

### Install Directly on an Android Device

Once the release APK is built:

```bash
flutter build apk --release
```

Then install it directly with ADB:

```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

If the device is already connected, you can also use Flutter directly:

```bash
flutter install --release
```

or, to run immediately on the connected device:

```bash
flutter run --release
```
