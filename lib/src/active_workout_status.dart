import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'utils.dart';

const workoutNotificationChannel =
    MethodChannel('climb_endurance/workout_notification');

class ActiveWorkoutSnapshot {
  const ActiveWorkoutSnapshot.idle()
      : active = false,
        resting = false,
        title = '',
        detail = '',
        timerSeconds = 0,
        targetRestSeconds = 0;

  const ActiveWorkoutSnapshot({
    required this.active,
    required this.resting,
    required this.title,
    required this.detail,
    required this.timerSeconds,
    required this.targetRestSeconds,
  });

  final bool active;
  final bool resting;
  final String title;
  final String detail;
  final int timerSeconds;
  final int targetRestSeconds;

  String get modeLabel => resting ? 'Resting' : 'Working';

  String get timerText {
    if (!resting) return formatDuration(timerSeconds);
    return formatSigned(targetRestSeconds - timerSeconds);
  }
}

class ActiveWorkoutStatus extends ValueNotifier<ActiveWorkoutSnapshot> {
  ActiveWorkoutStatus._() : super(const ActiveWorkoutSnapshot.idle());

  static final instance = ActiveWorkoutStatus._();

  Future<void> update(ActiveWorkoutSnapshot snapshot) async {
    value = snapshot;
    await _syncNotification(snapshot);
  }

  Future<void> clear() async {
    value = const ActiveWorkoutSnapshot.idle();
    if (Platform.isAndroid) {
      try {
        await workoutNotificationChannel.invokeMethod<void>('cancel');
      } on PlatformException {
        // Notification support is best-effort; recording state stays in-app.
      }
    }
  }

  Future<void> _syncNotification(ActiveWorkoutSnapshot snapshot) async {
    if (!Platform.isAndroid) return;
    try {
      if (!snapshot.active) {
        await workoutNotificationChannel.invokeMethod<void>('cancel');
        return;
      }
      await workoutNotificationChannel.invokeMethod<void>('show', {
        'title': '${snapshot.modeLabel}: ${snapshot.title}',
        'text': '${snapshot.detail} - ${snapshot.timerText}',
      });
    } on PlatformException {
      // Notification support is best-effort; recording state stays in-app.
    }
  }
}
