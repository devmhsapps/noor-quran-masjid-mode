import 'package:flutter_test/flutter_test.dart';
import 'package:noor_quran_masjid_mode/prayer/prayer_calculator.dart';

void main() {
  test('يحسِب جدول مواقيت محلياً للمدينة اليدوية', () {
    final schedule = PrayerCalculator.forCity('بغداد', now: DateTime(2026, 8, 22, 10));

    expect(schedule, isNotNull);
    expect(schedule!.entries, hasLength(5));
    expect(schedule.entries.map((entry) => entry.id), containsAll(<String>['fajr', 'dhuhr', 'asr', 'maghrib', 'isha']));
    expect(schedule.next.time.isAfter(DateTime(2026, 8, 22, 10)), isTrue);
  });

  test('لا يفبرك مواقيت لمدينة غير مدعومة', () {
    expect(PrayerCalculator.forCity('مدينة غير معروفة'), isNull);
  });
}
