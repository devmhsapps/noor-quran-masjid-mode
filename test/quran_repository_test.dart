import 'package:flutter_test/flutter_test.dart';
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
}
