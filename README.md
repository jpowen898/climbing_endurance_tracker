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
4. Verify the device is connected:

```bash
adb devices
```

5. Build the APK:

```bash
flutter build apk --debug
```

6. Install the APK on the device:

```bash
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

7. Launch from the phone or use:

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
