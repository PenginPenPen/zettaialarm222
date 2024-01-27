import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:just_audio/just_audio.dart';
import 'package:zettaialarm222/alarmpage.dart';

final player = AudioPlayer();

void main() async {
  final FlutterLocalNotificationsPlugin notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ja');
  loadAudio();
  runApp(const MyApp());
}

Future<void> loadAudio() async {
  await player.setAsset('assets/audio/outro.mp3');
  debugPrint('音声ファイル読み込み完了');
}

Future<void> playAlarm() async {
  if (player.processingState == ProcessingState.completed) {
    await loadAudio();
  }
  await player.play();
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'zettaialarm',
      theme: ThemeData(
        appBarTheme: const AppBarTheme(color: Color.fromARGB(255, 0, 0, 0)),
      ),
      home: const Home(),
    );
  }
}

class Home extends StatefulWidget {
  const Home({Key? key}) : super(key: key);

  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  late DateTime nowTime;
  late Timer timer;
  late TimeOfDay selectedTime;
  final FlutterLocalNotificationsPlugin flnp = FlutterLocalNotificationsPlugin();
  bool alarm_running = false;

  @override
  void initState() {
    super.initState();
    nowTime = DateTime.now();
    selectedTime = TimeOfDay.now();
    timer = Timer.periodic(const Duration(seconds: 1), _updateTime);

    final AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('logo');
    final InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    flnp.initialize(initializationSettings);
    initializeDateFormatting('ja');
  }

  void _updateTime(Timer timer) {
    setState(() {
      nowTime = DateTime.now();
      debugPrint('毎秒$alarm_running');
      if (alarm_running) {
        debugPrint('アラーム作動中');
      }
    });
  }

  Future<void> _showNotification() async {
    debugPrint('通知');
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'alarm_channel_id',
      'alarm_channel_name',
      importance: Importance.max,
      priority: Priority.high,
      channelShowBadge: true,
    );
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    // flutterLocalNotificationsPlugin の初期化
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    await flutterLocalNotificationsPlugin.show(
      0, // 通知ID
      'アラーム通知', // 通知タイトル
      'アラームが作動しました', // 通知本文
      platformChannelSpecifics,
    );
  }

  void _onTimeSelected(TimeOfDay time) {

    final now = DateTime.now();
    final scheduledTime = DateTime(now.year, now.month, now.day, selectedTime.hour, selectedTime.minute);
    final int id = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    debugPrint('設定された時間$scheduledTime.String');
    AndroidAlarmManager.oneShotAt(
      scheduledTime,
      id,
      onAlarm,
      alarmClock: true,
      allowWhileIdle: true,
      wakeup: true,
      exact: true,
    );
  }
  void onAlarm() async {
    setState(() {
      alarm_running = true;
    });
    debugPrint('アラーム作動');
    await _showNotification();
    playAlarm();
    debugPrint('作動直後$alarm_running');
  }


  @override
  void dispose() {
    timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('現在時刻', style: TextStyle(color: Colors.white)),
      ),
      body: Center(
        child: Column(
          children: [
            Text(
              DateFormat('HH:mm:ss').format(nowTime),
              style: const TextStyle(fontSize: 50),
            ),
            Text(
              '選択された時間: ${selectedTime.format(context)}',
              style: const TextStyle(fontSize: 20),
            ),
            IconButton(
              onPressed: () async {
                final TimeOfDay? newTime = await showTimePicker(
                  context: context,
                  initialTime: selectedTime,
                );
                if (newTime != null) {
                  _onTimeSelected(newTime);
                }
              },
              icon: const Icon(Icons.alarm_add),
            ),
            ElevatedButton(
              child: const Text('画面遷移(デバッグ)'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AlarmPage()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
