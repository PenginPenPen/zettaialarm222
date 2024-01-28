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
final FlutterLocalNotificationsPlugin notificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ja');
  await loadAudio();
  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();
  flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
  runApp(const MyApp());
}

Future<void> loadAudio() async {
  try {
    await player.setAsset('assets/audio/test_audio.mp3');
  } catch (e) {
    debugPrint('音声ファイルの読み込みに失敗しました: $e');
  }
}

Future<void> playAlarm() async {
  if (player.processingState == ProcessingState.completed) {
    await loadAudio();
  }
  await player.play();
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

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
  bool alarmRunning = false;

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
    notificationsPlugin.initialize(initializationSettings);
  }

  void _updateTime(Timer timer) {
    setState(() {
      nowTime = DateTime.now();
      debugPrint('アラームステータス$alarmRunning');
      if (alarmRunning) {
        debugPrint('アラーム作動中');
      }
    });
  }

  @override
  void dispose() {
    timer.cancel();
    player.dispose();
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
                  MaterialPageRoute(
                    builder: (context) => AlarmPage(alarmRunning: alarmRunning),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _onTimeSelected(TimeOfDay time) async {
    setState(() {
      selectedTime = time;
    });
    final now = DateTime.now();
    final scheduledTime = DateTime(
      now.year, now.month, now.day, selectedTime.hour, selectedTime.minute);
    final int id = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await AndroidAlarmManager.oneShotAt(
      scheduledTime,
      id,
      onAlarm,
      alarmClock: true,
      allowWhileIdle: true,
      wakeup: true,
      exact: true,
    );
  }
}

Future<void> showNotification() async {
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

  await notificationsPlugin.show(
    0,
    'アラーム通知',
    'アラームが作動しました',
    platformChannelSpecifics,
  );
}

@pragma('vm:entry-point')
void onAlarm() async {
  debugPrint('アラーム作動');
  await showNotification();
  await playAlarm();
  // bool alarm_running = true;
}