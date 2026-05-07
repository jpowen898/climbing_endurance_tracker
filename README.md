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

Install Flutter, then from this directory:

```bash
flutter create --platforms=android,ios .
flutter pub get
```

### Testing with Emulator

1. (Optional) Build the app: `flutter build apk` (this creates a debug APK; `flutter run` will build automatically if needed)
2. List available emulators: `flutter emulators`
3. Launch an emulator: `flutter emulators --launch <emulator_id>` (replace `<emulator_id>` with the ID from step 2, e.g., `flutter emulators --launch Pixel_8_API_34`)
4. Run the app on the emulator: `flutter run` (select the running emulator when prompted)

### Building and Installing on Android Phone

1. On your Android phone, enable Developer Options and USB debugging.
2. Connect the phone to your computer via USB.
3. Verify the device is recognized: `adb devices`
4. Build the APK: `flutter build apk --release`
5. Install on device: `flutter install --release`

On a Pixel 8, enable Developer Options and USB debugging, connect the phone, then select it as the run target when running `flutter run`.
