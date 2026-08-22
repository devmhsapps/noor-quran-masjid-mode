import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'prayer_location.dart';

class PrayerPlace {
  const PrayerPlace({
    required this.id,
    required this.name,
    required this.fallbackName,
    required this.admin1Code,
    required this.admin2Code,
    required this.latitude,
    required this.longitude,
    required this.timezone,
    required this.population,
  });

  final String id;
  final String name;
  final String fallbackName;
  final String? admin1Code;
  final String? admin2Code;
  final double latitude;
  final double longitude;
  final String timezone;
  final int population;

  factory PrayerPlace.fromJson(Map<String, dynamic> json) => PrayerPlace(
        id: json['id'] as String,
        name: json['name'] as String,
        fallbackName: json['fallbackName'] as String,
        admin1Code: json['admin1'] as String?,
        admin2Code: json['admin2'] as String?,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        timezone: json['timezone'] as String,
        population: json['population'] as int? ?? 0,
      );

  PrayerLocation toPrayerLocation({PrayerLocationSource source = PrayerLocationSource.manual}) => PrayerLocation(
        id: id,
        name: name,
        country: 'العراق',
        admin1: admin1Code == null ? null : 'محافظة ${admin1Code!}',
        admin2: admin2Code,
        latitude: latitude,
        longitude: longitude,
        timezone: timezone,
        utcOffset: const Duration(hours: 3),
        source: source,
      );
}

class IraqPlaceCatalog {
  IraqPlaceCatalog._();

  static List<PrayerPlace>? _cache;

  static Future<List<PrayerPlace>> load() async {
    final cache = _cache;
    if (cache != null) return cache;
    final content = await rootBundle.loadString('assets/data/iraq_places.json');
    final decoded = jsonDecode(content) as Map<String, dynamic>;
    final places = (decoded['places'] as List<dynamic>).cast<Map<String, dynamic>>().map(PrayerPlace.fromJson).toList(growable: false);
    _cache = places;
    return places;
  }

  static Future<List<PrayerPlace>> search(String query, {int limit = 60}) async {
    final normalized = _normalize(query);
    final places = await load();
    if (normalized.isEmpty) return places.take(limit).toList(growable: false);
    return places.where((place) => _normalize(place.name).contains(normalized) || _normalize(place.fallbackName).contains(normalized)).take(limit).toList(growable: false);
  }

  static String _normalize(String value) => value.toLowerCase().replaceAll(RegExp(r"[‘’`']"), '').replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ').trim();
}
