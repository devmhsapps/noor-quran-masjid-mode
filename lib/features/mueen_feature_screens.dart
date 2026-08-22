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
  Widget build(BuildContext context) {
    final palette = MueenPalette.of(context);
    return _FeatureScaffold(
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
            Divider(color: palette.line),
            _SettingRow(icon: Icons.location_city_rounded, title: 'اختيار مدينة يدوياً', detail: _city, onTap: _showCities),
            Divider(color: palette.line),
            const _SettingRow(icon: Icons.tune_rounded, title: 'طريقة الحساب', detail: 'محلية حسب المدينة', trailing: _StatusPill('محلي')),
          ])),
          const SizedBox(height: 18),
          FilledButton(onPressed: () { widget.onSave(_city); Navigator.pop(context); }, style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54), backgroundColor: palette.primaryStrong, foregroundColor: palette.actionForeground, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17))), child: const Text('حفظ الاختيار', style: TextStyle(fontWeight: FontWeight.w900))),
        ]),
      );
  }

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

  void _showCities() => showDialog<void>(
        context: context,
        builder: (dialogContext) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('اختيار مدينة'),
            content: Wrap(spacing: 8, runSpacing: 8, children: _cities.map((city) => ChoiceChip(label: Text(city), selected: city == _city, onSelected: (_) { setState(() => _city = city); Navigator.pop(dialogContext); })).toList()),
            actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء'))],
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

  void _select(String prayer) => showDialog<void>(
        context: context,
        builder: (dialogContext) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Text('اختيار صوت $prayer'),
            contentPadding: const EdgeInsetsDirectional.fromSTEB(16, 10, 16, 0),
            content: Column(mainAxisSize: MainAxisSize.min, children: ['أذان هادئ', 'تكبير قصير', 'نغمة ورد'].map((sound) => ListTile(title: Text(sound), trailing: const Icon(Icons.play_circle_outline_rounded), onTap: () { setState(() => _sounds[prayer] = sound); Navigator.pop(dialogContext); })).toList()),
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
        subtitle: 'تنزيل صريح وحفظ محلي',
        body: ListView(padding: const EdgeInsets.fromLTRB(20, 14, 20, 28), children: [
          const _HeroPanel(eyebrow: 'المحفوظ في جهازك', title: 'اختر صوت التنبيه', body: 'تعمل التنبيهات من النسخة المحفوظة فقط بعد التنزيل الصريح.', icon: Icons.library_music_rounded),
          const MueenSectionLabel(title: 'أصوات هادئة', action: 'إدارة المساحة'),
          MueenSurface(padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 5), child: Column(children: [
            const _SoundRow(name: 'أذان هادئ', size: '3.8 م.ب • محفوظ', action: 'اختيار'),
            Divider(color: palette.line),
            const _SoundRow(name: 'تكبير قصير', size: '1.2 م.ب • متاح', action: 'تنزيل'),
            Divider(color: palette.line),
            const _SoundRow(name: 'نغمة ورد', size: '0.6 م.ب • متاح', action: 'تنزيل'),
          ])),
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

class QiblaScreen extends StatelessWidget {
  const QiblaScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final palette = MueenPalette.of(context);
    return _FeatureScaffold(
        title: 'القبلة',
        subtitle: 'دقة المستشعر ومعايرته',
        body: ListView(padding: const EdgeInsets.fromLTRB(20, 14, 20, 28), children: [
          MueenSurface(radius: 30, child: Column(children: [
            const SizedBox(height: 4),
            Container(width: 254, height: 254, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: palette.primary, width: 4)), child: Stack(alignment: Alignment.center, children: [
              Positioned(top: 18, child: Text('ش', style: TextStyle(fontSize: 22, color: palette.goldAccent, fontWeight: FontWeight.w900))),
              Icon(Icons.navigation_rounded, color: palette.primary, size: 96),
              Column(mainAxisAlignment: MainAxisAlignment.center, children: [const SizedBox(height: 52), Text('212°', style: TextStyle(fontSize: 38, color: palette.primary, fontWeight: FontWeight.w900)), Text('اتجه نحو القبلة', style: TextStyle(color: palette.muted))]),
            ])),
            const SizedBox(height: 14),
            Text('حرّك هاتفك على شكل 8 للمعايرة', style: TextStyle(fontWeight: FontWeight.w800, color: palette.ink)),
          ])),
          const SizedBox(height: 14),
          Row(children: const [Expanded(child: _MetricCard(label: 'المسافة إلى مكة', value: '1,274 كم', icon: Icons.mosque_outlined)), SizedBox(width: 10), Expanded(child: _MetricCard(label: 'دقة المستشعر', value: 'جيدة', icon: Icons.gps_fixed_rounded))]),
        ]),
      );
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
      body: body,
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
  const _SoundRow({required this.name, required this.size, required this.action});
  final String name;
  final String size;
  final String action;
  @override
  Widget build(BuildContext context) {
    final palette = MueenPalette.of(context);
    return _SettingRow(icon: Icons.volume_up_rounded, title: name, detail: size, trailing: TextButton(onPressed: () {}, child: Text(action, style: TextStyle(color: palette.primary, fontWeight: FontWeight.w900))));
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
