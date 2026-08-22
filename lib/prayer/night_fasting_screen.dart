import 'dart:async';

import 'package:flutter/material.dart';

import 'prayer_calculator.dart';

class NightFastingScreen extends StatefulWidget {
  const NightFastingScreen({super.key, required this.city});

  final String city;

  @override
  State<NightFastingScreen> createState() => _NightFastingScreenState();
}

class _NightFastingScreenState extends State<NightFastingScreen> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final info = PrayerCalculator.nightFastingForCity(widget.city, now: now);
    return Scaffold(
      appBar: AppBar(title: const Text('ليلتي وصيامي')),
      body: info == null
          ? _NoCity(onBack: () => Navigator.pop(context))
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: [
                _NightHero(city: info.city.name, now: now, info: info),
                const SizedBox(height: 16),
                Text('صيام اليوم', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                _TimeCard(label: 'بداية الصيام', detail: 'الفجر', icon: Icons.wb_twilight_outlined, time: PrayerCalculator.formatTime(info.fajr)),
                const SizedBox(height: 8),
                _TimeCard(label: 'الإفطار', detail: 'المغرب', icon: Icons.wb_sunny_outlined, time: PrayerCalculator.formatTime(info.maghrib)),
                const SizedBox(height: 8),
                _MetricCard(label: 'مدة الصيام', value: PrayerCalculator.formatDuration(info.fastingDuration), icon: Icons.timelapse_rounded),
                const SizedBox(height: 22),
                Text('أوقات الليل', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                _TimeCard(label: 'منتصف الليل الشرعي', detail: 'بين مغرب اليوم وفجر الغد', icon: Icons.brightness_3_outlined, time: PrayerCalculator.formatTime(info.middleOfNight)),
                const SizedBox(height: 8),
                _TimeCard(label: 'بداية الثلث الأخير', detail: 'وقت قيام وذكر اختياري', icon: Icons.nightlight_round, time: PrayerCalculator.formatTime(info.lastThirdStarts)),
                const SizedBox(height: 8),
                _TimeCard(label: 'فجر الغد', detail: 'نهاية الليل', icon: Icons.wb_twilight, time: PrayerCalculator.formatTime(info.nextFajr)),
                const SizedBox(height: 8),
                _MetricCard(label: 'مدة الليل', value: PrayerCalculator.formatDuration(info.nightDuration), icon: Icons.dark_mode_outlined),
                const SizedBox(height: 18),
                Text('تُحسب هذه القيم محلياً من المدينة وطريقة الحساب الظاهرة في «صلاتي». راجع مرجع مدينتك قبل الاعتماد على أي وقت ديني رسمي.', style: theme.textTheme.bodySmall?.copyWith(height: 1.55)),
              ],
            ),
    );
  }
}

class _NightHero extends StatelessWidget {
  const _NightHero({required this.city, required this.now, required this.info});

  final String city;
  final DateTime now;
  final NightFastingInfo info;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final afterIftar = now.isAfter(info.maghrib) && now.isBefore(info.nextFajr);
    final target = afterIftar ? info.nextFajr : info.maghrib;
    final label = afterIftar ? 'المتبقي لفجر الغد' : 'المتبقي للإفطار';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [theme.colorScheme.primary, theme.colorScheme.primary.withValues(alpha: .72)], begin: Alignment.topRight, end: Alignment.bottomLeft),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [const Icon(Icons.nights_stay_outlined, color: Color(0xFFF8F5EE)), const SizedBox(width: 8), Text(city, style: const TextStyle(color: Color(0xFFF8F5EE), fontWeight: FontWeight.w800))]),
        const SizedBox(height: 18),
        Text(label, style: const TextStyle(color: Color(0xFFF8F5EE), fontSize: 16)),
        const SizedBox(height: 6),
        Text(PrayerCalculator.remainingLabel(now, target), style: const TextStyle(color: Color(0xFFF8F5EE), fontSize: 28, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Text(afterIftar ? 'بعد الإفطار حتى الفجر: ${PrayerCalculator.formatDuration(info.afterIftarDuration)}' : 'مدة صيام اليوم: ${PrayerCalculator.formatDuration(info.fastingDuration)}', style: const TextStyle(color: Color(0xFFF8F5EE))),
      ]),
    );
  }
}

class _TimeCard extends StatelessWidget {
  const _TimeCard({required this.label, required this.detail, required this.icon, required this.time});

  final String label;
  final String detail;
  final IconData icon;
  final String time;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(children: [
            CircleAvatar(backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: .12), child: Icon(icon, color: Theme.of(context).colorScheme.primary)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontWeight: FontWeight.w900)), const SizedBox(height: 3), Text(detail, style: Theme.of(context).textTheme.bodySmall)])),
            Text(time, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          ]),
        ),
      );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Card(
        color: Theme.of(context).colorScheme.primaryContainer,
        child: ListTile(
          leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
          title: Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
          trailing: Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
        ),
      );
}

class _NoCity extends StatelessWidget {
  const _NoCity({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.location_searching_rounded, size: 44),
            const SizedBox(height: 12),
            const Text('اختر مدينتك أولاً', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            const Text('تحتاج صفحة ليلتي وصيامي إلى مدينة لحساب الأوقات محلياً.', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onBack, child: const Text('العودة إلى مَعين')),
          ]),
        ),
      );
}
