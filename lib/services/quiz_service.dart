import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// 4択クイズ1問分のデータ。
class Quiz {
  final String question;
  final List<String> choices;
  final int correctIndex;

  const Quiz({
    required this.question,
    required this.choices,
    required this.correctIndex,
  });
}

/// クイズの生成を担当するサービス。
///
/// OpenAI APIキーが設定されていればAIがクイズを生成し、
/// 未設定・通信失敗時はローカルの計算問題にフォールバックする。
/// フォールバックがないとオフライン時にアラームを止められなくなるため必須。
class QuizService {
  QuizService._();
  static final QuizService instance = QuizService._();

  static const _apiKeyPref = 'openai_api_key';
  static const _endpoint = 'https://api.openai.com/v1/chat/completions';
  static const _genres = ['一般常識', '雑学', '地理', '歴史', '理科', 'ことわざ', '計算'];

  Future<String> loadApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_apiKeyPref) ?? '';
  }

  Future<void> saveApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiKeyPref, key.trim());
  }

  Future<Quiz> generate() async {
    final apiKey = await loadApiKey();
    if (apiKey.isEmpty) {
      return _mathQuiz();
    }
    try {
      return await _generateWithOpenAi(apiKey);
    } catch (e) {
      debugPrint('AIクイズの生成に失敗したため計算問題に切り替えます: $e');
      return _mathQuiz();
    }
  }

  Future<Quiz> _generateWithOpenAi(String apiKey) async {
    final genre = _genres[Random().nextInt(_genres.length)];
    final response = await http
        .post(
          Uri.parse(_endpoint),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $apiKey',
          },
          body: json.encode({
            'model': 'gpt-4o-mini',
            'temperature': 1.0,
            'response_format': {'type': 'json_object'},
            'messages': [
              {
                'role': 'system',
                'content': 'あなたはアラームアプリの出題者です。寝起きのユーザーの頭を起こすための4択クイズを日本語で1問作ってください。'
                    '必ず次の形式のJSONだけを返してください: '
                    '{"question": "問題文", "choices": ["選択肢1", "選択肢2", "選択肢3", "選択肢4"], "answer_index": 0}',
              },
              {'role': 'user', 'content': '$genreのクイズを1問お願いします。'},
            ],
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('OpenAI APIエラー: ${response.statusCode} ${response.body}');
    }
    final content = json.decode(utf8.decode(response.bodyBytes))['choices'][0]
        ['message']['content'] as String;
    final data = json.decode(content) as Map<String, dynamic>;
    final choices = (data['choices'] as List).map((e) => '$e').toList();
    final answerIndex = data['answer_index'] as int;
    if (choices.length < 2 || answerIndex < 0 || answerIndex >= choices.length) {
      throw Exception('クイズの形式が不正です: $content');
    }
    return Quiz(
      question: '${data['question']}',
      choices: choices,
      correctIndex: answerIndex,
    );
  }

  /// オフラインでも必ず解ける計算問題。
  Quiz _mathQuiz() {
    final random = Random();
    final a = random.nextInt(37) + 13; // 13〜49
    final b = random.nextInt(7) + 3; // 3〜9
    final c = random.nextInt(80) + 10; // 10〜89
    final answer = a * b + c;
    final choices = <int>{answer};
    while (choices.length < 4) {
      choices.add(answer + random.nextInt(21) - 10);
    }
    final list = choices.toList()..shuffle();
    return Quiz(
      question: '$a × $b + $c = ?',
      choices: list.map((e) => '$e').toList(),
      correctIndex: list.indexOf(answer),
    );
  }
}
