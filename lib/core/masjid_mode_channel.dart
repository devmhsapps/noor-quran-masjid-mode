import 'package:flutter/services.dart';

class MasjidModeStatus {
  const MasjidModeStatus({
    required this.active,
    required this.dndAccessGranted,
    this.endsAt,
  });

  final bool active;
  final bool dndAccessGranted;
  final int? endsAt;

  factory MasjidModeStatus.fromMap(Map<Object?, Object?> data) {
    return MasjidModeStatus(
      active: data['active'] == true,
      dndAccessGranted: data['dndAccessGranted'] == true,
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

  static Future<MasjidModeStatus> start(int seconds) async {
    final data = await _channel.invokeMethod<Map<Object?, Object?>>(
      'start',
      {'seconds': seconds},
    );
    return MasjidModeStatus.fromMap(data ?? const {});
  }

  static Future<void> cancel() => _channel.invokeMethod<void>('cancel');
}
