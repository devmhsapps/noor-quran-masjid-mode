import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'prayer_calculator.dart';

class PrayerNotificationService {
  PrayerNotificationService._();
  static final instance = PrayerNotificationService._();

  static const _channelId = 'mueen_adhan_local_v1';
  static const _notificationBaseId = 4100;
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    const settings = InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher'));
    await _plugin.initialize(settings);
    const channel = AndroidNotificationChannel(
      _channelId,
      'تنبيهات الأذان المحلية',
      description: 'تنبيهات المواقيت التي تحسب داخل مَعين دون إنترنت',
      importance: Importance.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('adhan'),
    );
    await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(channel);
    _initialized = true;
  }

  Future<void> scheduleNext24Hours(String cityName) async {
    await initialize();
    final location = tz.getLocation(_timeZoneFor(cityName));
    final now = DateTime.now();
    final moments = <PrayerMoment>[];
    for (var dayOffset = 0; dayOffset <= 1; dayOffset++) {
      final date = DateTime(now.year, now.month, now.day).add(Duration(days: dayOffset));
      final schedule = PrayerCalculator.forCity(cityName, now: date);
      if (schedule != null) moments.addAll(schedule.entries.where((entry) => entry.time.isAfter(now)));
    }
    moments.sort((a, b) => a.time.compareTo(b.time));
    for (var index = 0; index < 10; index++) {
      await _plugin.cancel(_notificationBaseId + index);
    }
    for (var index = 0; index < moments.length && index < 10; index++) {
      final moment = moments[index];
      await _plugin.zonedSchedule(
        _notificationBaseId + index,
        'حان وقت صلاة ${moment.label}',
        'تقبل الله طاعتكم',
        tz.TZDateTime.from(moment.time, location),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            'تنبيهات الأذان المحلية',
            channelDescription: 'تنبيهات المواقيت التي تحسب داخل مَعين دون إنترنت',
            importance: Importance.max,
            priority: Priority.max,
            sound: RawResourceAndroidNotificationSound('adhan'),
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    }
  }

  String _timeZoneFor(String cityName) => switch (cityName) {
        'مكة المكرمة' || 'المدينة المنورة' => 'Asia/Riyadh',
        _ => 'Asia/Baghdad',
      };
}
