import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:hijri/hijri_calendar.dart';

import '../prayer/place_catalog.dart';
import '../prayer/prayer_location.dart';
import '../prayer/prayer_notification_service.dart';
import '../ui/mueen_design.dart';

class MueenLocationScreen extends StatefulWidget {
  const MueenLocationScreen({super.key, required this.initialLocation, required this.onSave, required this.onAutoLocate});
  final PrayerLocation initialLocation;
  final ValueChanged<PrayerLocation> onSave;
  final Future<PrayerLocation> Function() onAutoLocate;

  @override
  State<MueenLocationScreen> createState() => _MueenLocationScreenState();
}

class _MueenLocationScreenState extends State<MueenLocationScreen> {
  late PrayerLocation _location = widget.initialLocation;
  final _search = TextEditingController();
  List<PrayerPlace> _results = const [];
  bool _locating = false;
  bool _loadingCatalog = false;
  bool _showManualPicker = false;

  @override
  void initState() {
    super.initState();
    _loadPlaces();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadPlaces([String query = '']) async {
    setState(() => _loadingCatalog = true);
    try {
      final results = await IraqPlaceCatalog.search(query);
      if (mounted) setState(() => _results = results);
    } finally {
      if (mounted) setState(() => _loadingCatalog = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = MueenPalette.of(context);
    return _FeatureScaffold(
        title: 'المدينة والموقع',
        subtitle: 'خصوصيتك أولاً',
        body: ListView(padding: const EdgeInsets.fromLTRB(20, 14, 20, 28), children: [
          _HeroPanel(
            eyebrow: 'المدينة الحالية',
            title: _location.name,
            body: _location.source == PrayerLocationSource.gps ? 'المواقيت محسوبة من إحداثيات GPS الحالية، وتحفظ على جهازك.' : 'المكان المختار محفوظ محلياً لحساب المواقيت والقبلة.',
            icon: Icons.location_on_rounded,
          ),
          const MueenSectionLabel(title: 'اختيار الموقع'),
          MueenSurface(child: Column(children: [
            _SettingRow(icon: _locating ? Icons.location_searching_rounded : Icons.my_location_rounded, title: _locating ? 'يجري تحديد موقعك…' : 'استخدام موقعي تلقائياً', detail: 'GPS دقيق؛ يطلب الإذن عند الضغط فقط', trailing: const _StatusPill('اختياري'), onTap: _locating ? null : _autoLocate),
            Divider(color: palette.line),
            _SettingRow(icon: Icons.location_city_rounded, title: 'اختيار المكان يدوياً', detail: _location.name, onTap: () => setState(() => _showManualPicker = !_showManualPicker)),
            Divider(color: palette.line),
            const _SettingRow(icon: Icons.tune_rounded, title: 'طريقة الحساب', detail: 'محلية بالإحداثيات • التقويم المرجعي اختياري', trailing: _StatusPill('محلي')),
          ])),
          if (_showManualPicker) ...[
            const MueenSectionLabel(title: 'دليل العراق المحلي'),
            MueenSurface(child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(children: [
                TextField(
                  controller: _search,
                  onChanged: _loadPlaces,
                  textDirection: TextDirection.rtl,
                  decoration: InputDecoration(
                    hintText: 'ابحث عن مدينة أو قضاء أو ناحية',
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: palette.surfaceSoft,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 300,
                  child: _loadingCatalog
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.separated(
                          itemCount: _results.length,
                          separatorBuilder: (_, __) => Divider(color: palette.line),
                          itemBuilder: (context, index) {
                            final place = _results[index];
                            return ListTile(
                              dense: true,
                              leading: const Icon(Icons.location_on_outlined),
                              title: Text(place.name, style: const TextStyle(fontWeight: FontWeight.w900)),
                              subtitle: Text(place.fallbackName),
                              onTap: () => setState(() {
                                _location = place.toPrayerLocation();
                                _showManualPicker = false;
                              }),
                            );
                          },
                        ),
                ),
              ]),
            )),
          ],
          const SizedBox(height: 18),
          FilledButton(onPressed: () { widget.onSave(_location); Navigator.pop(context); }, style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54), backgroundColor: palette.primaryStrong, foregroundColor: palette.actionForeground, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17))), child: const Text('حفظ الاختيار', style: TextStyle(fontWeight: FontWeight.w900))),
        ]),
      );
  }

  Future<void> _autoLocate() async {
    setState(() => _locating = true);
    try {
      final location = await widget.onAutoLocate();
      if (!mounted) return;
      setState(() => _location = location);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحديد إحداثيات موقعك بدقة.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

}

class PrayerRemindersScreen extends StatefulWidget {
  const PrayerRemindersScreen({super.key, this.onSaved});

  final Future<void> Function()? onSaved;

  @override
  State<PrayerRemindersScreen> createState() => _PrayerRemindersScreenState();
}

class _PrayerRemindersScreenState extends State<PrayerRemindersScreen> {
  static const _prayers = <({String id, String label})>[
    (id: 'fajr', label: 'الفجر'),
    (id: 'dhuhr', label: 'الظهر'),
    (id: 'asr', label: 'العصر'),
    (id: 'maghrib', label: 'المغرب'),
    (id: 'isha', label: 'العشاء'),
  ];

  PrayerReminderSettings _settings = const PrayerReminderSettings();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    final settings = await PrayerReminderSettingsStore.load();
    if (mounted) setState(() { _settings = settings; _loading = false; });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await PrayerReminderSettingsStore.save(_settings);
    await widget.onSaved?.call();
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ التذكيرات وإعادة جدولة التنبيهات المحلية.')));
  }

  @override
  Widget build(BuildContext context) {
    final palette = MueenPalette.of(context);
    return _FeatureScaffold(
      title: 'تذكيرات الصلاة',
      subtitle: 'قبل الأذان والإقامة',
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.fromLTRB(20, 14, 20, 28), children: [
              const _HeroPanel(
                eyebrow: 'محلي دون إنترنت',
                title: 'استعد للصلاة بهدوء',
                body: 'يُعاد ضبط التذكيرات من مواقيت جهازك المحفوظة عند تغيير المكان أو التحديث.',
                icon: Icons.notifications_active_rounded,
              ),
              const MueenSectionLabel(title: 'قبل الأذان'),
              MueenSurface(child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('تذكير موحّد لكل الصلوات', style: TextStyle(color: palette.ink, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 5),
                  Text('يمكنك إيقافه أو اختيار عدد الدقائق قبل الأذان.', style: TextStyle(color: palette.muted, fontSize: 12)),
                  const SizedBox(height: 12),
                  _MinutesSelector(
                    value: _settings.beforeAdhanMinutes,
                    onChanged: (value) => setState(() => _settings = _settings.copyWith(beforeAdhanMinutes: value)),
                  ),
                ]),
              )),
              const MueenSectionLabel(title: 'تنبيه الإقامة'),
              MueenSurface(padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 4), child: Column(children: [
                for (var index = 0; index < _prayers.length; index++) ...[
                  _PrayerIqamaRow(
                    prayer: _prayers[index].label,
                    minutes: _settings.iqamaMinutesFor(_prayers[index].id),
                    onChanged: (value) => setState(() {
                      final updated = Map<String, int>.from(_settings.iqamaByPrayer)..[_prayers[index].id] = value;
                      _settings = _settings.copyWith(iqamaByPrayer: updated);
                    }),
                  ),
                  if (index != _prayers.length - 1) Divider(color: palette.line),
                ],
              ])),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_outlined),
                label: Text(_saving ? 'جارِ الحفظ…' : 'حفظ التذكيرات'),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54), backgroundColor: palette.primaryStrong, foregroundColor: palette.actionForeground, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17))),
              ),
            ]),
    );
  }
}

class _MinutesSelector extends StatelessWidget {
  const _MinutesSelector({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [0, 5, 10, 15, 20, 30].map((minutes) => ChoiceChip(
          label: Text(minutes == 0 ? 'إيقاف' : '$minutes د'),
          selected: value == minutes,
          onSelected: (_) => onChanged(minutes),
        )).toList(),
      );
}

class _PrayerIqamaRow extends StatelessWidget {
  const _PrayerIqamaRow({required this.prayer, required this.minutes, required this.onChanged});
  final String prayer;
  final int minutes;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.mosque_outlined),
        title: Text('إقامة $prayer', style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text(minutes == 0 ? 'غير مفعّلة' : 'بعد $minutes دقائق من الأذان'),
        trailing: DropdownButton<int>(
          value: minutes,
          underline: const SizedBox.shrink(),
          items: [0, 5, 10, 15, 20, 30].map((value) => DropdownMenuItem(value: value, child: Text(value == 0 ? 'إيقاف' : '$value د'))).toList(),
          onChanged: (value) { if (value != null) onChanged(value); },
        ),
      );
}

class AdhanSelectionScreen extends StatefulWidget {
  const AdhanSelectionScreen({super.key});
  @override
  State<AdhanSelectionScreen> createState() => _AdhanSelectionScreenState();
}

class _AdhanSelectionScreenState extends State<AdhanSelectionScreen> {
  final _sounds = <String, String>{'الفجر': 'Beautiful Adhan', 'الظهر': 'Beautiful Adhan', 'العصر': 'Beautiful Adhan', 'المغرب': 'Beautiful Adhan', 'العشاء': 'Beautiful Adhan'};

  @override
  Widget build(BuildContext context) => _FeatureScaffold(
        title: 'اختيار الأذان',
        subtitle: 'صوت مستقل لكل صلاة',
        body: ListView(padding: const EdgeInsets.fromLTRB(20, 14, 20, 28), children: [
          const _HeroPanel(eyebrow: 'إعدادك الحالي', title: 'صوت مَعين المحلي', body: 'Beautiful Adhan مضمّن ويعمل دون إنترنت. ستظهر خيارات أخرى بعد التحقق من ترخيصها.', icon: Icons.volume_up_rounded),
          const MueenSectionLabel(title: 'الأذان', action: 'الإقامة'),
          MueenSurface(padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 5), child: Column(children: _sounds.entries.map((entry) => _AdhanRow(
            prayer: entry.key,
            sound: entry.value,
            onSelect: () => _select(entry.key),
          )).toList())),
          const MueenSectionLabel(title: 'إدارة الأصوات'),
          const MueenSurface(child: _SettingRow(icon: Icons.folder_copy_outlined, title: 'مكتبة الأصوات', detail: 'تحتوي حالياً على الصوت المضمّن المرخّص فقط', trailing: Icon(Icons.verified_rounded, color: MueenColors.gold))),
        ]),
      );

  void _select(String prayer) => showDialog<void>(
        context: context,
        builder: (dialogContext) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Text('اختيار صوت $prayer'),
            contentPadding: const EdgeInsetsDirectional.fromSTEB(16, 10, 16, 0),
            content: ListTile(title: const Text('Beautiful Adhan'), subtitle: const Text('الصوت المحلي المضمّن والمرخّص'), trailing: const Icon(Icons.verified_rounded), onTap: () { setState(() => _sounds[prayer] = 'Beautiful Adhan'); Navigator.pop(dialogContext); }),
            actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء'))],
          ),
        ),
      );
}

class SoundLibraryScreen extends StatelessWidget {
  const SoundLibraryScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final palette = MueenPalette.of(context);
    return _FeatureScaffold(
        title: 'مكتبة الأصوات',
        subtitle: 'صوت مرخّص محفوظ محلياً',
        body: ListView(padding: const EdgeInsets.fromLTRB(20, 14, 20, 28), children: [
          const _HeroPanel(eyebrow: 'المحفوظ في جهازك', title: 'الصوت الأساسي لمَعين', body: 'الصوت الموجود مرخّص ومضمّن في التطبيق ويعمل دون إنترنت.', icon: Icons.library_music_rounded),
          const MueenSectionLabel(title: 'الأصوات المتاحة محلياً'),
          MueenSurface(padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 5), child: Column(children: [
            const _SoundRow(name: 'Beautiful Adhan', size: 'مضمّن • CC0 • الصوت الافتراضي', status: 'معتمد'),
          ])),
          const SizedBox(height: 12),
          const Text('أصوات مكة والمدينة وبقية المؤذنين ستظهر هنا فقط بعد التحقق من ترخيص التضمين. لن يعرض مَعين زر تنزيل لصوت غير مرخّص.'),
        ]),
      );
  }
}

class KhatmaScreen extends StatelessWidget {
  const KhatmaScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final palette = MueenPalette.of(context);
    return _FeatureScaffold(
        title: 'وردي وختماتي',
        subtitle: 'خطتك محفوظة على جهازك',
        body: ListView(padding: const EdgeInsets.fromLTRB(20, 14, 20, 28), children: [
          MueenSurface(radius: 30, child: Column(children: [
            const Align(alignment: Alignment.centerRight, child: _StatusPill('34%')),
            const SizedBox(height: 8),
            Container(width: 146, height: 146, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: palette.goldAccent, width: 11)), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text('10', style: TextStyle(fontSize: 41, fontWeight: FontWeight.w900, color: palette.primary)), Text('أيام متبقية', style: TextStyle(color: palette.muted))])),
            const SizedBox(height: 12),
            Text('خطتك اليومية: جزء كل ثلاثة أيام', style: TextStyle(color: palette.muted, fontWeight: FontWeight.w700)),
          ])),
          const MueenSectionLabel(title: 'ورد اليوم'),
          MueenSurface(child: Column(children: [
            const _SettingRow(icon: Icons.menu_book_rounded, title: 'سورة الملك', detail: 'اقرأ قبل النوم', trailing: _StatusPill('ابدأ')),
            Divider(color: palette.line),
            const _SettingRow(icon: Icons.favorite_border_rounded, title: 'محفوظاتي', detail: '12 علامة وملاحظة', trailing: _StatusPill('افتح')),
          ])),
        ]),
      );
  }
}

class QiblaScreen extends StatefulWidget {
  const QiblaScreen({super.key, this.location});
  final PrayerLocation? location;

  @override
  State<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends State<QiblaScreen> {
  StreamSubscription<CompassEvent>? _subscription;
  double? _heading;

  @override
  void initState() {
    super.initState();
    _subscription = FlutterCompass.events?.listen((event) {
      if (mounted) setState(() => _heading = event.heading);
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = MueenPalette.of(context);
    final location = widget.location;
    if (location == null) {
      return _FeatureScaffold(
        title: 'القبلة',
        subtitle: 'تحتاج إلى مكانك',
        body: const Center(child: Padding(padding: EdgeInsets.all(28), child: Text('اختر موقعك يدوياً أو استخدم GPS أولاً، ثم افتح القبلة لحساب اتجاه الكعبة.'))),
      );
    }
    final bearing = _qiblaBearing(location.latitude, location.longitude);
    final distance = _distanceToMakkah(location.latitude, location.longitude);
    final heading = _heading;
    final angle = heading == null ? 0.0 : (bearing - heading) * math.pi / 180;
    return _FeatureScaffold(
        title: 'القبلة',
        subtitle: 'دقة المستشعر ومعايرته',
        body: ListView(padding: const EdgeInsets.fromLTRB(20, 14, 20, 28), children: [
          MueenSurface(radius: 30, child: Column(children: [
            const SizedBox(height: 4),
            Container(width: 254, height: 254, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: palette.primary, width: 4)), child: Stack(alignment: Alignment.center, children: [
              Positioned(top: 18, child: Text('ش', style: TextStyle(fontSize: 22, color: palette.goldAccent, fontWeight: FontWeight.w900))),
              Transform.rotate(angle: angle, child: Icon(Icons.navigation_rounded, color: palette.primary, size: 96)),
              Column(mainAxisAlignment: MainAxisAlignment.center, children: [const SizedBox(height: 52), Text('${bearing.round()}°', style: TextStyle(fontSize: 38, color: palette.primary, fontWeight: FontWeight.w900)), Text(heading == null ? 'بانتظار مستشعر البوصلة' : 'اتجه نحو القبلة', style: TextStyle(color: palette.muted))]),
            ])),
            const SizedBox(height: 14),
            Text('حرّك هاتفك على شكل 8 للمعايرة، وأبعده عن المعادن والمغناطيس.', style: TextStyle(fontWeight: FontWeight.w800, color: palette.ink), textAlign: TextAlign.center),
          ])),
          const SizedBox(height: 14),
          Row(children: [Expanded(child: _MetricCard(label: 'المسافة إلى مكة', value: '${distance.round()} كم', icon: Icons.mosque_outlined)), const SizedBox(width: 10), Expanded(child: _MetricCard(label: 'حالة المستشعر', value: heading == null ? 'غير متاح' : 'يعمل', icon: Icons.gps_fixed_rounded))]),
        ]),
      );
  }

  double _qiblaBearing(double latitude, double longitude) {
    const makkahLatitude = 21.4225;
    const makkahLongitude = 39.8262;
    final lat1 = latitude * math.pi / 180;
    final lat2 = makkahLatitude * math.pi / 180;
    final deltaLongitude = (makkahLongitude - longitude) * math.pi / 180;
    final y = math.sin(deltaLongitude) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) - math.sin(lat1) * math.cos(lat2) * math.cos(deltaLongitude);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  double _distanceToMakkah(double latitude, double longitude) {
    const makkahLatitude = 21.4225;
    const makkahLongitude = 39.8262;
    final latDelta = (makkahLatitude - latitude) * math.pi / 180;
    final longitudeDelta = (makkahLongitude - longitude) * math.pi / 180;
    final a = math.sin(latDelta / 2) * math.sin(latDelta / 2) + math.cos(latitude * math.pi / 180) * math.cos(makkahLatitude * math.pi / 180) * math.sin(longitudeDelta / 2) * math.sin(longitudeDelta / 2);
    return 6371 * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }
}

class MueenCalendarScreen extends StatelessWidget {
  const MueenCalendarScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final palette = MueenPalette.of(context);
    final hijri = HijriCalendar.now();
    const months = ['محرم', 'صفر', 'ربيع الأول', 'ربيع الآخر', 'جمادى الأولى', 'جمادى الآخرة', 'رجب', 'شعبان', 'رمضان', 'شوال', 'ذو القعدة', 'ذو الحجة'];
    final monthName = months[(hijri.hMonth - 1).clamp(0, 11)];
    return _FeatureScaffold(
      title: 'التقويم',
      subtitle: 'هجري وميلادي',
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 14, 20, 28), children: [
        MueenSurface(child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Icon(Icons.chevron_right_rounded, color: palette.goldAccent), Text('$monthName ${hijri.hYear}', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: palette.ink)), Icon(Icons.chevron_left_rounded, color: palette.goldAccent)]),
          const SizedBox(height: 5),
          Text('تقويم محلي', style: TextStyle(color: palette.goldAccent, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          const _CalendarGrid(),
        ])),
        const SizedBox(height: 16),
        Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: palette.primaryStrong, borderRadius: BorderRadius.circular(25)), child: Column(children: [Text('مواقيت اليوم', style: TextStyle(color: palette.actionForeground, fontSize: 18, fontWeight: FontWeight.w900)), const SizedBox(height: 12), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: ['الفجر\n04:05', 'الظهر\n12:21', 'العصر\n04:01', 'المغرب\n07:00', 'العشاء\n08:21'].map((time) => Text(time, textAlign: TextAlign.center, style: TextStyle(color: palette.actionForeground))).toList())])),
      ]),
    );
  }
}

class _FeatureScaffold extends StatelessWidget {
  const _FeatureScaffold({required this.title, required this.subtitle, required this.body});
  final String title;
  final String subtitle;
  final Widget body;
  @override
  Widget build(BuildContext context) {
    final palette = MueenPalette.of(context);
    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        title: Column(children: [Text(title, style: TextStyle(color: palette.ink, fontWeight: FontWeight.w900)), Text(subtitle, style: TextStyle(color: palette.muted, fontSize: 10))]),
        leading: IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.arrow_forward_rounded, color: palette.primary)),
      ),
      body: SafeArea(top: false, child: body),
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({required this.eyebrow, required this.title, required this.body, required this.icon});
  final String eyebrow;
  final String title;
  final String body;
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    final palette = MueenPalette.of(context);
    return MueenSurface(radius: 27, color: palette.surfaceSoft, child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [MueenIconBubble(icon: icon, color: MueenColors.gold, size: 43), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(eyebrow, style: TextStyle(color: palette.muted, fontSize: 11, fontWeight: FontWeight.w800)), const SizedBox(height: 6), Text(title, style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900, color: palette.ink)), const SizedBox(height: 5), Text(body, style: TextStyle(color: palette.muted, fontSize: 11, height: 1.55))]))]));
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({required this.icon, required this.title, required this.detail, this.trailing, this.onTap});
  final IconData icon;
  final String title;
  final String detail;
  final Widget? trailing;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final palette = MueenPalette.of(context);
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(14), child: Padding(padding: const EdgeInsets.symmetric(vertical: 9), child: Row(children: [MueenIconBubble(icon: icon, size: 36), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(fontWeight: FontWeight.w900, color: palette.ink)), const SizedBox(height: 2), Text(detail, style: TextStyle(color: palette.muted, fontSize: 11))])), if (trailing != null) trailing!])));
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill(this.label);
  final String label;
  @override
  Widget build(BuildContext context) {
    final palette = MueenPalette.of(context);
    return Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5), decoration: BoxDecoration(color: palette.selection, borderRadius: BorderRadius.circular(99)), child: Text(label, style: TextStyle(color: palette.primary, fontSize: 10, fontWeight: FontWeight.w900)));
  }
}

class _AdhanRow extends StatelessWidget {
  const _AdhanRow({required this.prayer, required this.sound, required this.onSelect});
  final String prayer;
  final String sound;
  final VoidCallback onSelect;
  @override
  Widget build(BuildContext context) {
    final palette = MueenPalette.of(context);
    return Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(children: [const MueenIconBubble(icon: Icons.volume_up_rounded, size: 36), const SizedBox(width: 8), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(prayer, style: TextStyle(fontWeight: FontWeight.w900, color: palette.ink)), Text(sound, style: TextStyle(color: palette.muted, fontSize: 10))])), OutlinedButton(onPressed: onSelect, style: OutlinedButton.styleFrom(foregroundColor: palette.primary, side: BorderSide(color: palette.goldAccent), padding: const EdgeInsets.symmetric(horizontal: 9)), child: const Text('اختيار الصوت', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900))), const SizedBox(width: 5), CircleAvatar(radius: 16, backgroundColor: palette.primaryStrong, child: Icon(Icons.play_arrow_rounded, color: palette.actionForeground, size: 18))]));
  }
}

class _SoundRow extends StatelessWidget {
  const _SoundRow({required this.name, required this.size, required this.status});
  final String name;
  final String size;
  final String status;
  @override
  Widget build(BuildContext context) {
    final palette = MueenPalette.of(context);
    return _SettingRow(icon: Icons.volume_up_rounded, title: name, detail: size, trailing: _StatusPill(status));
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    final palette = MueenPalette.of(context);
    return MueenSurface(padding: const EdgeInsets.all(12), child: Column(children: [MueenIconBubble(icon: icon, size: 36), const SizedBox(height: 8), Text(value, style: TextStyle(fontWeight: FontWeight.w900, color: palette.primary)), const SizedBox(height: 2), Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: palette.muted))]));
  }
}

class _CalendarGrid extends StatelessWidget {
  const _CalendarGrid();
  @override
  Widget build(BuildContext context) {
    final palette = MueenPalette.of(context);
    return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 35,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, childAspectRatio: .82),
        itemBuilder: (context, index) {
          final day = index + 1;
          final selected = day == 22;
          return Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(9), border: Border.all(color: selected ? palette.goldAccent : Colors.transparent)),
            child: Center(child: Text('$day', style: TextStyle(fontWeight: selected ? FontWeight.w900 : FontWeight.w700, color: selected ? palette.primary : palette.ink))),
          );
        },
      );
  }
}
