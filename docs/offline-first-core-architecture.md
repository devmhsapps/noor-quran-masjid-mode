# بنية مَعين الأساسية دون إنترنت

> **النطاق:** قرآن نصي ومواقيت صلاة فقط. الحسابات وبيانات المدن والمصحف والإشعارات تعمل محلياً، ولا تُستخدم أي واجهة API أو تلاوات شبكية.

## 1. الاعتماديات المقترحة

أبقِ `adhan` و`flutter_local_notifications` الموجودتين في المشروع، وأضف الآتي بعد التحقق من توافق الإصدارات مع Flutter الحالي عبر `flutter pub outdated`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^3.0.0
  adhan: ^2.0.0-nullsafety.1
  geolocator: ^14.0.2
  flutter_local_notifications: ^19.3.1
  timezone: ^0.10.1
  flutter_timezone: ^4.1.1
  sqflite: ^2.4.2
  path: ^1.9.1
  shared_preferences: ^2.5.3
  permission_handler: ^12.0.1
```

أضف أصول التطبيق:

```yaml
flutter:
  assets:
    - assets/data/cities.json
    - assets/db/quran_uthmani.sqlite
  fonts:
    - family: KfgqpcUthmanic
      fonts:
        - asset: assets/fonts/KFGQPC-Uthmanic-Script-HAFS.ttf
```

يجب الحصول على خط **KFGQPC Uthmanic Script HAFS** من مصدر يجيز إعادة توزيعه داخل APK، مع الاحتفاظ بشروط الخط. إلى أن تتأكد الرخصة، يبقى خط `AmiriQuran.ttf` المضمّن حالياً هو البديل الآمن.

## 2. هيكل الملفات

```text
lib/
  app/
    app.dart
    bootstrap.dart
  core/
    result.dart
    time/timezone_bootstrap.dart
  features/
    prayer/
      data/local_city_repository.dart
      domain/prayer_models.dart
      domain/prayer_times_service.dart
      application/prayer_controller.dart
      notifications/prayer_notification_scheduler.dart
      presentation/prayer_screen.dart
    location/
      data/location_service.dart
      application/location_controller.dart
    quran/
      data/quran_database.dart
      domain/quran_models.dart
      application/quran_page_controller.dart
      presentation/quran_page_view.dart
assets/
  data/cities.json
  db/quran_uthmani.sqlite
  fonts/KFGQPC-Uthmanic-Script-HAFS.ttf
android/app/src/main/res/raw/adhan.mp3
```

يفصل هذا الهيكل العرض عن حالة التطبيق والمنطق. يمكن استخدام Riverpod عبر `Notifier`/`AsyncNotifier`، بحيث لا تتعامل الـ widgets مع SQLite أو GPS أو `adhan` مباشرة.

```dart
// features/prayer/application/prayer_controller.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/prayer_times_service.dart';

final prayerTimesServiceProvider = Provider((_) => PrayerTimesService());

final prayerScheduleProvider =
    AsyncNotifierProvider<PrayerScheduleController, DailyPrayerSchedule>(
  PrayerScheduleController.new,
);

class PrayerScheduleController extends AsyncNotifier<DailyPrayerSchedule> {
  @override
  Future<DailyPrayerSchedule> build() => _forCoordinates(33.3152, 44.3661);

  Future<void> refreshForCoordinates(double latitude, double longitude) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _forCoordinates(latitude, longitude));
  }

  Future<DailyPrayerSchedule> _forCoordinates(double latitude, double longitude) async {
    return ref.read(prayerTimesServiceProvider).calculate(
      date: DateTime.now(), latitude: latitude, longitude: longitude,
    );
  }
}
```

## 3. المدن المحلية والموقع الاختياري

يكون `assets/data/cities.json` ثابتاً داخل التطبيق:

```json
[
  {"id":"baghdad","nameAr":"بغداد","countryAr":"العراق","lat":33.3152,"lng":44.3661},
  {"id":"makkah","nameAr":"مكة","countryAr":"السعودية","lat":21.4225,"lng":39.8262}
]
```

لا تطلب صلاحية الموقع عند فتح التطبيق. لا تُستدعى إلا عندما يضغط المستخدم **«تحديد موقعي تلقائياً»**. عند الرفض أو إيقاف GPS يبقى آخر اختيار يدوي محفوظاً، ولا تتوقف المواقيت أو المصحف.

```dart
// features/location/data/location_service.dart
import 'package:geolocator/geolocator.dart';

class DeviceLocationService {
  Future<Position> getCurrentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw StateError('خدمة الموقع غير مفعلة');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw StateError('لم يُمنح إذن الموقع');
    }
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
    );
  }
}
```

## 4. منطق المواقيت المحلي

```dart
// features/prayer/domain/prayer_times_service.dart
import 'package:adhan/adhan.dart';

enum PrayerId { fajr, sunrise, dhuhr, asr, maghrib, isha }

class PrayerEntry {
  const PrayerEntry(this.id, this.labelAr, this.at);
  final PrayerId id;
  final String labelAr;
  final DateTime at;
}

class DailyPrayerSchedule {
  const DailyPrayerSchedule({required this.date, required this.entries});
  final DateTime date;
  final List<PrayerEntry> entries;

  PrayerEntry get next {
    final now = DateTime.now();
    return entries.firstWhere(
      (entry) => entry.at.isAfter(now),
      orElse: () => entries.first,
    );
  }
}

class PrayerTimesService {
  DailyPrayerSchedule calculate({
    required DateTime date,
    required double latitude,
    required double longitude,
    CalculationMethod method = CalculationMethod.muslimWorldLeague,
    Madhab madhab = Madhab.shafi,
  }) {
    final parameters = method.getParameters()..madhab = madhab;
    final times = PrayerTimes(
      Coordinates(latitude, longitude),
      DateComponents(date.year, date.month, date.day),
      parameters,
    );
    return DailyPrayerSchedule(
      date: DateTime(date.year, date.month, date.day),
      entries: [
        PrayerEntry(PrayerId.fajr, 'الفجر', times.fajr),
        PrayerEntry(PrayerId.sunrise, 'الشروق', times.sunrise),
        PrayerEntry(PrayerId.dhuhr, 'الظهر', times.dhuhr),
        PrayerEntry(PrayerId.asr, 'العصر', times.asr),
        PrayerEntry(PrayerId.maghrib, 'المغرب', times.maghrib),
        PrayerEntry(PrayerId.isha, 'العشاء', times.isha),
      ],
    );
  }
}
```

## 5. SQLite للمصحف من الأصول

استخدم نص Tanzil العثماني **دون تعديل حرفي**، وأظهر المصدر والرابط داخل «حول التطبيق». ترخيص Tanzil يسمح بالتوزيع الحرفي داخل التطبيقات بشرط نسبة المصدر والرابط، ويمنع تغيير النص.[1] لا يجب صناعة صفحات مصحف من تقسيم عشوائي للآيات؛ جدول `pages` يجب أن يأتي من مصدر موثق لمواضع صفحات مصحف حفص.

الحد الأدنى المقترح للقاعدة:

```sql
CREATE TABLE surahs(number INTEGER PRIMARY KEY, name_ar TEXT, ayah_count INTEGER);
CREATE TABLE verses(
  surah_number INTEGER, ayah_number INTEGER, page_number INTEGER,
  uthmani TEXT NOT NULL, PRIMARY KEY(surah_number, ayah_number)
);
CREATE INDEX verses_by_page ON verses(page_number, surah_number, ayah_number);
```

```dart
// features/quran/data/quran_database.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class QuranVerse {
  const QuranVerse({required this.surah, required this.ayah, required this.text});
  final int surah;
  final int ayah;
  final String text;
}

class QuranDatabase {
  QuranDatabase._();
  static final instance = QuranDatabase._();
  Database? _database;

  Future<Database> get database async => _database ??= await _open();

  Future<Database> _open() async {
    final target = p.join(await getDatabasesPath(), 'quran_uthmani_v1.sqlite');
    if (!await File(target).exists()) {
      final ByteData bytes = await rootBundle.load('assets/db/quran_uthmani.sqlite');
      await File(target).writeAsBytes(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        flush: true,
      );
    }
    return openDatabase(target, readOnly: true, singleInstance: true);
  }

  Future<List<QuranVerse>> versesForPage(int pageNumber) async {
    final db = await database;
    final rows = await db.query(
      'verses',
      columns: ['surah_number', 'ayah_number', 'uthmani'],
      where: 'page_number = ?',
      whereArgs: [pageNumber],
      orderBy: 'surah_number, ayah_number',
    );
    return rows.map((row) => QuranVerse(
      surah: row['surah_number']! as int,
      ayah: row['ayah_number']! as int,
      text: row['uthmani']! as String,
    )).toList(growable: false);
  }

  Future<void> close() async { await _database?.close(); _database = null; }
}
```

تُغذى واجهة القراءة من `PageView.builder(itemCount: 604)`، ويطلب `versesForPage(index + 1)` عبر `AsyncNotifier` مع ذاكرة مؤقتة للصفحة السابقة والحالية والتالية.

## 6. إشعارات الأذان المحلية

| النهج | الوصف | الاعتمادية | التعقيد |
|---|---|---:|---:|
| جدولة محلية يومية | إعادة جدولة الصلوات القادمة محلياً عند فتح التطبيق أو عند تغير المدينة | جيدة | منخفض |
| منبّه Android أصلي إضافي | دمج AlarmManager/Receiver مع خدمة وضع الجامع الموجودة | أعلى على Android | متوسط |

المسار الأنسب لمَعين هو **الجمع بينهما**: جدولة الإشعارات محلياً، والإبقاء على مستقبل Android الحالي للعمليات الحساسة مثل وضع الجامع. لا تعِد بأن صوتاً طويلاً سيعمل بصورة موحّدة على كل جهاز؛ سياسات Android وقنوات الإشعار وإعدادات المستخدم تظل حاكمة.

ضع الصوت في `android/app/src/main/res/raw/adhan.mp3` بالاسم الصغير فقط. القناة في Android 8+ ثابتة بعد إنشائها، لذلك غيّر `channelId` عند تغيير الصوت الافتراضي.

```dart
// features/prayer/notifications/prayer_notification_scheduler.dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../domain/prayer_times_service.dart';

class PrayerNotificationScheduler {
  PrayerNotificationScheduler(this._notifications);
  final FlutterLocalNotificationsPlugin _notifications;
  static const _channelId = 'adhan_channel_v1';

  Future<void> initialize() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _notifications.initialize(const InitializationSettings(android: android));
    const channel = AndroidNotificationChannel(
      _channelId,
      'تنبيهات الصلاة',
      description: 'إشعارات الأذان المحلية',
      importance: Importance.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('adhan'),
    );
    await _notifications.resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(channel);
  }

  Future<void> schedule(DailyPrayerSchedule schedule) async {
    await _notifications.cancelAll();
    for (final entry in schedule.entries.where((e) => e.id != PrayerId.sunrise)) {
      final at = tz.TZDateTime.from(entry.at, tz.local);
      if (at.isBefore(tz.TZDateTime.now(tz.local))) continue;
      await _notifications.zonedSchedule(
        1000 + entry.id.index,
        'حان وقت صلاة ${entry.labelAr}',
        'تقبل الله طاعتكم',
        at,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId, 'تنبيهات الصلاة',
            channelDescription: 'إشعارات الأذان المحلية',
            importance: Importance.max, priority: Priority.max,
            sound: RawResourceAndroidNotificationSound('adhan'),
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    }
  }
}
```

يتطلب التطبيق إعداد المنطقة الزمنية عند الإقلاع، وطلب `POST_NOTIFICATIONS` في Android 13+، وإعداد المنبه الدقيق عندما تختار نموذج الإشعارات الدقيقة. بعد تغيّر المدينة أو GPS، أعد الحساب ثم ألغِ الجدولة السابقة وجدول صلاة اليوم فقط، وجدول اليوم التالي عند أول فتح بعد منتصف الليل.

```dart
// core/time/timezone_bootstrap.dart
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

Future<void> initializeDeviceTimezone() async {
  tz_data.initializeTimeZones();
  final local = await FlutterTimezone.getLocalTimezone();
  tz.setLocalLocation(tz.getLocation(local.name));
}
```

## 7. ضوابط الإنتاج

ينبغي اختبار الحساب على مدن يدوية معروفة قبل النشر، وعدم استعمال بيانات العرض في الصور كقيم حقيقية. يجب التحقق من 114 سورة و6236 آية، ومراجعة مصدر وخريطة صفحات القاعدة قبل شحنها. أضف اختباراً لوحدة `PrayerTimesService` واختباراً لنسخ ملف SQLite وقراءة صفحة محددة.

## المراجع

[1]: https://tanzil.net/docs/text_license "Tanzil Quran Text License"
[2]: https://tanzil.net/download/ "Tanzil Quran Text Download"
[3]: https://pub.dev/packages/sqflite "sqflite package"
[4]: https://pub.dev/packages/geolocator "geolocator package"
[5]: https://pub.dev/packages/flutter_local_notifications "flutter_local_notifications package"
