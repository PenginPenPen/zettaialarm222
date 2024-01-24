import 'package:flutter/material.dart';
import 'package:chat_gpt_sdk/chat_gpt_sdk.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:zettaialarm222/main.dart';
// import 'package:flutter_dotenv/flutter_dotenv.dart';

final token = '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';
final openAI = OpenAI.instance.build(token: token,baseOption: HttpSetup(receiveTimeout: const Duration(seconds: 5)),enableLog: true);


Future<void> qiuz_generation() async { //chatgptにクイズを生成させる
}

Future<void> stopAlarm()async{
  qiuz_generation();
  debugPrint('アラーム停止');
  AndroidAlarmManager.channel;
  // player.stop();
  // alarm_runing = false;
}


class AlarmPage extends StatelessWidget {
  const AlarmPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(
        'アラームページ',
        style: TextStyle(color: Colors.white)
      )
      ),
      body: Column(
        children: [

          ElevatedButton(
              child: const Text('アラーム停止ボタン(デバッグ)'),
              onPressed: () {
                stopAlarm();
              })

        ],
      ),
    );
  }
}