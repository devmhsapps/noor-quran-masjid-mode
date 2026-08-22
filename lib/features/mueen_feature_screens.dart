import 'package:flutter/material.dart';
import 'package:hijri/hijri_calendar.dart';

import '../ui/mueen_design.dart';

class MueenLocationScreen extends StatefulWidget {
  const MueenLocationScreen({super.key, required this.initialCity, required this.onSave, required this.onAutoLocate});
  final String initialCity;
  final ValueChanged<String> onSave;
  final Future<String> Function() onAutoLocate;

  @override
  State<MueenLocationScreen> createState() => _MueenLocationScreenState();
}

class _MueenLocationScreenState extends State<MueenLocationScreen> {
  late String _city = widget.initialCity == 'اختر المدينة' ? 'بغداد' : widget.initialCity;
  final _cities = const ['بغداد', 'مكة المكرمة', 'المدينة المنورة', 'النجف', 'البصرة'];
  bool _locating = false;

  @override
  Widget build(BuildContext context) => _FeatureScaffold(
        title: 'المدينة والموقع',
        subtitle: 'خصوصيتك أولاً',
        body: ListView(padding: const EdgeInsets.fromLTRB(20, 14, 20, 28), children: [
          _HeroPanel(
            eyebrow: 'المدينة الحالية',
            title: _city,
            body: 'تستخدم المدينة لحساب المواقيت والقبلة، ولا تحفظ إلا على جهازك.',
            icon: Icons.location_on_rounded,
          ),
          const MueenSectionLabel(title: 'اختيار الموقع'),
          MueenSurface(child: Column(children: [
            _SettingRow(icon: _locating ? Icons.location_searching_rounded : Icons.my_location_rounded, title: _locating ? 'يجري تحديد موقعك…' : 'استخدام موقعي تلقائياً', detail: 'يطلب الإذن عند الضغط فقط', trailing: const _StatusPill('اختياري'), onTap: _locating ? null : _autoLocate),
            const Divider(color: MueenColors.line),
            _SettingRow(icon: Icons.location_city_rounded, title: 'اختيار مدينة يدوياً', detail: _city, onTap: _showCities),
            const Divider(color: MueenColors.line),
            const _SettingRow(icon: Icons.tune_rounded, title: 'طريقة الحساب', detail: 'محلية حسب المدينة', trailing: _StatusPill('محلي')),
          ])),
          const SizedBox(height: 18),
          FilledButton(onPressed: () { widget.onSave(_city); Navigator.pop(context); }, style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54), backgroundColor: MueenColors.forest, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17))), child: const Text('حفظ الاختيار', style: TextStyle(fontWeight: FontWeight.w900))),
        ]),
      );

  Future<void> _autoLocate() async {
    setState(() => _locating = true);
    try {
      final city = await widget.onAutoLocate();
      if (!mounted) return;
      setState(() => _city = city);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم تحديد أقرب مدينة: $city')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _showCities() => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (sheetContext) => Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Wrap(spacing: 8, runSpacing: 8, children: _cities.map((city) => ChoiceChip(label: Text(city), selected: city == _city, onSelected: (_) { setState(() => _city = city); Navigator.pop(sheetContext); })).toList()),
          ),
        ),
      );
}

class AdhanSelectionScreen extends StatefulWidget {
  const AdhanSelectionScreen({super.key});
  @override
  State<AdhanSelectionScreen> createState() => _AdhanSelectionScreenState();
}

class _AdhanSelectionScreenState extends State<AdhanSelectionScreen> {
  final _sounds = <String, String>{'الفجر': 'أذان الفجر الهادئ', 'الظهر': 'أذان بغداد القصير', 'العصر': 'غير محدد', 'المغرب': 'غير محدد', 'العشاء': 'غير محدد'};

  @override
  Widget build(BuildContext context) => _FeatureScaffold(
        title: 'اختيار الأذان',
        subtitle: 'صوت مستقل لكل صلاة',
        body: ListView(padding: const EdgeInsets.fromLTRB(20, 14, 20, 28), children: [
          const _HeroPanel(eyebrow: 'إعدادك الحالي', title: 'اختَر صوت كل صلاة', body: 'اضغط اختيار الصوت للصلاة المطلوبة، ثم استمع قبل حفظه على الجهاز.', icon: Icons.volume_up_rounded),
          const MueenSectionLabel(title: 'الأذان', action: 'الإقامة'),
          MueenSurface(padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 5), child: Column(children: _sounds.entries.map((entry) => _AdhanRow(
            prayer: entry.key,
            sound: entry.value,
            onSelect: () => _select(entry.key),
          )).toList())),
          const MueenSectionLabel(title: 'إدارة الأصوات'),
          const MueenSurface(child: _SettingRow(icon: Icons.folder_copy_outlined, title: 'مكتبة الأصوات', detail: 'اعرض الحجم والتنزيل والحذف لاحقاً', trailing: Icon(Icons.chevron_left_rounded, color: MueenColors.gold))),
        ]),
      );

  void _select(String prayer) => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (sheetContext) => Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('اختيار صوت $prayer', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              ...['أذان هادئ', 'تكبير قصير', 'نغمة ورد'].map((sound) => ListTile(title: Text(sound), trailing: const Icon(Icons.play_circle_outline_rounded), onTap: () { setState(() => _sounds[prayer] = sound); Navigator.pop(sheetContext); })),
            ]),
          ),
        ),
      );
}

class SoundLibraryScreen extends StatelessWidget {
  const SoundLibraryScreen({super.key});
  @override
  Widget build(BuildContext context) => _FeatureScaffold(
        title: 'مكتبة الأصوات',
        subtitle: 'تنزيل صريح وحفظ محلي',
        body: ListView(padding: const EdgeInsets.fromLTRB(20, 14, 20, 28), children: const [
          _HeroPanel(eyebrow: 'المحفوظ في جهازك', title: 'اختر صوت التنبيه', body: 'تعمل التنبيهات من النسخة المحفوظة فقط بعد التنزيل الصريح.', icon: Icons.library_music_rounded),
          MueenSectionLabel(title: 'أصوات هادئة', action: 'إدارة المساحة'),
          MueenSurface(padding: EdgeInsets.symmetric(horizontal: 13, vertical: 5), child: Column(children: [
            _SoundRow(name: 'أذان هادئ', size: '3.8 م.ب • محفوظ', action: 'اختيار'),
            Divider(color: MueenColors.line),
            _SoundRow(name: 'تكبير قصير', size: '1.2 م.ب • متاح', action: 'تنزيل'),
            Divider(color: MueenColors.line),
            _SoundRow(name: 'نغمة ورد', size: '0.6 م.ب • متاح', action: 'تنزيل'),
          ])),
        ]),
      );
}

class KhatmaScreen extends StatelessWidget {
  const KhatmaScreen({super.key});
  @override
  Widget build(BuildContext context) => _FeatureScaffold(
        title: 'وردي وختماتي',
        subtitle: 'خطتك محفوظة على جهازك',
        body: ListView(padding: const EdgeInsets.fromLTRB(20, 14, 20, 28), children: [
          MueenSurface(radius: 30, child: Column(children: [
            const Align(alignment: Alignment.centerRight, child: _StatusPill('34%')),
            const SizedBox(height: 8),
            Container(width: 146, height: 146, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: MueenColors.gold, width: 11)), child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text('10', style: TextStyle(fontSize: 41, fontWeight: FontWeight.w900, color: MueenColors.forest)), Text('أيام متبقية', style: TextStyle(color: MueenColors.muted))])),
            const SizedBox(height: 12),
            const Text('خطتك اليومية: جزء كل ثلاثة أيام', style: TextStyle(color: MueenColors.muted, fontWeight: FontWeight.w700)),
          ])),
          const MueenSectionLabel(title: 'ورد اليوم'),
          MueenSurface(child: Column(children: const [
            _SettingRow(icon: Icons.menu_book_rounded, title: 'سورة الملك', detail: 'اقرأ قبل النوم', trailing: _StatusPill('ابدأ')),
            Divider(color: MueenColors.line),
            _SettingRow(icon: Icons.favorite_border_rounded, title: 'محفوظاتي', detail: '12 علامة وملاحظة', trailing: _StatusPill('افتح')),
          ])),
        ]),
      );
}

class QiblaScreen extends StatelessWidget {
  const QiblaScreen({super.key});
  @override
  Widget build(BuildContext context) => _FeatureScaffold(
        title: 'القبلة',
        subtitle: 'دقة المستشعر ومعايرته',
        body: ListView(padding: const EdgeInsets.fromLTRB(20, 14, 20, 28), children: [
          MueenSurface(radius: 30, child: Column(children: [
            const SizedBox(height: 4),
            Container(width: 254, height: 254, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: MueenColors.forest, width: 4)), child: Stack(alignment: Alignment.center, children: [
              const Positioned(top: 18, child: Text('ش', style: TextStyle(fontSize: 22, color: MueenColors.gold, fontWeight: FontWeight.w900))),
              const Icon(Icons.navigation_rounded, color: MueenColors.forest, size: 96),
              const Column(mainAxisAlignment: MainAxisAlignment.center, children: [SizedBox(height: 52), Text('212°', style: TextStyle(fontSize: 38, color: MueenColors.forest, fontWeight: FontWeight.w900)), Text('اتجه نحو القبلة', style: TextStyle(color: MueenColors.muted))]),
            ])),
            const SizedBox(height: 14),
            const Text('حرّك هاتفك على شكل 8 للمعايرة', style: TextStyle(fontWeight: FontWeight.w800, color: MueenColors.ink)),
          ])),
          const SizedBox(height: 14),
          Row(children: const [Expanded(child: _MetricCard(label: 'المسافة إلى مكة', value: '1,274 كم', icon: Icons.mosque_outlined)), SizedBox(width: 10), Expanded(child: _MetricCard(label: 'دقة المستشعر', value: 'جيدة', icon: Icons.gps_fixed_rounded))]),
        ]),
      );
}

class MueenCalendarScreen extends StatelessWidget {
  const MueenCalendarScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final hijri = HijriCalendar.now();
    const months = ['محرم', 'صفر', 'ربيع الأول', 'ربيع الآخر', 'جمادى الأولى', 'جمادى الآخرة', 'رجب', 'شعبان', 'رمضان', 'شوال', 'ذو القعدة', 'ذو الحجة'];
    final monthName = months[(hijri.hMonth - 1).clamp(0, 11)];
    return _FeatureScaffold(
      title: 'التقويم',
      subtitle: 'هجري وميلادي',
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 14, 20, 28), children: [
        MueenSurface(child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Icon(Icons.chevron_right_rounded, color: MueenColors.gold), Text('$monthName ${hijri.hYear}', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)), const Icon(Icons.chevron_left_rounded, color: MueenColors.gold)]),
          const SizedBox(height: 5),
          const Text('تقويم محلي', style: TextStyle(color: MueenColors.gold, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          const _CalendarGrid(),
        ])),
        const SizedBox(height: 16),
        Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: MueenColors.forest, borderRadius: BorderRadius.circular(25)), child: const Column(children: [Text('مواقيت اليوم', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)), SizedBox(height: 12), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('الفجر\n04:05', textAlign: TextAlign.center, style: TextStyle(color: Colors.white)), Text('الظهر\n12:21', textAlign: TextAlign.center, style: TextStyle(color: Colors.white)), Text('العصر\n04:01', textAlign: TextAlign.center, style: TextStyle(color: Colors.white)), Text('المغرب\n07:00', textAlign: TextAlign.center, style: TextStyle(color: Colors.white)), Text('العشاء\n08:21', textAlign: TextAlign.center, style: TextStyle(color: Colors.white))])])),
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
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: MueenColors.ivory,
        appBar: AppBar(backgroundColor: MueenColors.ivory, surfaceTintColor: Colors.transparent, centerTitle: true, title: Column(children: [Text(title, style: const TextStyle(color: MueenColors.ink, fontWeight: FontWeight.w900)), Text(subtitle, style: const TextStyle(color: MueenColors.muted, fontSize: 10))]), leading: IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_forward_rounded, color: MueenColors.forest))),
        body: body,
      );
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({required this.eyebrow, required this.title, required this.body, required this.icon});
  final String eyebrow;
  final String title;
  final String body;
  final IconData icon;
  @override
  Widget build(BuildContext context) => MueenSurface(radius: 27, color: const Color(0xFFF9F2E2), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [MueenIconBubble(icon: icon, color: MueenColors.gold, size: 43), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(eyebrow, style: const TextStyle(color: MueenColors.muted, fontSize: 11, fontWeight: FontWeight.w800)), const SizedBox(height: 6), Text(title, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900, color: MueenColors.ink)), const SizedBox(height: 5), Text(body, style: const TextStyle(color: MueenColors.muted, fontSize: 11, height: 1.55))]))]));
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({required this.icon, required this.title, required this.detail, this.trailing, this.onTap});
  final IconData icon;
  final String title;
  final String detail;
  final Widget? trailing;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => InkWell(onTap: onTap, borderRadius: BorderRadius.circular(14), child: Padding(padding: const EdgeInsets.symmetric(vertical: 9), child: Row(children: [MueenIconBubble(icon: icon, size: 36), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w900, color: MueenColors.ink)), const SizedBox(height: 2), Text(detail, style: const TextStyle(color: MueenColors.muted, fontSize: 11))])), if (trailing != null) trailing!])));
}

class _StatusPill extends StatelessWidget {
  const _StatusPill(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5), decoration: BoxDecoration(color: MueenColors.mint, borderRadius: BorderRadius.circular(99)), child: Text(label, style: const TextStyle(color: MueenColors.forest, fontSize: 10, fontWeight: FontWeight.w900)));
}

class _AdhanRow extends StatelessWidget {
  const _AdhanRow({required this.prayer, required this.sound, required this.onSelect});
  final String prayer;
  final String sound;
  final VoidCallback onSelect;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(children: [const MueenIconBubble(icon: Icons.volume_up_rounded, size: 36), const SizedBox(width: 8), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(prayer, style: const TextStyle(fontWeight: FontWeight.w900)), Text(sound, style: const TextStyle(color: MueenColors.muted, fontSize: 10))])), OutlinedButton(onPressed: onSelect, style: OutlinedButton.styleFrom(foregroundColor: MueenColors.forest, side: const BorderSide(color: MueenColors.gold), padding: const EdgeInsets.symmetric(horizontal: 9)), child: const Text('اختيار الصوت', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900))), const SizedBox(width: 5), const CircleAvatar(radius: 16, backgroundColor: MueenColors.forest, child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 18))]));
}

class _SoundRow extends StatelessWidget {
  const _SoundRow({required this.name, required this.size, required this.action});
  final String name;
  final String size;
  final String action;
  @override
  Widget build(BuildContext context) => _SettingRow(icon: Icons.volume_up_rounded, title: name, detail: size, trailing: TextButton(onPressed: () {}, child: Text(action, style: const TextStyle(color: MueenColors.forest, fontWeight: FontWeight.w900))));
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => MueenSurface(padding: const EdgeInsets.all(12), child: Column(children: [MueenIconBubble(icon: icon, size: 36), const SizedBox(height: 8), Text(value, style: const TextStyle(fontWeight: FontWeight.w900, color: MueenColors.forest)), const SizedBox(height: 2), Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: MueenColors.muted))]));
}

class _CalendarGrid extends StatelessWidget {
  const _CalendarGrid();
  @override
  Widget build(BuildContext context) => GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 35,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, childAspectRatio: .82),
        itemBuilder: (context, index) {
          final day = index + 1;
          final selected = day == 22;
          return Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(9), border: Border.all(color: selected ? MueenColors.gold : Colors.transparent)),
            child: Center(child: Text('$day', style: TextStyle(fontWeight: selected ? FontWeight.w900 : FontWeight.w700, color: selected ? MueenColors.forest : MueenColors.ink))),
          );
        },
      );
}
