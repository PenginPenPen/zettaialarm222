import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:zettaialarm222/alarmpage.dart';
import 'package:zettaialarm222/services/alarm_service.dart';
import 'package:zettaialarm222/settingpage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await initializeDateFormatting('ja');
  } catch (_) {}
  await AlarmService.instance.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF8B7CF6),
      brightness: Brightness.dark,
    );
    return MaterialApp(
      title: '絶対アラーム',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: const Color(0xFF0E0E1A),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      home: const Home(),
    );
  }
}

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  DateTime _now = DateTime.now();
  DateTime? _scheduled;
  Timer? _timer;
  bool _onAlarmPage = false;

  @override
  void initState() {
    super.initState();
    _loadScheduled();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadScheduled() async {
    final t = await AlarmService.instance.scheduledTime;
    if (mounted) setState(() => _scheduled = t);
  }

  Future<void> _tick() async {
    if (mounted) setState(() => _now = DateTime.now());
    if (_onAlarmPage) return;
    bool ringing;
    try {
      ringing = await AlarmService.instance.checkAndStartRinging();
    } catch (_) {
      return;
    }
    if (ringing && mounted && !_onAlarmPage) {
      _openAlarmPage();
    }
  }

  Future<void> _openAlarmPage() async {
    _onAlarmPage = true;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AlarmPage()),
    );
    _onAlarmPage = false;
    await _loadScheduled();
  }

  Future<void> _pickTime() async {
    final initial =
        _scheduled != null ? TimeOfDay.fromDateTime(_scheduled!) : TimeOfDay.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      helpText: 'アラーム時刻を選択',
    );
    if (picked == null || !mounted) return;
    final scheduled = await AlarmService.instance.schedule(picked);
    if (!mounted) return;
    setState(() => _scheduled = scheduled);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            '${_dateLabel(scheduled)} ${DateFormat('HH:mm').format(scheduled)} にセットしました'),
      ),
    );
  }

  Future<void> _cancelAlarm() async {
    await AlarmService.instance.cancel();
    if (!mounted) return;
    setState(() => _scheduled = null);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('アラームを解除しました')),
    );
  }

  Future<void> _testAlarm() async {
    await AlarmService.instance.startTestRinging();
    if (mounted) _openAlarmPage();
  }

  String _dateLabel(DateTime d) {
    const weekdays = ['月', '火', '水', '木', '金', '土', '日'];
    return '${d.month}月${d.day}日 (${weekdays[d.weekday - 1]})';
  }

  String _remainingLabel() {
    if (_scheduled == null) return '';
    final diff = _scheduled!.difference(_now);
    if (diff.isNegative) return 'まもなく鳴ります';
    final h = diff.inHours;
    final m = diff.inMinutes % 60;
    return h > 0 ? 'あと$h時間$m分' : 'あと$m分';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('絶対アラーム',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: '設定',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingPage()),
            ),
          ),
        ],
      ),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1B1A33), Color(0xFF0E0E1A)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 2),
              Text(
                _dateLabel(_now),
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.white.withOpacity(0.7),
                  letterSpacing: 1,
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    DateFormat('HH:mm').format(_now),
                    style: const TextStyle(
                      fontSize: 84,
                      fontWeight: FontWeight.w200,
                      color: Colors.white,
                      letterSpacing: 2,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text(
                    DateFormat(':ss').format(_now),
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w300,
                      color: Colors.white.withOpacity(0.6),
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              const Spacer(),
              _alarmCard(context),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: FilledButton.icon(
                  onPressed: _pickTime,
                  icon: const Icon(Icons.alarm_add),
                  label: Text(_scheduled == null ? 'アラームをセット' : '時刻を変更'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    textStyle: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18)),
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _testAlarm,
                icon: const Icon(Icons.notifications_active_outlined, size: 18),
                label: const Text('アラームをテスト'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white.withOpacity(0.5),
                ),
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }

  Widget _alarmCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white12),
      ),
      child: _scheduled == null
          ? Row(
              children: [
                Icon(Icons.alarm_off,
                    color: Colors.white.withOpacity(0.4), size: 28),
                const SizedBox(width: 12),
                Text(
                  'アラームは未設定です',
                  style: TextStyle(
                      fontSize: 16, color: Colors.white.withOpacity(0.6)),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.alarm, color: scheme.primary, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      '次のアラーム',
                      style: TextStyle(
                          fontSize: 14, color: Colors.white.withOpacity(0.7)),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      color: Colors.white.withOpacity(0.5),
                      tooltip: 'アラームを解除',
                      onPressed: _cancelAlarm,
                    ),
                  ],
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      DateFormat('HH:mm').format(_scheduled!),
                      style: const TextStyle(
                        fontSize: 44,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${_dateLabel(_scheduled!)}・${_remainingLabel()}',
                      style: TextStyle(
                          fontSize: 14, color: Colors.white.withOpacity(0.6)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.psychology_outlined,
                        size: 18, color: scheme.tertiary),
                    const SizedBox(width: 8),
                    Text(
                      '問題に正解するまで止まりません',
                      style: TextStyle(
                          fontSize: 13, color: Colors.white.withOpacity(0.7)),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}
