import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'quran_repository.dart';

class QuranReadingData {
  const QuranReadingData({
    required this.bookmarkColors,
    required this.favorites,
    required this.notes,
    this.plan,
  });

  final Map<String, String> bookmarkColors;
  final Set<String> favorites;
  final Map<String, String> notes;
  final QuranKhatmahPlan? plan;
}

class QuranKhatmahPlan {
  const QuranKhatmahPlan({
    required this.startedAt,
    required this.durationDays,
  });

  final DateTime startedAt;
  final int durationDays;

  DateTime get endsAt => startedAt.add(Duration(days: durationDays));

  int get dailyVerses => (6236 / durationDays).ceil();

  Map<String, dynamic> toJson() => {
        'startedAt': startedAt.toIso8601String(),
        'durationDays': durationDays,
      };

  factory QuranKhatmahPlan.fromJson(Map<String, dynamic> json) => QuranKhatmahPlan(
        startedAt: DateTime.parse(json['startedAt'] as String),
        durationDays: json['durationDays'] as int,
      );
}

class QuranReadingStore {
  static const _bookmarkColorsKey = 'quran_bookmark_colors_v1';
  static const _favoritesKey = 'quran_favorites_v1';
  static const _notesKey = 'quran_notes_v1';
  static const _planKey = 'quran_khatmah_plan_v1';

  static const bookmarkColorOptions = <String, String>{
    'gold': 'ذهبي',
    'green': 'أخضر',
    'blue': 'أزرق',
    'red': 'أحمر',
  };

  static Future<QuranReadingData> load() async {
    final preferences = await SharedPreferences.getInstance();
    final bookmarkColors = _decodeStringMap(preferences.getString(_bookmarkColorsKey));
    final legacyBookmarks = preferences.getStringList('quran_bookmarks') ?? const <String>[];
    for (final key in legacyBookmarks) {
      bookmarkColors.putIfAbsent(key, () => 'gold');
    }
    final favorites = (preferences.getStringList(_favoritesKey) ?? const <String>[]).toSet();
    final notes = _decodeStringMap(preferences.getString(_notesKey));
    final planRaw = preferences.getString(_planKey);
    QuranKhatmahPlan? plan;
    if (planRaw != null) {
      try {
        plan = QuranKhatmahPlan.fromJson(Map<String, dynamic>.from(jsonDecode(planRaw) as Map));
      } catch (_) {
        await preferences.remove(_planKey);
      }
    }
    return QuranReadingData(
      bookmarkColors: bookmarkColors,
      favorites: favorites,
      notes: notes,
      plan: plan,
    );
  }

  static Future<void> saveBookmark(String key, String? color) async {
    final preferences = await SharedPreferences.getInstance();
    final values = _decodeStringMap(preferences.getString(_bookmarkColorsKey));
    if (color == null) {
      values.remove(key);
    } else {
      values[key] = color;
    }
    await preferences.setString(_bookmarkColorsKey, jsonEncode(values));
    await preferences.setStringList('quran_bookmarks', values.keys.toList()..sort());
  }

  static Future<void> saveFavorite(String key, bool enabled) async {
    final preferences = await SharedPreferences.getInstance();
    final values = (preferences.getStringList(_favoritesKey) ?? const <String>[]).toSet();
    if (enabled) {
      values.add(key);
    } else {
      values.remove(key);
    }
    await preferences.setStringList(_favoritesKey, values.toList()..sort());
  }

  static Future<void> saveNote(String key, String note) async {
    final preferences = await SharedPreferences.getInstance();
    final values = _decodeStringMap(preferences.getString(_notesKey));
    final cleaned = note.trim();
    if (cleaned.isEmpty) {
      values.remove(key);
    } else {
      values[key] = cleaned;
    }
    await preferences.setString(_notesKey, jsonEncode(values));
  }

  static Future<void> savePlan(QuranKhatmahPlan plan) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_planKey, jsonEncode(plan.toJson()));
  }

  static Future<void> clearPlan() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_planKey);
  }

  static String positionKey(int surah, int verse) => '$surah:$verse';

  static int globalVerseIndex(List<QuranSurah> surahs, int surahNumber, int verseNumber) {
    var count = 0;
    for (final surah in surahs) {
      if (surah.number == surahNumber) {
        return count + verseNumber;
      }
      count += surah.verses.length;
    }
    return 0;
  }

  static Map<String, String> _decodeStringMap(String? raw) {
    if (raw == null || raw.isEmpty) return <String, String>{};
    try {
      final json = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      return json.map((key, value) => MapEntry(key, value.toString()));
    } catch (_) {
      return <String, String>{};
    }
  }
}
