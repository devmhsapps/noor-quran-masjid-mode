import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/duration.dart';
import 'core/masjid_mode_channel.dart';
import 'prayer/prayer_calculator.dart';
import 'quran/quran_tab.dart';
import 'widgets/islamic_background.dart';

void main() => runApp(const MueenApp());

class MueenApp extends StatefulWidget {
  const MueenApp({super.key});

  @override
  State<MueenApp> createState() => _MueenAppState();
}

class _MueenAppState extends State<MueenApp> {
  ThemeMode _themeMode = ThemeMode.light;

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF0B3D2E);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'مَعين — رفيق القرآن والصلاة',
      themeMode: _themeMode,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'sans',
        colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.light),
        scaffoldBackgroundColor: const Color(0xFFF8F5EE),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        fontFamily: 'sans',
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF76C79F), brightness: Brightness.dark),
        scaffoldBackgroundColor: const Color(0xFF0B1713),
      ),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: MueenShell(
          isDark: _themeMode == ThemeMode.dark,
          onToggleTheme: _toggleTheme,
        ),
      ),
    );
  }
}

class MasjidModeScreen extends StatefulWidget {
  const MasjidModeScreen({super.key});

  @override
  State<MasjidModeScreen> createState() => _MasjidModeScreenState();
}

class _MasjidModeScreenState extends State<MasjidModeScreen>
    with WidgetsBindingObserver {
  final _hours = TextEditingController(text: '0');
  final _minutes = TextEditingController(text: '2');
  final _seconds = TextEditingController(text: '0');
  Timer? _timer;
  bool _opening = true;
  bool _busy = false;
  bool _notificationsGranted = false;
  bool _locationGranted = false;
  bool _setupComplete = false;
  bool _setupInProgress = false;
  MasjidModeStatus _status = const MasjidModeStatus(
    active: false,
    dndAccessGranted: false,
    exactAlarmGranted: false,
    batteryUnrestricted: false,
  );
  String _message = 'يرجى منح الصلاحيات اللازمة ثم اختيار وقت الجلسة.';
  int _now = DateTime.now().millisecondsSinceEpoch;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadInitialState();
    Timer(const Duration(milliseconds: 2200), () {
      if (mounted) setState(() => _opening = false);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _hours.dispose();
    _minutes.dispose();
    _seconds.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshStatus();
      if (_setupInProgress) _continuePermissionSetup();
    }
  }

  Future<void> _loadInitialState() async {
    final notification = await Permission.notification.status;
    final location = await Permission.locationWhenInUse.status;
    final preferences = await SharedPreferences.getInstance();
    await _refreshStatus();
    if (!mounted) return;
    setState(() {
      _notificationsGranted = notification.isGranted;
      _locationGranted = location.isGranted;
      _setupComplete = preferences.getBool('masjid_permission_setup_complete') ?? false;
    });
  }

  Future<void> _refreshStatus() async {
    try {
      final status = await MasjidModeChannel.status();
      if (!mounted) return;
      setState(() {
        _status = status;
        _now = DateTime.now().millisecondsSinceEpoch;
        if (!status.active && status.endsAt != null) {
          _message = 'تم إيقاف الوضع الصامت. تقبل الله صلاتكم.';
        }
      });
      _scheduleTicker();
    } catch (_) {
      if (!mounted) return;
      setState(() => _message = 'تعذر التحقق من وضع الجامع على هذا الجهاز.');
    }
  }

  void _scheduleTicker() {
    _timer?.cancel();
    if (!_status.active) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!mounted) return;
      setState(() => _now = DateTime.now().millisecondsSinceEpoch);
      if ((_status.endsAt ?? 0) <= _now) await _refreshStatus();
    });
  }

  int get _selectedSeconds => durationPartsToSeconds(
        hours: int.tryParse(_hours.text) ?? 0,
        minutes: int.tryParse(_minutes.text) ?? 0,
        seconds: int.tryParse(_seconds.text) ?? 0,
      );

  int get _remainingSeconds =>
      (((_status.endsAt ?? _now) - _now) / 1000).ceil().clamp(0, maxSessionSeconds).toInt();

  Future<void> _startOrRequestAccess() async {
    if (_busy) return;
    if (_setupComplete && _notificationsGranted && _status.dndAccessGranted && _status.exactAlarmGranted && _status.batteryUnrestricted) {
      await _activateSession();
      return;
    }

    final confirmed = await _showPermissionIntroduction();
    if (!confirmed || !mounted) return;
    setState(() => _setupInProgress = true);
    await _continuePermissionSetup();
  }

  Future<bool> _showPermissionIntroduction() async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: const Text('إعداد وضع الجامع'),
              content: const Text(
                'لتفعيل الوضع الصامت المؤقت واستعادته حتى بعد سحب التطبيق، يحتاج التطبيق إلى: الإشعارات، التحكم في عدم الإزعاج، والمنبّه الدقيق، وإيقاف تقييد البطارية لهذا التطبيق. لا نطلب الموقع إلا عند إعداد مواقيت الصلاة لاحقاً.',
                style: TextStyle(height: 1.6),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('لاحقاً')),
                FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('متابعة الإعداد')),
              ],
            ),
          ),
        ) ??
        false;
  }

  Future<void> _continuePermissionSetup() async {
    final notification = await Permission.notification.status;
    if (!notification.isGranted) {
      final requested = await Permission.notification.request();
      if (!requested.isGranted) {
        if (mounted) setState(() {
          _setupInProgress = false;
          _notificationsGranted = false;
          _message = 'تحتاج إلى السماح بالإشعارات لإكمال إعداد وضع الجامع.';
        });
        return;
      }
    }

    await _refreshStatus();
    if (!mounted) return;
    if (!_status.dndAccessGranted) {
      await MasjidModeChannel.requestDndAccess();
      if (mounted) setState(() => _message = 'اسمح بالتحكم في عدم الإزعاج من إعدادات Android ثم ارجع للتطبيق.');
      return;
    }

    if (!_status.exactAlarmGranted) {
      await MasjidModeChannel.requestExactAlarmAccess();
      if (mounted) setState(() => _message = 'اسمح بالمنبّه الدقيق حتى ينتهي وضع الجامع حتى بعد سحب التطبيق.');
      return;
    }

    if (!_status.batteryUnrestricted) {
      await MasjidModeChannel.requestBatteryOptimizationAccess();
      if (mounted) setState(() => _message = 'لضمان رجوع الصوت في الوقت المحدد، اختر «السماح» أو «غير مقيّد» من إعداد البطارية ثم ارجع للتطبيق.');
      return;
    }

    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('masjid_permission_setup_complete', true);
    if (!mounted) return;
    setState(() {
      _setupInProgress = false;
      _setupComplete = true;
      _notificationsGranted = true;
      _message = 'اكتمل الإعداد. يمكنك الآن تفعيل وضع الجامع.';
    });
    await _activateSession();
  }

  Future<void> _activateSession() async {
    if (!_status.dndAccessGranted || !_status.exactAlarmGranted || !_status.batteryUnrestricted) {
      setState(() => _setupComplete = false);
      await _startOrRequestAccess();
      return;
    }

    if (!isValidSessionDuration(_selectedSeconds)) {
      setState(() => _message = 'اختر مدة من ثانية واحدة حتى 24 ساعة.');
      return;
    }

    setState(() => _busy = true);
    try {
      final updated = await MasjidModeChannel.start(_selectedSeconds);
      if (!mounted) return;
      setState(() {
        _status = updated;
        _now = DateTime.now().millisecondsSinceEpoch;
        _message = 'تم تفعيل وضع الجامع. سيعود الصوت تلقائياً عند انتهاء الوقت.';
      });
      _scheduleTicker();
    } catch (_) {
      if (mounted) setState(() => _message = 'تعذر تفعيل الوضع. تحقق من صلاحية عدم الإزعاج.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    setState(() => _busy = true);
    try {
      await MasjidModeChannel.cancel();
      await _refreshStatus();
      if (mounted) setState(() => _message = 'تم إلغاء وضع الجامع وعاد الهاتف إلى وضعه السابق.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _requestLocation() async {
    final result = await Permission.locationWhenInUse.request();
    if (!mounted) return;
    setState(() {
      _locationGranted = result.isGranted;
      _message = result.isGranted
          ? 'تم السماح بالموقع. سنستخدمه لاحقاً لحساب مواقيت الصلاة بدقة.'
          : 'يمكنك السماح بالموقع لاحقاً عند إعداد مواقيت الصلاة.';
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_opening) return const _OpeningPage();

    final active = _status.active && _remainingSeconds > 0;
    final display = active ? formatDuration(_remainingSeconds) : formatDuration(_selectedSeconds);
    return Scaffold(
      backgroundColor: const Color(0xFFF8F5EE),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const _BrandMark(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: const [
                      Text('وضع الجامع', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Color(0xFF18221F))),
                      SizedBox(height: 3),
                      Text('هدوء مؤقت باحترام وطمأنينة', style: TextStyle(color: Color(0xFF66726D))),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _StatusCard(
                active: active,
                dndGranted: _status.dndAccessGranted,
                exactAlarmGranted: _status.exactAlarmGranted,
                batteryUnrestricted: _status.batteryUnrestricted,
                time: display,
                message: _message,
                notificationsGranted: _notificationsGranted,
                setupComplete: _setupComplete,
              ),
              const SizedBox(height: 18),
              if (!active) _TimeInputs(hours: _hours, minutes: _minutes, seconds: _seconds),
              const Spacer(),
              _PermissionRow(
                locationGranted: _locationGranted,
                onLocationTap: _requestLocation,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _busy ? null : active ? _cancel : _startOrRequestAccess,
                  icon: Icon(active ? Icons.close_rounded : !_status.dndAccessGranted ? Icons.settings_rounded : !_status.exactAlarmGranted ? Icons.alarm_add_rounded : !_status.batteryUnrestricted ? Icons.battery_charging_full_rounded : Icons.volume_off_rounded),
                  label: Text(active ? 'إلغاء وضع الجامع' : !_status.dndAccessGranted ? 'منح صلاحية وضع الجامع' : !_status.exactAlarmGranted ? 'السماح بالمنبّه الدقيق' : !_status.batteryUnrestricted ? 'إعداد البطارية' : 'تفعيل وضع الجامع'),
                  style: FilledButton.styleFrom(
                    backgroundColor: active ? const Color(0xFFB44949) : const Color(0xFF0B3D2E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 17),
                    textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Text('يحفظ التطبيق وضع الهاتف السابق ويعيده تلقائياً عند انتهاء الجلسة.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Color(0xFF66726D))),
            ],
          ),
        ),
      ),
    );
  }
}

class _OpeningPage extends StatelessWidget {
  const _OpeningPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IslamicBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              children: [
                const Spacer(flex: 2),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(color: const Color(0xFFC58A28), width: 1.4),
                    color: const Color(0xFFF8F5EE),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 22, offset: Offset(0, 12))],
                  ),
                  padding: const EdgeInsets.all(14),
                  child: Image.asset('assets/images/app_icon.png', width: 100, height: 100),
                ),
                const SizedBox(height: 42),
                const Text('بِسْمِ اللَّهِ الرَّحْمَنِ الرَّحِيمِ', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFFF8F5EE), fontSize: 26, height: 1.8, fontWeight: FontWeight.w800)),
                const SizedBox(height: 18),
                Container(width: 88, height: 1, color: const Color(0xFFC58A28)),
                const SizedBox(height: 18),
                const Text('مَعين', style: TextStyle(color: Color(0xFFF8F5EE), fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                const Text('رفيق القرآن والصلاة', style: TextStyle(color: Color(0xFFD9E8E0), fontSize: 14)),
                const Spacer(flex: 3),
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(color: Color(0xFFC58A28), strokeWidth: 2),
                ),
                const SizedBox(height: 14),
                const Text('يرجى الانتظار', style: TextStyle(color: Color(0xFFD9E8E0), fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();
  @override
  Widget build(BuildContext context) => Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(color: const Color(0xFF0B3D2E), borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.notifications_off_rounded, color: Color(0xFFF8F5EE)),
      );
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.active, required this.dndGranted, required this.exactAlarmGranted, required this.batteryUnrestricted, required this.time, required this.message, required this.notificationsGranted, required this.setupComplete});
  final bool active;
  final bool dndGranted;
  final bool exactAlarmGranted;
  final bool batteryUnrestricted;
  final String time;
  final String message;
  final bool notificationsGranted;
  final bool setupComplete;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), border: Border.all(color: const Color(0xFFD9DED6)), boxShadow: const [BoxShadow(color: Color(0x11000000), blurRadius: 18, offset: Offset(0, 8))]),
        child: Column(
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              _Pill(label: active ? 'مفعّل' : dndGranted && exactAlarmGranted && batteryUnrestricted ? 'جاهز' : 'صلاحية مطلوبة', color: active ? const Color(0xFFC58A28) : dndGranted && exactAlarmGranted && batteryUnrestricted ? const Color(0xFF2F7A4C) : const Color(0xFF66726D)),
              Text(active ? 'الوقت المتبقي' : 'المدة المختارة', style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF18221F))),
            ]),
            const SizedBox(height: 20),
            Text(time, style: const TextStyle(fontSize: 52, fontWeight: FontWeight.w800, letterSpacing: 2, color: Color(0xFF0B3D2E))),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF66726D), height: 1.6)),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(notificationsGranted ? Icons.notifications_active_rounded : Icons.notifications_off_rounded, size: 16, color: const Color(0xFF66726D)),
              const SizedBox(width: 6),
              Text(notificationsGranted ? 'الإشعارات مفعّلة' : 'الإشعارات غير مفعّلة', style: const TextStyle(fontSize: 12, color: Color(0xFF66726D))),
            ]),
            if (!setupComplete) const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('عند أول تفعيل، سيشرح التطبيق الصلاحيات المطلوبة خطوة بخطوة.', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Color(0xFF66726D))),
            ),
          ],
        ),
      );
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: color.withValues(alpha: .14), borderRadius: BorderRadius.circular(20)), child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color)));
}

class _TimeInputs extends StatelessWidget {
  const _TimeInputs({required this.hours, required this.minutes, required this.seconds});
  final TextEditingController hours;
  final TextEditingController minutes;
  final TextEditingController seconds;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFD9DED6))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('مدة مخصصة', style: TextStyle(fontWeight: FontWeight.w800)), Text('حتى 24 ساعة', style: TextStyle(fontSize: 12, color: Color(0xFF66726D)))]),
          const SizedBox(height: 14),
          Row(children: [
            _TimeField(label: 'ساعات', controller: hours),
            const SizedBox(width: 9),
            _TimeField(label: 'دقائق', controller: minutes),
            const SizedBox(width: 9),
            _TimeField(label: 'ثوانٍ', controller: seconds),
          ]),
        ]),
      );
}

class _TimeField extends StatelessWidget {
  const _TimeField({required this.label, required this.controller});
  final String label;
  final TextEditingController controller;
  @override
  Widget build(BuildContext context) => Expanded(child: Column(children: [Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF66726D))), const SizedBox(height: 5), TextField(controller: controller, keyboardType: TextInputType.number, textAlign: TextAlign.center, maxLength: 2, decoration: InputDecoration(counterText: '', filled: true, fillColor: const Color(0xFFF8F5EE), contentPadding: const EdgeInsets.symmetric(vertical: 11), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)))]));
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({required this.locationGranted, required this.onLocationTap});
  final bool locationGranted;
  final VoidCallback onLocationTap;
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        onPressed: onLocationTap,
        icon: Icon(locationGranted ? Icons.location_on_rounded : Icons.location_on_outlined),
        label: Text(locationGranted ? 'الموقع مفعّل' : 'تحديد الموقع لمواقيت الصلاة'),
        style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF0B3D2E), side: const BorderSide(color: Color(0xFFD9DED6)), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
      );
}

class MueenShell extends StatefulWidget {
  const MueenShell({super.key, required this.isDark, required this.onToggleTheme});

  final bool isDark;
  final VoidCallback onToggleTheme;

  @override
  State<MueenShell> createState() => _MueenShellState();
}

class _MueenShellState extends State<MueenShell> {
  int _selectedIndex = 0;
  String _city = 'اختر المدينة';

  void _openPage(Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => Directionality(textDirection: TextDirection.rtl, child: page)));
  }

  void _chooseCity() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('اختيار المدينة', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              const Text('اختر مدينة يدوياً الآن، أو استخدم موقعك عند تجهيز خدمة المواقيت.', style: TextStyle(height: 1.5)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ['بغداد', 'مكة المكرمة', 'المدينة المنورة', 'النجف', 'البصرة'].map((city) => ChoiceChip(
                  label: Text(city),
                  selected: _city == city,
                  onSelected: (_) {
                    setState(() => _city = city);
                    Navigator.pop(context);
                  },
                )).toList(),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text('سيطلب التطبيق الموقع عند تفعيل خدمة المواقيت.')));
                },
                icon: const Icon(Icons.my_location_rounded),
                label: const Text('استخدام موقعي عند فتح التطبيق'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      _HomeTab(city: _city, onOpenMasjid: () => _openPage(const MasjidModeScreen()), onOpenPrayer: () => setState(() => _selectedIndex = 1), onOpenQuran: () => setState(() => _selectedIndex = 2)),
      _PrayerTab(city: _city, onChooseCity: _chooseCity),
      const QuranTab(),
      _DhikrTab(onOpenReminders: () => _openPage(const ReminderScreen())),
      _MoreTab(onOpenSupport: () => _openPage(const SupportScreen()), onOpenSupportUs: () => _openPage(const SupportUsScreen())),
    ];
    const titles = ['الرئيسية', 'صلاتي', 'المصحف', 'الأذكار', 'المزيد'];

    return Scaffold(
      endDrawer: _MueenDrawer(
        isDark: widget.isDark,
        onToggleTheme: widget.onToggleTheme,
        onOpenSupport: () => _openPage(const SupportScreen()),
        onOpenSupportUs: () => _openPage(const SupportUsScreen()),
        onOpenCity: _chooseCity,
      ),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        title: Column(
          children: [
            Text(titles[_selectedIndex], style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            const Text('مَعين', style: TextStyle(fontSize: 11, letterSpacing: 1.2)),
          ],
        ),
        leading: Builder(
          builder: (context) => IconButton(
            tooltip: 'القائمة',
            onPressed: () => Scaffold.of(context).openEndDrawer(),
            icon: const Icon(Icons.menu_rounded),
          ),
        ),
        actions: [
          IconButton(
            tooltip: widget.isDark ? 'الوضع النهاري' : 'الوضع الليلي',
            onPressed: widget.onToggleTheme,
            icon: Icon(widget.isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
          ),
        ],
      ),
      body: SafeArea(top: false, child: screens[_selectedIndex]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (value) => setState(() => _selectedIndex = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'الرئيسية'),
          NavigationDestination(icon: Icon(Icons.explore_outlined), selectedIcon: Icon(Icons.explore_rounded), label: 'صلاتي'),
          NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book_rounded), label: 'المصحف'),
          NavigationDestination(icon: Icon(Icons.spa_outlined), selectedIcon: Icon(Icons.spa_rounded), label: 'الأذكار'),
          NavigationDestination(icon: Icon(Icons.grid_view_rounded), selectedIcon: Icon(Icons.grid_view_rounded), label: 'المزيد'),
        ],
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab({required this.city, required this.onOpenMasjid, required this.onOpenPrayer, required this.onOpenQuran});
  final String city;
  final VoidCallback onOpenMasjid;
  final VoidCallback onOpenPrayer;
  final VoidCallback onOpenQuran;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Text('السلام عليكم', style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text('رفيقك الهادئ للقرآن والصلاة', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 18),
        _MueenCard(
          color: theme.colorScheme.primary,
          foreground: theme.colorScheme.onPrimary,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              _ChipLabel(label: 'صلاتي اليوم'),
              Icon(Icons.explore_rounded, color: theme.colorScheme.onPrimary),
            ]),
            const SizedBox(height: 18),
            const Text('ابدأ بإعداد مواقيتك', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(city == 'اختر المدينة' ? 'اختر مدينتك أو موقعك لعرض الصلاة التالية.' : 'المدينة المختارة: $city'),
            const SizedBox(height: 16),
            TextButton.icon(onPressed: onOpenPrayer, icon: const Icon(Icons.arrow_back_rounded), label: const Text('فتح صلاتي'), style: TextButton.styleFrom(foregroundColor: theme.colorScheme.onPrimary)),
          ]),
        ),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _ActionTile(icon: Icons.volume_off_rounded, title: 'وضع الجامع', subtitle: 'هدوء مؤقت', onTap: onOpenMasjid)),
          const SizedBox(width: 12),
          Expanded(child: _ActionTile(icon: Icons.menu_book_rounded, title: 'آخر قراءة', subtitle: 'ابدأ الآن', onTap: onOpenQuran)),
        ]),
        const SizedBox(height: 18),
        Text('لليوم', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        _MueenCard(child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(backgroundColor: const Color(0xFFC58A28).withValues(alpha: .16), child: const Icon(Icons.auto_graph_rounded, color: Color(0xFFC58A28))),
          title: const Text('وردك اليومي', style: TextStyle(fontWeight: FontWeight.w800)),
          subtitle: const Text('ابدأ وردك وحدد التقدم الذي يناسبك.'),
          trailing: const Icon(Icons.chevron_left_rounded),
        )),
        const SizedBox(height: 12),
        _MueenCard(child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(backgroundColor: theme.colorScheme.primary.withValues(alpha: .12), child: Icon(Icons.spa_rounded, color: theme.colorScheme.primary)),
          title: const Text('ذكر هادئ', style: TextStyle(fontWeight: FontWeight.w800)),
          subtitle: const Text('سبحان الله، والحمد لله، ولا إله إلا الله.'),
          trailing: const Icon(Icons.chevron_left_rounded),
        )),
      ],
    );
  }
}

class _MoreTab extends StatelessWidget {
  const _MoreTab({required this.onOpenSupport, required this.onOpenSupportUs});

  final VoidCallback onOpenSupport;
  final VoidCallback onOpenSupportUs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 24), children: [
      _MueenCard(color: theme.colorScheme.primaryContainer, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('رحلتك في مَعين', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        const Text('أدوات القراءة والتقويم والقبلة والدعم في مكان واحد مرتب.'),
        const SizedBox(height: 16),
        FilledButton.icon(onPressed: () => _showGentleMessage(context, 'ستتمكن من إنشاء وردك بعد إضافة أدوات الختمات.'), icon: const Icon(Icons.auto_graph_rounded), label: const Text('إدارة وردي')),
      ])),
      const SizedBox(height: 16),
      const _FeatureRow(icon: Icons.flag_outlined, title: 'وردي وختماتي', detail: 'تابع القراءة والحفظ والمراجعة محلياً.'),
      const _FeatureRow(icon: Icons.calendar_month_outlined, title: 'التقويم الهجري', detail: 'التاريخ والمناسبات الهجرية والميلادية.'),
      const _FeatureRow(icon: Icons.explore_outlined, title: 'القبلة', detail: 'اتجاه الكعبة مع معايرة المستشعر.'),
      _FeatureRow(icon: Icons.support_agent_rounded, title: 'الدعم الفني', detail: 'أرسل طلبك وتابع الرد عند ربط الخدمة.', onTap: onOpenSupport),
      _FeatureRow(icon: Icons.volunteer_activism_outlined, title: 'ادعمنا', detail: 'دعم اختياري لا يظهر تلقائياً.', onTap: onOpenSupportUs),
    ]);
  }
}

class _PrayerTab extends StatefulWidget {
  const _PrayerTab({required this.city, required this.onChooseCity});
  final String city;
  final VoidCallback onChooseCity;

  @override
  State<_PrayerTab> createState() => _PrayerTabState();
}

class _PrayerTabState extends State<_PrayerTab> {
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
    final hijri = HijriCalendar.now();
    final months = ['محرم', 'صفر', 'ربيع الأول', 'ربيع الآخر', 'جمادى الأولى', 'جمادى الآخرة', 'رجب', 'شعبان', 'رمضان', 'شوال', 'ذو القعدة', 'ذو الحجة'];
    final now = DateTime.now();
    final theme = Theme.of(context);
    final schedule = PrayerCalculator.forCity(widget.city, now: now);
    return ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 24), children: [
      _MueenCard(color: theme.colorScheme.primary, foreground: theme.colorScheme.onPrimary, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.location_on_outlined, size: 18),
          const SizedBox(width: 6),
          Expanded(child: Text(widget.city, style: const TextStyle(fontWeight: FontWeight.w900))),
          TextButton(onPressed: widget.onChooseCity, style: TextButton.styleFrom(foregroundColor: theme.colorScheme.onPrimary), child: const Text('تغيير')),
        ]),
        const SizedBox(height: 12),
        Text('${hijri.hDay} ${months[(hijri.hMonth - 1).clamp(0, 11)]} ${hijri.hYear} هـ', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text('${now.day}/${now.month}/${now.year} م'),
        const SizedBox(height: 10),
        const Text('المواقيت تحسب محلياً حسب المدينة وطريقة الحساب المختارة.'),
      ])),
      const SizedBox(height: 14),
      if (schedule == null)
        _MueenCard(child: Column(children: [
          const Icon(Icons.location_searching_rounded, size: 38),
          const SizedBox(height: 10),
          const Text('اختر مدينة لعرض مواقيت حقيقية', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          const Text('يبقى اختيار المدينة محلياً، ولا يُطلب الموقع إلا عندما تختاره أنت.', textAlign: TextAlign.center),
          const SizedBox(height: 14),
          FilledButton.icon(onPressed: widget.onChooseCity, icon: const Icon(Icons.location_on_outlined), label: const Text('اختيار المدينة')),
        ]))
      else ...[
        _MueenCard(color: theme.colorScheme.primaryContainer, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('الصلاة التالية', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(child: Text(schedule.next.label, style: const TextStyle(fontSize: 29, fontWeight: FontWeight.w900))),
            Text(PrayerCalculator.formatTime(schedule.next.time), style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
          ]),
          const SizedBox(height: 6),
          Text(PrayerCalculator.remainingLabel(now, schedule.next.time)),
          const SizedBox(height: 12),
          LinearProgressIndicator(value: _dayProgress(now), minHeight: 7, borderRadius: BorderRadius.circular(8)),
          const SizedBox(height: 8),
          const Text('طريقة الحساب: كراتشي • العصر: حنفي', style: TextStyle(fontSize: 12)),
        ])),
        const SizedBox(height: 18),
        Text('مواقيت اليوم', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        ...schedule.entries.map((entry) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _MueenCard(
            color: entry.id == schedule.next.id ? theme.colorScheme.primaryContainer : null,
            child: Row(children: [
              Icon(entry.id == schedule.next.id ? Icons.notifications_active_rounded : Icons.notifications_none_rounded, color: entry.id == schedule.next.id ? const Color(0xFFC58A28) : theme.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(child: Text(entry.label, style: const TextStyle(fontWeight: FontWeight.w900))),
              Text(PrayerCalculator.formatTime(entry.time), style: const TextStyle(fontWeight: FontWeight.w900)),
            ]),
          ),
        )),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _PrayerQuickAction(icon: Icons.explore_outlined, label: 'القبلة', onTap: () => _showGentleMessage(context, 'ستعمل البوصلة بعد ربط حساسات الهاتف وحساب اتجاه القبلة.'))),
          const SizedBox(width: 10),
          Expanded(child: _PrayerQuickAction(icon: Icons.calendar_month_outlined, label: 'التقويم', onTap: () => _showGentleMessage(context, 'سيظهر التقويم الكامل والمناسبات في التحديث التالي.'))),
          const SizedBox(width: 10),
          Expanded(child: _PrayerQuickAction(icon: Icons.volume_off_outlined, label: 'وضع الجامع', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MasjidModeScreen())))),
        ]),
      ],
    ]);
  }
}

class _PrayerQuickAction extends StatelessWidget {
  const _PrayerQuickAction({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: _MueenCard(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(children: [Icon(icon, color: Theme.of(context).colorScheme.primary), const SizedBox(height: 6), Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800))]),
          ),
        ),
      );
}

double _dayProgress(DateTime now) {
  final minutes = now.hour * 60 + now.minute;
  return (minutes / (24 * 60)).clamp(0, 1).toDouble();
}

class _DhikrTab extends StatelessWidget {
  const _DhikrTab({required this.onOpenReminders});
  final VoidCallback onOpenReminders;

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 24), children: [
      const _DhikrCategory(title: 'أذكار الصباح', subtitle: 'ابدأ يومك بذكر الله.', icon: Icons.wb_sunny_outlined),
      const SizedBox(height: 10),
      const _DhikrCategory(title: 'أذكار المساء', subtitle: 'هدوء وطمأنينة في آخر اليوم.', icon: Icons.nightlight_round),
      const SizedBox(height: 10),
      const _DhikrCategory(title: 'أذكار بعد الصلاة', subtitle: 'أذكار موثقة سهلة الوصول.', icon: Icons.mosque_outlined),
      const SizedBox(height: 18),
      _MueenCard(child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const CircleAvatar(child: Icon(Icons.alarm_add_rounded)),
        title: const Text('ذكّرني', style: TextStyle(fontWeight: FontWeight.w900)),
        subtitle: const Text('أنشئ أكثر من تذكير في الوقت الذي تختاره.'),
        trailing: const Icon(Icons.chevron_left_rounded),
        onTap: onOpenReminders,
      )),
      const SizedBox(height: 10),
      _MueenCard(child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const CircleAvatar(child: Icon(Icons.add_circle_outline_rounded)),
        title: const Text('المسبحة', style: TextStyle(fontWeight: FontWeight.w900)),
        subtitle: const Text('عداد بسيط يحفظ تسبيحك محلياً.'),
        trailing: const Icon(Icons.chevron_left_rounded),
        onTap: () => _showGentleMessage(context, 'ستظهر المسبحة الرقمية في هذه الصفحة.'),
      )),
    ]);
  }
}

class _MueenDrawer extends StatelessWidget {
  const _MueenDrawer({required this.isDark, required this.onToggleTheme, required this.onOpenSupport, required this.onOpenSupportUs, required this.onOpenCity});
  final bool isDark;
  final VoidCallback onToggleTheme;
  final VoidCallback onOpenSupport;
  final VoidCallback onOpenSupportUs;
  final VoidCallback onOpenCity;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(child: ListView(padding: const EdgeInsets.fromLTRB(18, 12, 18, 24), children: [
        Row(children: [
          Container(width: 44, height: 44, decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.auto_stories_rounded, color: Color(0xFFF8F5EE))),
          const SizedBox(width: 10),
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('مَعين', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)), Text('رفيق القرآن والصلاة', style: TextStyle(fontSize: 12))]),
        ]),
        const SizedBox(height: 22),
        _DrawerItem(icon: isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined, title: isDark ? 'الوضع النهاري' : 'الوضع الليلي', onTap: onToggleTheme),
        _DrawerItem(icon: Icons.location_on_outlined, title: 'المدينة وطريقة الحساب', onTap: onOpenCity),
        _DrawerItem(icon: Icons.notifications_outlined, title: 'الإشعارات والصلاحيات', onTap: () => _showGentleMessage(context, 'ستظهر إعدادات إشعارات المواقيت والأذكار هنا.')),
        const Divider(height: 28),
        _DrawerItem(icon: Icons.help_outline_rounded, title: 'التعليمات', onTap: () => _showGentleMessage(context, 'سنعرض هنا دليلاً مختصراً لاستخدام مَعين.')),
        _DrawerItem(icon: Icons.support_agent_rounded, title: 'الدعم الفني', onTap: onOpenSupport),
        _DrawerItem(icon: Icons.volunteer_activism_outlined, title: 'ادعمنا', onTap: onOpenSupportUs),
        _DrawerItem(icon: Icons.system_update_alt_rounded, title: 'تحقق من التحديث', onTap: () => _showGentleMessage(context, 'سيتحقق التطبيق من الإصدار عند ربط صفحة الإصدارات.')),
        const Divider(height: 28),
        _DrawerItem(icon: Icons.info_outline_rounded, title: 'حول المصحف والمصادر', onTap: () => _showGentleMessage(context, 'بيانات المصحف محلية. المصدر: quran-json، النص العثماني من موسوعة القرآن الكريم، CC BY-SA 4.0.')),
        _DrawerItem(icon: Icons.privacy_tip_outlined, title: 'الخصوصية', onTap: () => _showGentleMessage(context, 'لا يحتاج مَعين إلى حساب، وموقعك اختياري ويستخدم محلياً للمواقيت.')),
      ])),
    );
  }
}

class ReminderScreen extends StatefulWidget {
  const ReminderScreen({super.key});
  @override
  State<ReminderScreen> createState() => _ReminderScreenState();
}

class _ReminderScreenState extends State<ReminderScreen> {
  final List<_ReminderItem> _items = [
    _ReminderItem(text: 'اللهم صل على سيدنا محمد', interval: 'كل 20 دقيقة', enabled: false),
    _ReminderItem(text: 'سبحان الله وبحمده', interval: 'كل ساعة', enabled: false),
  ];

  void _addReminder() {
    final text = TextEditingController();
    final interval = TextEditingController(text: '15 دقيقة');
    showDialog<void>(context: context, builder: (context) => AlertDialog(
      title: const Text('تذكير جديد'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: text, textDirection: TextDirection.rtl, decoration: const InputDecoration(labelText: 'نص الذكر')),
        TextField(controller: interval, textDirection: TextDirection.rtl, decoration: const InputDecoration(labelText: 'التكرار، مثال: 5 دقائق')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        FilledButton(onPressed: () {
          if (text.text.trim().isEmpty) return;
          setState(() => _items.add(_ReminderItem(text: text.text.trim(), interval: interval.text.trim().isEmpty ? '15 دقيقة' : interval.text.trim(), enabled: true)));
          Navigator.pop(context);
        }, child: const Text('إضافة')),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('ذكّرني')),
    floatingActionButton: FloatingActionButton.extended(onPressed: _addReminder, icon: const Icon(Icons.add_rounded), label: const Text('تذكير جديد')),
    body: ListView(padding: const EdgeInsets.all(20), children: [
      const Text('أنشئ تذكيرات متعددة، ولكل تذكير وقت وتشغيل مستقل.', style: TextStyle(height: 1.6)),
      const SizedBox(height: 14),
      ..._items.asMap().entries.map((entry) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _MueenCard(child: SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(entry.value.text, style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text(entry.value.interval),
          value: entry.value.enabled,
          onChanged: (value) => setState(() => entry.value.enabled = value),
        )),
      )),
      const SizedBox(height: 60),
    ]),
  );
}

class _ReminderItem {
  _ReminderItem({required this.text, required this.interval, required this.enabled});
  final String text;
  final String interval;
  bool enabled;
}

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});
  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final _message = TextEditingController();
  final List<String> _messages = [];
  String _topic = 'مشكلة في التطبيق';

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  void _send() {
    final text = _message.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(text);
      _message.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ رسالتك كطلب دعم محلياً. سترسل عند ربط الدعم الفني.')));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('الدعم الفني')),
    body: SafeArea(child: Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 12), child: _MueenCard(color: Theme.of(context).colorScheme.primaryContainer, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('كيف يمكننا مساعدتك؟', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        const SizedBox(height: 6),
        const Text('اشرح المشكلة، ويمكنك لاحقاً إرفاق لقطة شاشة. سيظهر طلبك في لوحة الإدارة كمحادثة منظمة.'),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(value: _topic, items: const [DropdownMenuItem(value: 'مشكلة في التطبيق', child: Text('مشكلة في التطبيق')), DropdownMenuItem(value: 'اقتراح ميزة', child: Text('اقتراح ميزة')), DropdownMenuItem(value: 'مشكلة في المواقيت', child: Text('مشكلة في المواقيت'))], onChanged: (value) => setState(() => _topic = value ?? _topic), decoration: const InputDecoration(labelText: 'نوع الطلب')),
      ]))),
      Expanded(
        child: _messages.isEmpty
            ? const Center(child: Text('اكتب أول رسالة لفتح طلب دعم جديد.'))
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _messages.length,
                itemBuilder: (_, index) => Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      _messages[index],
                      style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
                    ),
                  ),
                ),
              ),
      ),
      Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 16), child: Row(children: [
        IconButton(onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('سيُتاح رفع صورة برابط مؤقت عند تفعيل تخزين الدعم الفني.'))), icon: const Icon(Icons.attach_file_rounded)),
        Expanded(child: TextField(controller: _message, textDirection: TextDirection.rtl, onSubmitted: (_) => _send(), decoration: const InputDecoration(hintText: 'اكتب رسالتك...'))),
        IconButton(onPressed: _send, icon: const Icon(Icons.send_rounded)),
      ])),
    ])),
  );
}

class SupportUsScreen extends StatelessWidget {
  const SupportUsScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('ادعمنا')),
    body: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _MueenCard(color: Theme.of(context).colorScheme.primaryContainer, child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('معاً ليستمر النفع', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
        SizedBox(height: 8),
        Text('ستظهر هنا حملات الدعم وطرق المساهمة فقط عندما يفعّلها مدير التطبيق من لوحة الإدارة.'),
      ])),
      const SizedBox(height: 16),
      OutlinedButton.icon(onPressed: () => _showGentleMessage(context, 'زر حملة الدعم غير مفعّل حالياً.'), icon: const Icon(Icons.ads_click_outlined), label: const Text('ادعمنا بإعلان')),
      const SizedBox(height: 10),
      OutlinedButton.icon(onPressed: () => _showGentleMessage(context, 'طرق الدعم ستظهر هنا عند تفعيلها من لوحة الإدارة.'), icon: const Icon(Icons.volunteer_activism_outlined), label: const Text('طرق الدعم')),
    ])),
  );
}

class _MueenCard extends StatelessWidget {
  const _MueenCard({required this.child, this.color, this.foreground});
  final Widget child;
  final Color? color;
  final Color? foreground;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: color ?? Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: .55)),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .035), blurRadius: 16, offset: const Offset(0, 7))],
    ),
    child: DefaultTextStyle.merge(style: TextStyle(color: foreground), child: child),
  );
}

class _ChipLabel extends StatelessWidget {
  const _ChipLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: .14),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
  );
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: _MueenCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 16),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 2),
        Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      ])),
    ),
  );
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.icon, required this.title, required this.detail, this.onTap});
  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: _MueenCard(child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(icon, color: Theme.of(context).colorScheme.primary), title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text(detail), trailing: const Icon(Icons.chevron_left_rounded), onTap: onTap)),
  );
}

class _DhikrCategory extends StatelessWidget {
  const _DhikrCategory({required this.title, required this.subtitle, required this.icon});
  final String title;
  final String subtitle;
  final IconData icon;
  @override
  Widget build(BuildContext context) => _MueenCard(child: ListTile(contentPadding: EdgeInsets.zero, leading: CircleAvatar(backgroundColor: Theme.of(context).colorScheme.primaryContainer, child: Icon(icon, color: Theme.of(context).colorScheme.primary)), title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)), subtitle: Text(subtitle), trailing: const Icon(Icons.chevron_left_rounded), onTap: () => _showGentleMessage(context, 'سيظهر نص الذكر ومصدره في هذه الصفحة.')));
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({required this.icon, required this.title, required this.onTap});
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(leading: Icon(icon), title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)), onTap: onTap, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)));
}

void _showGentleMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
