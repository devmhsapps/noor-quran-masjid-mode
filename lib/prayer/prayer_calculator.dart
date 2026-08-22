import 'package:adhan/adhan.dart';

class PrayerCity {
  const PrayerCity({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.utcOffset,
  });

  final String name;
  final double latitude;
  final double longitude;
  final Duration utcOffset;
}

class PrayerMoment {
  const PrayerMoment({required this.id, required this.label, required this.time});

  final String id;
  final String label;
  final DateTime time;
}

class PrayerSchedule {
  const PrayerSchedule({required this.city, required this.entries, required this.next});

  final PrayerCity city;
  final List<PrayerMoment> entries;
  final PrayerMoment next;
}

class PrayerCalculator {
  static const cities = <PrayerCity>[
    PrayerCity(name: 'بغداد', latitude: 33.3152, longitude: 44.3661, utcOffset: Duration(hours: 3)),
    PrayerCity(name: 'مكة المكرمة', latitude: 21.3891, longitude: 39.8579, utcOffset: Duration(hours: 3)),
    PrayerCity(name: 'المدينة المنورة', latitude: 24.5247, longitude: 39.5692, utcOffset: Duration(hours: 3)),
    PrayerCity(name: 'النجف', latitude: 31.9956, longitude: 44.3147, utcOffset: Duration(hours: 3)),
    PrayerCity(name: 'البصرة', latitude: 30.5085, longitude: 47.7804, utcOffset: Duration(hours: 3)),
  ];

  static PrayerSchedule? forCity(String cityName, {DateTime? now}) {
    final city = cities.where((item) => item.name == cityName).cast<PrayerCity?>().firstOrNull;
    if (city == null) return null;
    final current = now ?? DateTime.now();
    final today = _timesFor(city, current);
    final tomorrow = _timesFor(city, current.add(const Duration(days: 1)));
    final entries = _entriesFor(today);
    final next = entries.where((entry) => entry.time.isAfter(current)).cast<PrayerMoment?>().firstOrNull ?? _entriesFor(tomorrow).first;
    return PrayerSchedule(city: city, entries: entries, next: next);
  }

  static PrayerTimes _timesFor(PrayerCity city, DateTime date) {
    final parameters = CalculationMethod.karachi.getParameters();
    parameters.madhab = Madhab.hanafi;
    return PrayerTimes(
      Coordinates(city.latitude, city.longitude),
      DateComponents.from(date),
      parameters,
      utcOffset: city.utcOffset,
    );
  }

  static List<PrayerMoment> _entriesFor(PrayerTimes times) => [
        PrayerMoment(id: 'fajr', label: 'الفجر', time: times.fajr),
        PrayerMoment(id: 'dhuhr', label: 'الظهر', time: times.dhuhr),
        PrayerMoment(id: 'asr', label: 'العصر', time: times.asr),
        PrayerMoment(id: 'maghrib', label: 'المغرب', time: times.maghrib),
        PrayerMoment(id: 'isha', label: 'العشاء', time: times.isha),
      ];

  static String formatTime(DateTime time) {
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'م' : 'ص';
    return '$hour:$minute $period';
  }

  static String remainingLabel(DateTime now, DateTime target) {
    final difference = target.difference(now);
    if (difference.isNegative) return 'انتهى الوقت';
    final hours = difference.inHours;
    final minutes = difference.inMinutes.remainder(60);
    if (hours == 0) return 'بعد $minutes دقيقة';
    return 'بعد $hours ساعة و$minutes د';
  }
}

extension on Iterable<PrayerCity?> {
  PrayerCity? get firstOrNull => isEmpty ? null : first;
}

extension on Iterable<PrayerMoment?> {
  PrayerMoment? get firstOrNull => isEmpty ? null : first;
}
