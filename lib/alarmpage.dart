import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:zettaialarm222/main.dart';

const token = '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';

Future<String> quizGeneration() async {
  debugPrint('クイズ生成');
  final url = Uri.parse('https://api.openai.com/v1/engines/gpt-3.5-turbo-instruct/completions');
  final headers = {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token'
  };
  final body = json.encode({
    'prompt': 'Create a quiz question about general knowledge',
    'max_tokens': 100,
    'temperature': 0.7,
    'top_p': 1,
    'frequency_penalty': 0,
    'presence_penalty': 0
  });

  try {
    debugPrint('通信開始');
    final response = await http.post(url, headers: headers, body: body);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final generatedQuiz = data['choices'][0]['text'].trim();
      debugPrint('生成されたクイズ: $generatedQuiz'); // Output the generated quiz
      return generatedQuiz;
    } else {
      debugPrint('Error generating quiz: ${response.body}');
      return 'Error generating quiz.';
    }
  } catch (e) {
    debugPrint('Error generating quiz: $e');
    return 'Error generating quiz.';
  }
}

Future<void> stopAlarm() async {
  await quizGeneration();
  debugPrint('アラーム停止');
  AndroidAlarmManager.cancel(0);
  player.stop();
}

class AlarmPage extends StatelessWidget {
  final bool alarmRunning;
  const AlarmPage({Key? key, required this.alarmRunning}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'アラームページ',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton(
            child: const Text('アラーム停止ボタン(デバッグ)'),
            onPressed: () {
              stopAlarm();
            },
          ),
          FutureBuilder<String>(
            future: quizGeneration(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return CircularProgressIndicator(); // Show loading indicator while fetching quiz
              } else if (snapshot.hasError) {
                return Text('Error: ${snapshot.error}');
              } else {
                return Text(snapshot.data ?? ''); // Display fetched quiz
              }
            },
          ),
        ],
      ),
    );
  }
}