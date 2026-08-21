import 'package:flutter_test/flutter_test.dart';
import 'package:noor_quran_masjid_mode/core/duration.dart';

void main() {
  test('converts hours, minutes, and seconds correctly', () {
    expect(durationPartsToSeconds(hours: 1, minutes: 2, seconds: 5), 3725);
  });

  test('supports Android background test durations in seconds', () {
    expect(isValidSessionDuration(10), isTrue);
    expect(formatDuration(10), '00:10');
  });

  test('limits duration to twenty-four hours', () {
    expect(durationPartsToSeconds(hours: 30, minutes: 10, seconds: 10), maxSessionSeconds);
  });
}
