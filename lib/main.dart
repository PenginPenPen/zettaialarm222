import 'package:flutter/material.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:just_audio/just_audio.dart';

final player = AudioPlayer();
void main() async{
  initializeDateFormatting('ja');
  WidgetsFlutterBinding.ensureInitialized();
  loadAudio();
  runApp(const MyApp());
}

Future<void> loadAudio() async{ //アプリ側からリンクでアラーム音を指定できるようにする。
  await player.setAsset('assets/audio/outro.mp3');
  debugPrint('音声ファイル読み込み完了');
}

Future<void> playalarm() async{
  if(player.processingState == ProcessingState.completed) {
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
  late DateTime nowTime;
  late Timer timer;
  late TimeOfDay selectedTime;
  final FlutterLocalNotificationsPlugin flnp = FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    nowTime = DateTime.now();
    selectedTime = TimeOfDay.now();
    timer = Timer.periodic(const Duration(seconds: 1), _onTimer);

    final AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('logo');
    final InitializationSettings initializationSettings =
      InitializationSettings(android: initializationSettingsAndroid);
    flnp.initialize(initializationSettings);
  }

  void _onTimer(Timer timer) {
    setState(() {
      nowTime = DateTime.now();
    });
  }

  @override
  void dispose() {
    timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'zettaialarm',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: Home(nowTime: nowTime, selectedTime: selectedTime, onTimeSelected: _onTimeSelected),
    );
  }

  void _onTimeSelected(TimeOfDay time) {
    setState(() {
      selectedTime = time;
    });

    final now = DateTime.now();
    final scheduledTime = DateTime(now.year, now.month, now.day, selectedTime.hour, selectedTime.minute);
    final int id = DateTime.now().millisecondsSinceEpoch ~/ 1000;

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
}

void onAlarm() async {
  debugPrint('アラーム作動');
  playalarm();
}

class Home extends StatelessWidget {
  final DateTime nowTime;
  final TimeOfDay selectedTime;
  final Function(TimeOfDay) onTimeSelected;

  Home({required this.nowTime, required this.selectedTime, required this.onTimeSelected, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('現在時刻'),
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
                  onTimeSelected(newTime);
                }
              },
              icon: const Icon(Icons.alarm_add),
            ),
          ],
        ),
      ),
    );
  }
}