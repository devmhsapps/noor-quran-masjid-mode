import 'dart:async';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/duration.dart';
import 'core/masjid_mode_channel.dart';
import 'widgets/islamic_background.dart';

void main() => runApp(const NoorQuranApp());

class NoorQuranApp extends StatelessWidget {
  const NoorQuranApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'نور القرآن',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0B3D2E),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const Directionality(
        textDirection: TextDirection.rtl,
        child: MasjidModeScreen(),
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
                const Text('نور القرآن', style: TextStyle(color: Color(0xFFF8F5EE), fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                const Text('وضع الجامع الهادئ', style: TextStyle(color: Color(0xFFD9E8E0), fontSize: 14)),
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
