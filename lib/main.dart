import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/duration.dart';
import 'core/masjid_mode_channel.dart';
import 'features/mueen_feature_screens.dart';
import 'prayer/prayer_calculator.dart';
import 'prayer/location_service.dart';
import 'prayer/night_fasting_screen.dart';
import 'prayer/prayer_notification_service.dart';
import 'quran/quran_tab.dart';
import 'ui/mueen_design.dart';
import 'widgets/islamic_background.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PrayerNotificationService.instance.initialize();
  runApp(const MueenApp());
}

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
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFFF8F5EE), foregroundColor: Color(0xFF17251F), elevation: 0, surfaceTintColor: Colors.transparent),
        navigationBarTheme: NavigationBarThemeData(backgroundColor: const Color(0xFFF0F4EF), indicatorColor: const Color(0xFFD6F0E2), labelTextStyle: WidgetStateProperty.all(const TextStyle(fontWeight: FontWeight.w800, fontSize: 12))),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        fontFamily: 'sans',
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF76C79F), brightness: Brightness.dark),
        scaffoldBackgroundColor: const Color(0xFF0B1713),
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF0B1713), foregroundColor: Color(0xFFF2F4EE), elevation: 0, surfaceTintColor: Colors.transparent),
        navigationBarTheme: NavigationBarThemeData(backgroundColor: const Color(0xFF10221B), indicatorColor: const Color(0xFF1D513C), labelTextStyle: WidgetStateProperty.all(const TextStyle(fontWeight: FontWeight.w800, fontSize: 12))),
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
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedIndex = 0;
  String _city = 'اختر المدينة';

  @override
  void initState() {
    super.initState();
    _restoreCity();
  }

  Future<void> _restoreCity() async {
    final preferences = await SharedPreferences.getInstance();
    final saved = preferences.getString('prayer_city');
    if (saved != null && mounted) setState(() => _city = saved);
  }

  Future<void> _saveCity(String city) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('prayer_city', city);
    await PrayerNotificationService.instance.scheduleNext24Hours(city);
    if (mounted) setState(() => _city = city);
  }

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
                  onSelected: (_) { _saveCity(city); Navigator.pop(context); },
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

  Future<void> _openNightFasting() async {
    if (_city == 'اختر المدينة') {
      _chooseCity();
      return;
    }
    _openPage(NightFastingScreen(city: _city));
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      _HomeTab(city: _city, onOpenMasjid: () => _openPage(const MasjidModeScreen()), onOpenPrayer: () => setState(() => _selectedIndex = 1), onOpenQuran: () => setState(() => _selectedIndex = 2)),
      _PrayerTab(city: _city, onChooseCity: _chooseCity),
      const QuranTab(),
      _DhikrTab(onOpenReminders: () => _openPage(const ReminderScreen())),
      _MoreTab(
        onOpenNightFasting: _openNightFasting,
        onOpenSupport: () => _openPage(const SupportScreen()),
        onOpenSupportUs: () => _openPage(const SupportUsScreen()),
        onOpenLocation: () => _openPage(MueenLocationScreen(
          initialCity: _city,
          onSave: _saveCity,
          onAutoLocate: () async => (await PrayerLocationService().detectNearestCity()).name,
        )),
        onOpenAdhan: () => _openPage(const AdhanSelectionScreen()),
        onOpenSounds: () => _openPage(const SoundLibraryScreen()),
        onOpenKhatma: () => _openPage(const KhatmaScreen()),
        onOpenQibla: () => _openPage(const QiblaScreen()),
        onOpenCalendar: () => _openPage(const MueenCalendarScreen()),
      ),
    ];
    const titles = ['مَعين', 'صلاتي', 'المصحف', 'ذِكري', 'المزيد'];
    const subtitles = ['رفيق القرآن والصلاة', 'مواقيت محلية', 'قراءة دون إنترنت', 'ورد يومي لطيف', 'إعداداتك ورفيقك اليومي'];

    return Scaffold(
      key: _scaffoldKey,
      endDrawer: _MueenDrawer(
        isDark: widget.isDark,
        onToggleTheme: widget.onToggleTheme,
        onOpenSupport: () => _openPage(const SupportScreen()),
        onOpenSupportUs: () => _openPage(const SupportUsScreen()),
        onOpenCity: _chooseCity,
      ),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: SafeArea(
          bottom: false,
          child: MueenPageHeader(
            title: titles[_selectedIndex],
            subtitle: subtitles[_selectedIndex],
            onMenu: () => _scaffoldKey.currentState?.openEndDrawer(),
            onTheme: widget.onToggleTheme,
            darkMode: widget.isDark,
          ),
        ),
      ),
      body: SafeArea(top: false, child: screens[_selectedIndex]),
      bottomNavigationBar: _MueenBottomNav(
        selectedIndex: _selectedIndex,
        onSelected: (value) => setState(() => _selectedIndex = value),
      ),
    );
  }
}

class _MueenBottomNav extends StatelessWidget {
  const _MueenBottomNav({required this.selectedIndex, required this.onSelected});

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const _items = <_BottomNavItem>[
    _BottomNavItem(label: 'الرئيسية', icon: Icons.home_outlined, selectedIcon: Icons.home_rounded),
    _BottomNavItem(label: 'صلاتي', icon: Icons.timelapse_outlined, selectedIcon: Icons.timelapse_rounded),
    _BottomNavItem(label: 'المصحف', icon: Icons.auto_stories_outlined, selectedIcon: Icons.auto_stories_rounded),
    _BottomNavItem(label: 'الأذكار', icon: Icons.local_florist_outlined, selectedIcon: Icons.local_florist_rounded),
    _BottomNavItem(label: 'المزيد', icon: Icons.dashboard_outlined, selectedIcon: Icons.dashboard_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withValues(alpha: .96),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: .42)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .08), blurRadius: 18, offset: const Offset(0, 7))],
        ),
        child: Row(
          children: List.generate(_items.length, (index) {
            final item = _items[index];
            final selected = index == selectedIndex;
            return Expanded(
              child: Semantics(
                selected: selected,
                button: true,
                label: item.label,
                child: InkWell(
                  onTap: () => onSelected(index),
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOut,
                        width: 43,
                        height: 43,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: selected ? theme.colorScheme.primary : theme.colorScheme.primary.withValues(alpha: .08),
                          boxShadow: selected ? [BoxShadow(color: theme.colorScheme.primary.withValues(alpha: .22), blurRadius: 10, offset: const Offset(0, 4))] : null,
                        ),
                        child: Icon(selected ? item.selectedIcon : item.icon, color: selected ? theme.colorScheme.onPrimary : theme.colorScheme.primary, size: 22),
                      ),
                      const SizedBox(height: 5),
                      Text(item.label, style: TextStyle(fontSize: 10, fontWeight: selected ? FontWeight.w900 : FontWeight.w700, color: selected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant)),
                    ]),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _BottomNavItem {
  const _BottomNavItem({required this.label, required this.icon, required this.selectedIcon});

  final String label;
  final IconData icon;
  final IconData selectedIcon;
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
    final schedule = PrayerCalculator.forCity(city);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
      children: [
        Row(children: [
          Expanded(child: Text('السبت ${DateTime.now().day} آب', style: theme.textTheme.titleMedium?.copyWith(color: MueenColors.ink, fontWeight: FontWeight.w900))),
          const MueenIconBubble(icon: Icons.auto_stories_rounded, color: MueenColors.gold, size: 38),
        ]),
        const SizedBox(height: 3),
        const Text('رفيقك اليومي للقرآن والصلاة', style: TextStyle(color: MueenColors.muted, fontWeight: FontWeight.w700)),
        const SizedBox(height: 14),
        _PrayerHeroCard(schedule: schedule, city: city, onOpenPrayer: onOpenPrayer),
        const SizedBox(height: 13),
        Row(children: [
          Expanded(child: _ActionTile(icon: Icons.volume_off_rounded, title: 'وضع الجامع', subtitle: 'هدوء مؤقت', onTap: onOpenMasjid)),
          const SizedBox(width: 12),
          Expanded(child: _ActionTile(icon: Icons.menu_book_rounded, title: 'متابعة القراءة', subtitle: 'من آخر موضع', onTap: onOpenQuran)),
        ]),
        const MueenSectionLabel(title: 'لليوم'),
        _MueenCard(child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(backgroundColor: const Color(0xFFC58A28).withValues(alpha: .16), child: const Icon(Icons.auto_graph_rounded, color: Color(0xFFC58A28))),
          title: const Text('وردك اليومي', style: TextStyle(fontWeight: FontWeight.w900)),
          subtitle: const Text('ختمتك وملاحظاتك وعلاماتك محفوظة محلياً.'),
          trailing: const Icon(Icons.chevron_left_rounded),
          onTap: onOpenQuran,
        )),
        const SizedBox(height: 12),
        _MueenCard(child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(backgroundColor: theme.colorScheme.primary.withValues(alpha: .12), child: Icon(Icons.nights_stay_outlined, color: theme.colorScheme.primary)),
          title: const Text('ليلتي وصيامي', style: TextStyle(fontWeight: FontWeight.w900)),
          subtitle: const Text('السحور والإفطار وأوقات الليل بحسب مدينتك.'),
          trailing: const Icon(Icons.chevron_left_rounded),
          onTap: onOpenPrayer,
        )),
      ],
    );
  }
}

class _PrayerHeroCard extends StatelessWidget {
  const _PrayerHeroCard({required this.schedule, required this.city, required this.onOpenPrayer});

  final PrayerSchedule? schedule;
  final String city;
  final VoidCallback onOpenPrayer;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final ready = schedule != null;
    return InkWell(
      onTap: onOpenPrayer,
      borderRadius: BorderRadius.circular(31),
      child: MueenSurface(
        radius: 31,
        padding: const EdgeInsets.fromLTRB(16, 15, 16, 13),
        child: Column(children: [
          Row(children: [
            const MueenIconBubble(icon: Icons.location_on_rounded, color: MueenColors.gold, size: 34),
            const SizedBox(width: 8),
            Expanded(child: Text(ready ? city : 'أكمل إعداد المدينة', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900))),
            const Icon(Icons.chevron_left_rounded, color: MueenColors.gold),
          ]),
          const SizedBox(height: 8),
          SizedBox(
            height: 228,
            child: Stack(alignment: Alignment.center, children: [
              Container(width: 220, height: 220, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: MueenColors.forest, width: 17))),
              Container(width: 220, height: 220, decoration: BoxDecoration(shape: BoxShape.circle, border: Border(top: const BorderSide(color: MueenColors.gold, width: 17), right: const BorderSide(color: MueenColors.gold, width: 17)))),
              Container(width: 177, height: 177, decoration: const BoxDecoration(shape: BoxShape.circle, color: MueenColors.paper)),
              Column(mainAxisSize: MainAxisSize.min, children: [
                Text(ready ? 'الصلاة التالية' : 'المواقيت المحلية', style: const TextStyle(color: MueenColors.muted, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(ready ? PrayerCalculator.formatTime(schedule!.next.time) : '--:--', style: const TextStyle(color: MueenColors.forest, fontSize: 41, fontWeight: FontWeight.w900, letterSpacing: 1)),
                Text(ready ? schedule!.next.label : 'اختر مدينة', style: const TextStyle(color: MueenColors.ink, fontSize: 19, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(ready ? PrayerCalculator.remainingLabel(now, schedule!.next.time) : 'تعمل دون إنترنت', style: const TextStyle(color: MueenColors.muted, fontSize: 11, fontWeight: FontWeight.w700)),
              ]),
            ]),
          ),
          const Divider(color: MueenColors.line),
          Text(ready ? 'المواقيت محسوبة محلياً حسب مدينتك' : 'اختر مدينة أو استخدم موقعك لاحقاً', style: const TextStyle(color: MueenColors.muted, fontSize: 11)),
        ]),
      ),
    );
  }
}

class _MoreTab extends StatelessWidget {
  const _MoreTab({required this.onOpenNightFasting, required this.onOpenSupport, required this.onOpenSupportUs, required this.onOpenLocation, required this.onOpenAdhan, required this.onOpenSounds, required this.onOpenKhatma, required this.onOpenQibla, required this.onOpenCalendar});

  final VoidCallback onOpenNightFasting;
  final VoidCallback onOpenSupport;
  final VoidCallback onOpenSupportUs;
  final VoidCallback onOpenLocation;
  final VoidCallback onOpenAdhan;
  final VoidCallback onOpenSounds;
  final VoidCallback onOpenKhatma;
  final VoidCallback onOpenQibla;
  final VoidCallback onOpenCalendar;

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
      _FeatureRow(icon: Icons.flag_outlined, title: 'وردي وختماتي', detail: 'تابع القراءة والحفظ والمراجعة محلياً.', onTap: onOpenKhatma),
      _FeatureRow(icon: Icons.nights_stay_outlined, title: 'ليلتي وصيامي', detail: 'السحور والإفطار وأوقات الليل بحساب محلي.', onTap: onOpenNightFasting),
      _FeatureRow(icon: Icons.calendar_month_outlined, title: 'التقويم الهجري', detail: 'التاريخ والمناسبات الهجرية والميلادية.', onTap: onOpenCalendar),
      _FeatureRow(icon: Icons.explore_outlined, title: 'القبلة', detail: 'اتجاه الكعبة مع معايرة المستشعر.', onTap: onOpenQibla),
      _FeatureRow(icon: Icons.location_on_outlined, title: 'المدينة والموقع', detail: 'اختيار يدوي أو GPS اختياري.', onTap: onOpenLocation),
      _FeatureRow(icon: Icons.volume_up_outlined, title: 'اختيار الأذان', detail: 'صوت مستقل لكل صلاة.', onTap: onOpenAdhan),
      _FeatureRow(icon: Icons.library_music_outlined, title: 'مكتبة الأصوات', detail: 'تنزيل صريح وحفظ محلي.', onTap: onOpenSounds),
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
    return ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 24), children: [
      Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('مواقيت اليوم', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text('${hijri.hDay} ${months[(hijri.hMonth - 1).clamp(0, 11)]} ${hijri.hYear} هـ  •  ${now.day}/${now.month}/${now.year} م', style: theme.textTheme.bodySmall),
        ])),
        InkWell(
          onTap: widget.onChooseCity,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(color: theme.colorScheme.primary.withValues(alpha: .10), borderRadius: BorderRadius.circular(18)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.location_on_outlined, color: theme.colorScheme.primary, size: 18), const SizedBox(width: 4), Text(widget.city, style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w900, fontSize: 12))]),
          ),
        ),
      ]),
      const SizedBox(height: 18),
      if (schedule == null)
        _MueenCard(child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(children: [
            Container(width: 54, height: 54, decoration: BoxDecoration(shape: BoxShape.circle, color: theme.colorScheme.primary.withValues(alpha: .10)), child: Icon(Icons.location_searching_rounded, size: 28, color: theme.colorScheme.primary)),
            const SizedBox(height: 14),
            const Text('اختر مدينة لعرض مواقيت حقيقية', style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            const Text('اختيار المدينة يبقى محلياً، ولا نطلب موقعك إلا عندما تختاره أنت.', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(onPressed: widget.onChooseCity, icon: const Icon(Icons.location_on_outlined), label: const Text('اختيار المدينة')),
          ]),
        ))
      else ...[
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [Color(0xFF0B3D2E), Color(0xFF17664C)]),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [BoxShadow(color: const Color(0xFF0B3D2E).withValues(alpha: .18), blurRadius: 20, offset: const Offset(0, 10))],
          ),
          child: Stack(children: [
            Positioned(left: -18, top: -24, child: Container(width: 100, height: 100, decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFE4B85F).withValues(alpha: .10)))),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [Icon(Icons.timelapse_rounded, color: Color(0xFFE4B85F), size: 20), SizedBox(width: 7), Text('الصلاة التالية', style: TextStyle(color: Color(0xFFF8F5EE), fontWeight: FontWeight.w800))]),
              const SizedBox(height: 18),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Expanded(child: Text(schedule.next.label, style: const TextStyle(color: Color(0xFFF8F5EE), fontSize: 31, fontWeight: FontWeight.w900))),
                Text(PrayerCalculator.formatTime(schedule.next.time), style: const TextStyle(color: Color(0xFFF8F5EE), fontSize: 28, fontWeight: FontWeight.w900)),
              ]),
              const SizedBox(height: 6),
              Text(PrayerCalculator.remainingLabel(now, schedule.next.time), style: const TextStyle(color: Color(0xFFF8F5EE))),
              const SizedBox(height: 14),
              ClipRRect(borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator(value: _dayProgress(now), minHeight: 7, backgroundColor: const Color(0x33FFFFFF), valueColor: const AlwaysStoppedAnimation(Color(0xFFE4B85F)))),
              const SizedBox(height: 10),
              const Text('حساب محلي • كراتشي • العصر حنفي', style: TextStyle(color: Color(0xDDF8F5EE), fontSize: 12, fontWeight: FontWeight.w700)),
            ]),
          ]),
        ),
        const SizedBox(height: 22),
        Row(children: [Text('مواقيت اليوم', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)), const Spacer(), Text('محلي', style: TextStyle(color: theme.colorScheme.primary, fontSize: 12, fontWeight: FontWeight.w900))]),
        const SizedBox(height: 10),
        ...schedule.entries.map((entry) {
          final active = entry.id == schedule.next.id;
          return Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
              decoration: BoxDecoration(
                color: active ? theme.colorScheme.primary.withValues(alpha: .10) : theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: active ? const Color(0xFFC58A28).withValues(alpha: .75) : theme.colorScheme.outlineVariant.withValues(alpha: .45)),
              ),
              child: Row(children: [
                Container(width: 35, height: 35, decoration: BoxDecoration(shape: BoxShape.circle, color: active ? theme.colorScheme.primary : theme.colorScheme.primary.withValues(alpha: .09)), child: Icon(active ? Icons.notifications_active_rounded : Icons.notifications_none_rounded, color: active ? theme.colorScheme.onPrimary : theme.colorScheme.primary, size: 19)),
                const SizedBox(width: 12),
                Expanded(child: Text(entry.label, style: TextStyle(fontWeight: active ? FontWeight.w900 : FontWeight.w800))),
                Text(PrayerCalculator.formatTime(entry.time), style: TextStyle(color: active ? theme.colorScheme.primary : theme.colorScheme.onSurface, fontWeight: FontWeight.w900, fontSize: 17)),
              ]),
            ),
          );
        }),
        const SizedBox(height: 8),
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
        borderRadius: BorderRadius.circular(20),
        child: _MueenCard(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(children: [
              Container(width: 41, height: 41, decoration: BoxDecoration(shape: BoxShape.circle, color: Theme.of(context).colorScheme.primary.withValues(alpha: .10)), child: Icon(icon, color: Theme.of(context).colorScheme.primary)),
              const SizedBox(height: 8),
              Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
            ]),
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
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: _MueenCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 38, height: 38, decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withValues(alpha: .12), borderRadius: BorderRadius.circular(13)), child: Icon(icon, color: Theme.of(context).colorScheme.primary)),
        const SizedBox(height: 18),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w900, height: 1.15)),
        const SizedBox(height: 4),
        Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.25)),
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
