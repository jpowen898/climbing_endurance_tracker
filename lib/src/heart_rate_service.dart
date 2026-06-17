import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

const _heartRateControlChannel = MethodChannel('climb_endurance/heart_rate');
const _heartRateEventChannel =
    EventChannel('climb_endurance/heart_rate_stream');

class HeartRateReading {
  const HeartRateReading({
    required this.bpm,
    required this.recordedAt,
    this.accuracy,
    this.source = 'local_sensor',
  });

  final double bpm;
  final DateTime recordedAt;
  final int? accuracy;
  final String source;

  static HeartRateReading? fromEvent(Object? event) {
    if (event is! Map) return null;
    final bpm = (event['bpm'] as num?)?.toDouble();
    final timestamp = event['timestamp'] as int?;
    if (bpm == null || timestamp == null || bpm <= 0) return null;
    return HeartRateReading(
      bpm: bpm,
      recordedAt: DateTime.fromMillisecondsSinceEpoch(timestamp),
      accuracy: event['accuracy'] as int?,
      source: event['source'] as String? ?? 'local_sensor',
    );
  }
}

class HeartRateService {
  HeartRateService._();

  static final HeartRateService instance = HeartRateService._();

  Stream<HeartRateReading>? _stream;

  Stream<HeartRateReading> get readings {
    _stream ??= _heartRateEventChannel.receiveBroadcastStream().map(
      (event) {
        final reading = HeartRateReading.fromEvent(event);
        if (reading == null) {
          throw const FormatException('Invalid heart rate reading');
        }
        return reading;
      },
    );
    return _stream!;
  }

  Future<bool> start() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _heartRateControlChannel.invokeMethod<bool>('start') ??
          false;
    } on PlatformException {
      return false;
    }
  }

  Future<Map<String, Object?>> healthConnectStatus() async {
    if (!Platform.isAndroid) {
      return {'available': false, 'permissionsGranted': false};
    }
    try {
      final result = await _heartRateControlChannel
          .invokeMapMethod<String, Object?>('healthConnectStatus');
      return result ?? {'available': false, 'permissionsGranted': false};
    } on PlatformException {
      return {'available': false, 'permissionsGranted': false};
    }
  }

  Future<bool> requestHealthConnectPermissions() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _heartRateControlChannel
              .invokeMethod<bool>('requestHealthConnectPermissions') ??
          false;
    } on PlatformException {
      return false;
    }
  }

  Future<List<HeartRateReading>> readHealthConnectHeartRate({
    required DateTime start,
    required DateTime end,
  }) async {
    if (!Platform.isAndroid) return const [];
    final result = await _heartRateControlChannel.invokeMethod<List<dynamic>>(
      'readHealthConnectHeartRate',
      {
        'startMillis': start.millisecondsSinceEpoch,
        'endMillis': end.millisecondsSinceEpoch,
      },
    );
    return (result ?? const [])
        .map(HeartRateReading.fromEvent)
        .whereType<HeartRateReading>()
        .toList();
  }

  Future<void> stop() async {
    if (!Platform.isAndroid) return;
    try {
      await _heartRateControlChannel.invokeMethod<void>('stop');
    } on PlatformException {
      // Best effort only; the sensor stream is optional.
    }
  }
}
