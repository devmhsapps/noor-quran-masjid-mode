import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'prayer_calculator.dart';

class PrayerNotificationService {
  PrayerNotificationService._();
  static final instance = PrayerNotificationService._();

  static const _adhanChannelId = 'mueen_adhan_local_v2';
  static const _reminderChannelId = 'mueen_prayer_reminders_v1';
  static const _iqamaChannelId = 'mueen_iqama_reminders_v1';
  static const _notificationBaseId = 4100;
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    const settings = InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher'));
    await _plugin.initialize(settings);
    const adhanChannel = AndroidNotificationChannel(
      _adhanChannelId,
      'تنبيهات الأذان المحلية',
      description: 'تنبيهات المواقيت التي تحسب داخل مَعين دون إنترنت',
      importance: Importance.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('adhan'),
    );
    const reminderChannel = AndroidNotificationChannel(
      _reminderChannelId,
      'تذكيرات ما قبل الصلاة',
      description: 'تذكيرات اختيارية قبل الأذان تعمل محلياً داخل مَعين',
      importance: Importance.high,
      playSound: true,
    );
    const iqamaChannel = AndroidNotificationChannel(
      _iqamaChannelId,
      'تنبيهات الإقامة',
      description: 'تنبيهات إقامة اختيارية تعمل محلياً داخل مَعين',
      importance: Importance.high,
      playSound: true,
    );
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(adhanChannel);
    await android?.createNotificationChannel(reminderChannel);
    await android?.createNotificationChannel(iqamaChannel);
    _initialized = true;
  }

  Future<void> scheduleNext24Hours(
    String cityName, {
    PrayerReminderSettings? settings,
  }) async {
    await initialize();
    final activeSettings = settings ?? await PrayerReminderSettingsStore.load();
    final location = tz.getLocation(_timeZoneFor(cityName));
    final now = DateTime.now();
    final moments = <PrayerMoment>[];
    for (var dayOffset = 0; dayOffset <= 1; dayOffset++) {
      final date = DateTime(now.year, now.month, now.day).add(Duration(days: dayOffset));
      final schedule = PrayerCalculator.forCity(cityName, now: date);
      if (schedule != null) moments.addAll(schedule.entries.where((entry) => entry.time.isAfter(now)));
    }
    moments.sort((a, b) => a.time.compareTo(b.time));
    for (var index = 0; index < 40; index++) {
      await _plugin.cancel(_notificationBaseId + index);
    }
    var notificationOffset = 0;
    for (var index = 0; index < moments.length && index < 10; index++) {
      final moment = moments[index];
      final beforeMinutes = activeSettings.beforeAdhanMinutesFor(moment.id);
      if (beforeMinutes > 0) {
        final reminderTime = moment.time.subtract(Duration(minutes: beforeMinutes));
        if (reminderTime.isAfter(now)) {
          await _schedule(
            id: _notificationBaseId + notificationOffset++,
            title: 'تذكير قبل أذان ${moment.label}',
            body: 'باقي $beforeMinutes دقائق على أذان ${moment.label}',
            time: reminderTime,
            location: location,
            details: const NotificationDetails(
              android: AndroidNotificationDetails(
                _reminderChannelId,
                'تذكيرات ما قبل الصلاة',
                channelDescription: 'تذكيرات اختيارية قبل الأذان تعمل محلياً داخل مَعين',
                importance: Importance.high,
                priority: Priority.high,
              ),
            ),
          );
        }
      }
      await _schedule(
        id: _notificationBaseId + notificationOffset++,
        title: 'حان وقت صلاة ${moment.label}',
        body: 'تقبل الله طاعتكم',
        time: moment.time,
        location: location,
        details: const NotificationDetails(
          android: AndroidNotificationDetails(
            _adhanChannelId,
            'تنبيهات الأذان المحلية',
            channelDescription: 'تنبيهات المواقيت التي تحسب داخل مَعين دون إنترنت',
            importance: Importance.max,
            priority: Priority.max,
            sound: RawResourceAndroidNotificationSound('adhan'),
          ),
        ),
      );
      final iqamaMinutes = activeSettings.iqamaMinutesFor(moment.id);
      if (iqamaMinutes > 0) {
        await _schedule(
          id: _notificationBaseId + notificationOffset++,
          title: 'حان وقت إقامة صلاة ${moment.label}',
          body: 'تقبل الله طاعتكم',
          time: moment.time.add(Duration(minutes: iqamaMinutes)),
          location: location,
          details: const NotificationDetails(
            android: AndroidNotificationDetails(
              _iqamaChannelId,
              'تنبيهات الإقامة',
              channelDescription: 'تنبيهات إقامة اختيارية تعمل محلياً داخل مَعين',
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
        );
      }
    }
  }

  Future<void> _schedule({
    required int id,
    required String title,
    required String body,
    required DateTime time,
    required tz.Location location,
    required NotificationDetails details,
  }) => _plugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(time, location),
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );

  String _timeZoneFor(String cityName) => switch (cityName) {
        'مكة المكرمة' || 'المدينة المنورة' => 'Asia/Riyadh',
        _ => 'Asia/Baghdad',
      };
}

class PrayerReminderSettings {
  const PrayerReminderSettings({
    this.beforeAdhanMinutes = 0,
    this.beforeAdhanByPrayer = const {},
    this.iqamaByPrayer = const {},
  });

  final int beforeAdhanMinutes;
  final Map<String, int> beforeAdhanByPrayer;
  final Map<String, int> iqamaByPrayer;

  int beforeAdhanMinutesFor(String prayerId) => beforeAdhanByPrayer[prayerId] ?? beforeAdhanMinutes;
  int iqamaMinutesFor(String prayerId) => iqamaByPrayer[prayerId] ?? 0;

  PrayerReminderSettings copyWith({
    int? beforeAdhanMinutes,
    Map<String, int>? beforeAdhanByPrayer,
    Map<String, int>? iqamaByPrayer,
  }) => PrayerReminderSettings(
        beforeAdhanMinutes: beforeAdhanMinutes ?? this.beforeAdhanMinutes,
        beforeAdhanByPrayer: beforeAdhanByPrayer ?? this.beforeAdhanByPrayer,
        iqamaByPrayer: iqamaByPrayer ?? this.iqamaByPrayer,
      );
}

class PrayerReminderSettingsStore {
  PrayerReminderSettingsStore._();

  static const _beforeMinutesKey = 'prayer_before_adhan_minutes';
  static const _iqamaPrefix = 'prayer_iqama_minutes_';

  static Future<PrayerReminderSettings> load() async {
    final preferences = await SharedPreferences.getInstance();
    final iqamaByPrayer = <String, int>{
      for (final prayer in const ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'])
        prayer: preferences.getInt('$_iqamaPrefix$prayer') ?? 0,
    };
    return PrayerReminderSettings(
      beforeAdhanMinutes: preferences.getInt(_beforeMinutesKey) ?? 0,
      iqamaByPrayer: iqamaByPrayer,
    );
  }

  static Future<void> save(PrayerReminderSettings settings) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(_beforeMinutesKey, settings.beforeAdhanMinutes.clamp(0, 60).toInt());
    for (final entry in settings.iqamaByPrayer.entries) {
      await preferences.setInt('$_iqamaPrefix${entry.key}', entry.value.clamp(0, 120).toInt());
    }
  }
}
