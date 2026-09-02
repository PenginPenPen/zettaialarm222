import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zettaialarm222/main.dart';

void main() {
  testWidgets('ホーム画面に時計とアラームカードが表示される', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const MyApp());

    expect(find.text('絶対アラーム'), findsOneWidget);
    expect(find.text('アラームは未設定です'), findsOneWidget);
    expect(find.text('アラームをセット'), findsOneWidget);

    // ホーム画面の周期タイマーを破棄してからテストを終える
    await tester.pumpWidget(const SizedBox());
  });
}
