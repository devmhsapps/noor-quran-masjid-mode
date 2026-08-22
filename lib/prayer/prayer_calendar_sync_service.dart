import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import 'prayer_location.dart';

class PrayerCalendarSyncService {
  PrayerCalendarSyncService._();
  static final instance = PrayerCalendarSyncService._();

  static const _prefix = 'mueen_monthly_prayer_calendar_';

  Future<PrayerCalendarSyncResult> syncCurrentAndNext(PrayerLocation location, {bool force = false}) async {
    final now = DateTime.now();
    final current = await _syncMonth(location, now.year, now.month, force: force);
    final nextDate = DateTime(now.year, now.month + 1);
    final next = await _syncMonth(location, nextDate.year, nextDate.month, force: force);
    return PrayerCalendarSyncResult(current: current, next: next);
  }

  Future<PrayerCalendarMonth> _syncMonth(PrayerLocation location, int year, int month, {required bool force}) async {
    final preferences = await SharedPreferences.getInstance();
    final key = _key(location, year, month);
    final existing = preferences.getString(key);
    if (!force && existing != null) {
      final cached = PrayerCalendarMonth.fromJson(jsonDecode(existing) as Map<String, dynamic>);
      if (DateTime.now().difference(cached.fetchedAt) < const Duration(hours: 6)) return cached;
    }

    final query = {
      'latitude': location.latitude.toStringAsFixed(6),
      'longitude': location.longitude.toStringAsFixed(6),
      'method': '1',
      'school': '1',
      'timezonestring': location.timezone,
    };
    final uri = Uri.https('api.aladhan.com', '/v1/calendar/$year/$month', query);
    final client = HttpClient();
    try {
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw PrayerCalendarSyncException('تعذر تحديث تقويم المواقيت الآن.');
      }
      final raw = await utf8.decoder.bind(response).join();
      final payload = jsonDecode(raw) as Map<String, dynamic>;
      final data = payload['data'];
      if (data is! List) throw PrayerCalendarSyncException('استجابة تقويم المواقيت غير مكتملة.');
      final monthData = PrayerCalendarMonth(
        locationId: location.id,
        year: year,
        month: month,
        fetchedAt: DateTime.now(),
        source: 'AlAdhan',
        method: 'Karachi (1)',
        entries: data.cast<Map<String, dynamic>>(),
      );
      await preferences.setString(key, jsonEncode(monthData.toJson()));
      return monthData;
    } on SocketException {
      throw PrayerCalendarSyncException('يلزم اتصال بالإنترنت لتحديث التقويم المرجعي.');
    } finally {
      client.close(force: true);
    }
  }

  Future<PrayerCalendarMonth?> cachedMonth(PrayerLocation location, DateTime date) async {
    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.getString(_key(location, date.year, date.month));
    return stored == null ? null : PrayerCalendarMonth.fromJson(jsonDecode(stored) as Map<String, dynamic>);
  }

  String _key(PrayerLocation location, int year, int month) => '$_prefix${location.id}_${year}_${month.toString().padLeft(2, '0')}';
}

class PrayerCalendarMonth {
  const PrayerCalendarMonth({
    required this.locationId,
    required this.year,
    required this.month,
    required this.fetchedAt,
    required this.source,
    required this.method,
    required this.entries,
  });

  final String locationId;
  final int year;
  final int month;
  final DateTime fetchedAt;
  final String source;
  final String method;
  final List<Map<String, dynamic>> entries;

  Map<String, Object?> toJson() => {
        'locationId': locationId,
        'year': year,
        'month': month,
        'fetchedAt': fetchedAt.toIso8601String(),
        'source': source,
        'method': method,
        'entries': entries,
      };

  factory PrayerCalendarMonth.fromJson(Map<String, dynamic> json) => PrayerCalendarMonth(
        locationId: json['locationId'] as String,
        year: json['year'] as int,
        month: json['month'] as int,
        fetchedAt: DateTime.parse(json['fetchedAt'] as String),
        source: json['source'] as String,
        method: json['method'] as String,
        entries: (json['entries'] as List<dynamic>).cast<Map<String, dynamic>>(),
      );
}

class PrayerCalendarSyncResult {
  const PrayerCalendarSyncResult({required this.current, required this.next});
  final PrayerCalendarMonth current;
  final PrayerCalendarMonth next;
}

class PrayerCalendarSyncException implements Exception {
  const PrayerCalendarSyncException(this.message);
  final String message;

  @override
  String toString() => message;
}
