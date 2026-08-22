import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';

import 'prayer_location.dart';

class LocalPrayerCity {
  const LocalPrayerCity({required this.name, required this.latitude, required this.longitude});
  final String name;
  final double latitude;
  final double longitude;
}

class PrayerLocationService {
  static const supportedCities = <LocalPrayerCity>[
    LocalPrayerCity(name: 'بغداد', latitude: 33.3152, longitude: 44.3661),
    LocalPrayerCity(name: 'مكة المكرمة', latitude: 21.4225, longitude: 39.8262),
    LocalPrayerCity(name: 'المدينة المنورة', latitude: 24.5247, longitude: 39.5692),
    LocalPrayerCity(name: 'النجف', latitude: 31.9973, longitude: 44.3140),
    LocalPrayerCity(name: 'البصرة', latitude: 30.5085, longitude: 47.7804),
  ];

  Future<LocalPrayerCity> detectNearestCity() async {
    final position = await _currentPosition();
    return supportedCities.reduce((nearest, candidate) {
      final nearestDistance = _distance(position.latitude, position.longitude, nearest.latitude, nearest.longitude);
      final candidateDistance = _distance(position.latitude, position.longitude, candidate.latitude, candidate.longitude);
      return candidateDistance < nearestDistance ? candidate : nearest;
    });
  }

  Future<PrayerLocation> detectCurrentLocation() async {
    final position = await _currentPosition();
    final offset = DateTime.now().timeZoneOffset;
    return PrayerLocation(
      id: 'gps-${position.latitude.toStringAsFixed(5)}-${position.longitude.toStringAsFixed(5)}',
      name: 'موقعي الحالي',
      country: 'تحديد تلقائي',
      latitude: position.latitude,
      longitude: position.longitude,
      timezone: 'Asia/Baghdad',
      utcOffset: offset,
      source: PrayerLocationSource.gps,
    );
  }

  Future<Position> _currentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const PrayerLocationException('فعّل GPS من إعدادات الهاتف ثم حاول مرة أخرى.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw const PrayerLocationException('إذن الموقع موقوف من إعدادات النظام.');
    }
    if (permission == LocationPermission.denied) {
      throw const PrayerLocationException('لم تمنح إذن الموقع. يمكنك اختيار مدينة يدوياً.');
    }
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }

  double _distance(double lat1, double lon1, double lat2, double lon2) {
    const earthRadiusKm = 6371.0;
    final dLat = _radians(lat2 - lat1);
    final dLon = _radians(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_radians(lat1)) * math.cos(_radians(lat2)) * math.sin(dLon / 2) * math.sin(dLon / 2);
    return earthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  double _radians(double degrees) => degrees * math.pi / 180;
}

class PrayerLocationException implements Exception {
  const PrayerLocationException(this.message);
  final String message;
  @override
  String toString() => message;
}
