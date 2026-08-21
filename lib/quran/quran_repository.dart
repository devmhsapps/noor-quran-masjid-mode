import 'dart:convert';

import 'package:flutter/services.dart';

class QuranVerse {
  const QuranVerse({required this.number, required this.text});

  final int number;
  final String text;

  factory QuranVerse.fromJson(Map<String, dynamic> json) => QuranVerse(
        number: json['id'] as int,
        text: json['text'] as String,
      );
}

class QuranSurah {
  const QuranSurah({
    required this.number,
    required this.name,
    required this.transliteration,
    required this.revelationType,
    required this.verses,
  });

  final int number;
  final String name;
  final String transliteration;
  final String revelationType;
  final List<QuranVerse> verses;

  factory QuranSurah.fromJson(Map<String, dynamic> json) {
    final rawVerses = json['verses'] as List<dynamic>;
    return QuranSurah(
      number: json['id'] as int,
      name: json['name'] as String,
      transliteration: json['transliteration'] as String,
      revelationType: json['type'] as String,
      verses: rawVerses
          .map((verse) => QuranVerse.fromJson(Map<String, dynamic>.from(verse as Map)))
          .toList(growable: false),
    );
  }
}

class QuranSearchMatch {
  const QuranSearchMatch({required this.surah, required this.verse});

  final QuranSurah surah;
  final QuranVerse verse;
}

class QuranRepository {
  static Future<List<QuranSurah>> load() async {
    final raw = await rootBundle.loadString('assets/data/quran.json');
    final records = jsonDecode(raw) as List<dynamic>;
    return records
        .map((record) => QuranSurah.fromJson(Map<String, dynamic>.from(record as Map)))
        .toList(growable: false);
  }

  static List<QuranSearchMatch> search(List<QuranSurah> surahs, String query) {
    final normalized = query.trim();
    if (normalized.isEmpty) return const [];
    final matches = <QuranSearchMatch>[];
    for (final surah in surahs) {
      for (final verse in surah.verses) {
        if (verse.text.contains(normalized)) {
          matches.add(QuranSearchMatch(surah: surah, verse: verse));
          if (matches.length == 80) return matches;
        }
      }
    }
    return matches;
  }
}
