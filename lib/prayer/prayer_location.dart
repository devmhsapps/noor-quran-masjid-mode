class PrayerLocation {
  const PrayerLocation({
    required this.id,
    required this.name,
    required this.country,
    required this.latitude,
    required this.longitude,
    required this.timezone,
    required this.utcOffset,
    this.admin1,
    this.admin2,
    this.source = PrayerLocationSource.manual,
  });

  final String id;
  final String name;
  final String country;
  final String? admin1;
  final String? admin2;
  final double latitude;
  final double longitude;
  final String timezone;
  final Duration utcOffset;
  final PrayerLocationSource source;

  String get label => [name, if (admin1 != null && admin1!.isNotEmpty) admin1, country].join('، ');

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'country': country,
        'admin1': admin1,
        'admin2': admin2,
        'latitude': latitude,
        'longitude': longitude,
        'timezone': timezone,
        'utcOffsetMinutes': utcOffset.inMinutes,
        'source': source.name,
      };

  factory PrayerLocation.fromJson(Map<String, Object?> json) => PrayerLocation(
        id: json['id'] as String,
        name: json['name'] as String,
        country: json['country'] as String,
        admin1: json['admin1'] as String?,
        admin2: json['admin2'] as String?,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        timezone: json['timezone'] as String,
        utcOffset: Duration(minutes: json['utcOffsetMinutes'] as int),
        source: PrayerLocationSource.values.byName((json['source'] as String?) ?? PrayerLocationSource.manual.name),
      );

  PrayerLocation copyWith({PrayerLocationSource? source}) => PrayerLocation(
        id: id,
        name: name,
        country: country,
        admin1: admin1,
        admin2: admin2,
        latitude: latitude,
        longitude: longitude,
        timezone: timezone,
        utcOffset: utcOffset,
        source: source ?? this.source,
      );
}

enum PrayerLocationSource { manual, gps }
