import 'package:flutter/services.dart';

class MasjidModeStatus {
  const MasjidModeStatus({
    required this.active,
    required this.dndAccessGranted,
    required this.exactAlarmGranted,
    required this.batteryUnrestricted,
    this.endsAt,
  });

  final bool active;
  final bool dndAccessGranted;
  final bool exactAlarmGranted;
  final bool batteryUnrestricted;
  final int? endsAt;

  factory MasjidModeStatus.fromMap(Map<Object?, Object?> data) {
    return MasjidModeStatus(
      active: data['active'] == true,
      dndAccessGranted: data['dndAccessGranted'] == true,
      exactAlarmGranted: data['exactAlarmGranted'] == true,
      batteryUnrestricted: data['batteryUnrestricted'] == true,
      endsAt: data['endsAt'] as int?,
    );
  }
}

class MasjidModeChannel {
  static const _channel = MethodChannel('com.devmhs.noor_quran/masjid_mode');

  static Future<MasjidModeStatus> status() async {
    final data = await _channel.invokeMethod<Map<Object?, Object?>>('status');
    return MasjidModeStatus.fromMap(data ?? const {});
  }

  static Future<void> requestDndAccess() =>
      _channel.invokeMethod<void>('requestDndAccess');

  static Future<void> requestExactAlarmAccess() =>
      _channel.invokeMethod<void>('requestExactAlarmAccess');

  static Future<void> requestBatteryOptimizationAccess() =>
      _channel.invokeMethod<void>('requestBatteryOptimizationAccess');

  static Future<MasjidModeStatus> start(int seconds) async {
    final data = await _channel.invokeMethod<Map<Object?, Object?>>(
      'start',
      {'seconds': seconds},
    );
    return MasjidModeStatus.fromMap(data ?? const {});
  }

  static Future<void> cancel() => _channel.invokeMethod<void>('cancel');
}
