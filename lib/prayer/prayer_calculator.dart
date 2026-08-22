import 'package:adhan/adhan.dart';

import 'prayer_location.dart';

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

class NightFastingInfo {
  const NightFastingInfo({
    required this.city,
    required this.fajr,
    required this.maghrib,
    required this.nextFajr,
    required this.fastingDuration,
    required this.afterIftarDuration,
    required this.nightDuration,
    required this.middleOfNight,
    required this.lastThirdStarts,
  });

  final PrayerCity city;
  final DateTime fajr;
  final DateTime maghrib;
  final DateTime nextFajr;
  final Duration fastingDuration;
  final Duration afterIftarDuration;
  final Duration nightDuration;
  final DateTime middleOfNight;
  final DateTime lastThirdStarts;
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
    return _scheduleFor(city, now ?? DateTime.now());
  }

  static PrayerSchedule forLocation(PrayerLocation location, {DateTime? now}) {
    final city = PrayerCity(
      name: location.name,
      latitude: location.latitude,
      longitude: location.longitude,
      utcOffset: location.utcOffset,
    );
    return _scheduleFor(city, now ?? DateTime.now());
  }

  static PrayerSchedule _scheduleFor(PrayerCity city, DateTime current) {
    final today = _timesFor(city, current);
    final tomorrow = _timesFor(city, current.add(const Duration(days: 1)));
    final entries = _entriesFor(today);
    final next = entries.where((entry) => entry.time.isAfter(current)).cast<PrayerMoment?>().firstOrNull ?? _entriesFor(tomorrow).first;
    return PrayerSchedule(city: city, entries: entries, next: next);
  }

  static NightFastingInfo? nightFastingForCity(String cityName, {DateTime? now}) {
    final city = cities.where((item) => item.name == cityName).cast<PrayerCity?>().firstOrNull;
    if (city == null) return null;
    return _nightFastingFor(city, now ?? DateTime.now());
  }

  static NightFastingInfo nightFastingForLocation(PrayerLocation location, {DateTime? now}) {
    final city = PrayerCity(
      name: location.name,
      latitude: location.latitude,
      longitude: location.longitude,
      utcOffset: location.utcOffset,
    );
    return _nightFastingFor(city, now ?? DateTime.now());
  }

  static NightFastingInfo _nightFastingFor(PrayerCity city, DateTime current) {
    final today = _timesFor(city, current);
    final tomorrow = _timesFor(city, current.add(const Duration(days: 1)));
    final nightDuration = tomorrow.fajr.difference(today.maghrib);
    return NightFastingInfo(
      city: city,
      fajr: today.fajr,
      maghrib: today.maghrib,
      nextFajr: tomorrow.fajr,
      fastingDuration: today.maghrib.difference(today.fajr),
      afterIftarDuration: tomorrow.fajr.difference(today.maghrib),
      nightDuration: nightDuration,
      middleOfNight: today.maghrib.add(Duration(minutes: nightDuration.inMinutes ~/ 2)),
      lastThirdStarts: today.maghrib.add(Duration(minutes: (nightDuration.inMinutes * 2) ~/ 3)),
    );
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

  static String formatDuration(Duration duration) {
    final minutes = duration.inMinutes.abs();
    final hours = minutes ~/ 60;
    final remainder = minutes % 60;
    return '$hours س $remainder د';
  }
}

extension on Iterable<PrayerCity?> {
  PrayerCity? get firstOrNull => isEmpty ? null : first;
}

extension on Iterable<PrayerMoment?> {
  PrayerMoment? get firstOrNull => isEmpty ? null : first;
}
