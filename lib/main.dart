import 'package:flutter/material.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:zettaialarm222/alarmpage.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';

void main() {
  runApp(const MyApp());
  initializeDateFormatting('ja');
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late DateTime nowTime;
  late Timer timer;

  @override
  void initState() {
    super.initState();
    nowTime = DateTime.now();
    timer = Timer.periodic(const Duration(seconds: 1), _onTimer);
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
      home:Home(nowTime: nowTime)
    );
  }
}
  void onAlarm() async {
    print('アラーム発生！');
  }

class Home extends StatelessWidget {
  final DateTime nowTime;
  Home({required this.nowTime, Key? key}) : super(key: key);
  TimeOfDay selectedtime= TimeOfDay.now();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: (Text('現在時刻')),
      ),
      body: Center(
        child: Column(
          children: [
            Text(
              DateFormat('HH:mm:ss').format(nowTime),
              style: const TextStyle(fontSize: 50),
            ),
            IconButton(
              onPressed: () async {
                final TimeOfDay? timeOfDay = await showTimePicker(
                  context: context,
                  initialTime: selectedtime,
                  initialEntryMode: TimePickerEntryMode.dial
                  );
                if(timeOfDay != null){
                  selectedtime=timeOfDay; //selectedtimeに時間を設定
                  print('設定した時間${selectedtime}');
                  final now = DateTime.now();
                  final scheduledTime = DateTime(now.year, now.month, now.day, selectedtime.hour, selectedtime.minute);
                  final int id = 1;

                  await AndroidAlarmManager.initialize();
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
              },
              icon: Icon(Icons.add),
              color: Colors.black,
              iconSize: 30,
            ),
            IconButton(onPressed: (){
              Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => AlarmPage()),
                );
            }, icon: Icon(Icons.alarm))
          ],
        ),
      ),
    );
  }
}

