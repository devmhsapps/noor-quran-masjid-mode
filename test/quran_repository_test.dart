import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:noor_quran_masjid_mode/quran/quran_reading_store.dart';
import 'package:noor_quran_masjid_mode/quran/quran_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('تحميل المصحف المحلي كاملاً', () async {
    final surahs = await QuranRepository.load();

    expect(surahs, hasLength(114));
    expect(surahs.first.name, 'الفاتحة');
    expect(surahs.first.verses, hasLength(7));
    expect(surahs.last.name, 'الناس');
    expect(surahs.fold<int>(0, (total, surah) => total + surah.verses.length), 6236);
  });

  test('البحث المحلي يعيد آيات من النص المدمج', () async {
    final surahs = await QuranRepository.load();
    final results = QuranRepository.search(surahs, 'ٱلۡحَمۡدُ');

    expect(results, isNotEmpty);
    expect(results.first.surah.name, 'الفاتحة');
    expect(results.first.verse.number, 2);
  });

  test('تحفظ أدوات القراءة العلامات والمفضلة والملاحظات محلياً', () async {
    SharedPreferences.setMockInitialValues({});
    const key = '1:2';

    await QuranReadingStore.saveBookmark(key, 'green');
    await QuranReadingStore.saveFavorite(key, true);
    await QuranReadingStore.saveNote(key, 'تأمل خاص');
    final data = await QuranReadingStore.load();

    expect(data.bookmarkColors[key], 'green');
    expect(data.favorites, contains(key));
    expect(data.notes[key], 'تأمل خاص');
  });

  test('تحفظ خطة الختمة وتحسب الورد اليومي', () async {
    SharedPreferences.setMockInitialValues({});
    final plan = QuranKhatmahPlan(startedAt: DateTime(2026, 8, 22), durationDays: 30);

    await QuranReadingStore.savePlan(plan);
    final data = await QuranReadingStore.load();

    expect(data.plan, isNotNull);
    expect(data.plan!.durationDays, 30);
    expect(data.plan!.dailyVerses, 208);
    expect(data.plan!.endsAt, DateTime(2026, 9, 21));
  });
}
