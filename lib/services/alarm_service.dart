import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// アラームの予約・鳴動・停止を一手に引き受けるサービス。
///
/// - Android: AndroidAlarmManagerでバックグラウンド発火し、別isolateで
///   フルスクリーン通知+ループ再生。フォアグラウンド側とはIsolateNameServerで連携。
/// - iOS: バックグラウンドでの任意コード実行ができないため、予約時刻に
///   通知を1分間隔で5回出し、アプリを開いた時点で鳴動を開始する。
class AlarmService {
  AlarmService._();
  static final AlarmService instance = AlarmService._();

  static const alarmId = 42;
  static const _stopPortName = 'zettaialarm_stop_port';
  static const prefScheduledEpoch = 'alarm_scheduled_epoch';
  static const prefRinging = 'alarm_ringing';

  final AudioPlayer _player = AudioPlayer();
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _foregroundPlaying = false;

  /// アプリ起動時に1回呼ぶ。プラグインが無い環境(テスト等)でも落ちない。
  Future<void> init() async {
    try {
      tzdata.initializeTimeZones();
      const initSettings = InitializationSettings(
        android: AndroidInitializationSettings('icon'),
        iOS: DarwinInitializationSettings(),
      );
      await _notifications.initialize(initSettings);
      if (Platform.isAndroid) {
        await AndroidAlarmManager.initialize();
        await _notifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
      } else if (Platform.isIOS) {
        await _notifications
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(alert: true, sound: true, badge: false);
      }
    } catch (e) {
      debugPrint('アラームサービスの初期化に失敗: $e');
    }
  }

  /// 予約済みのアラーム時刻。未設定ならnull。
  Future<DateTime?> get scheduledTime async {
    final prefs = await SharedPreferences.getInstance();
    final epoch = prefs.getInt(prefScheduledEpoch);
    return epoch == null ? null : DateTime.fromMillisecondsSinceEpoch(epoch);
  }

  /// 指定時刻にアラームを予約する。過去の時刻は自動的に翌日として扱う。
  Future<DateTime> schedule(TimeOfDay time) async {
    await cancel();
    final now = DateTime.now();
    var scheduled =
        DateTime(now.year, now.month, now.day, time.hour, time.minute);
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(prefScheduledEpoch, scheduled.millisecondsSinceEpoch);
    await prefs.setBool(prefRinging, false);

    try {
      if (Platform.isAndroid) {
        await AndroidAlarmManager.oneShotAt(
          scheduled,
          alarmId,
          alarmCallback,
          alarmClock: true,
          allowWhileIdle: true,
          wakeup: true,
          exact: true,
          rescheduleOnReboot: true,
        );
      } else if (Platform.isIOS) {
        await _scheduleIosNotifications(scheduled);
      }
    } catch (e) {
      debugPrint('アラーム予約に失敗: $e');
    }
    return scheduled;
  }

  /// iOSはバックグラウンドで音を鳴らし続けられないので、
  /// 1分間隔の通知5連発でユーザーにアプリを開かせる。
  Future<void> _scheduleIosNotifications(DateTime scheduled) async {
    const details = NotificationDetails(
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      ),
    );
    final delay = scheduled.difference(DateTime.now());
    for (var i = 0; i < 5; i++) {
      await _notifications.zonedSchedule(
        alarmId + i,
        '絶対アラーム',
        '起きる時間です!アプリを開いて問題に正解すると止まります',
        tz.TZDateTime.now(tz.local).add(delay + Duration(minutes: i)),
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  /// 予約と通知をすべて取り消す。
  Future<void> cancel() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(prefScheduledEpoch);
    await prefs.setBool(prefRinging, false);
    try {
      if (Platform.isAndroid) {
        await AndroidAlarmManager.cancel(alarmId);
      }
      await _notifications.cancelAll();
    } catch (e) {
      debugPrint('アラーム解除に失敗: $e');
    }
  }

  /// 鳴動すべき状態かを判定し、必要ならフォアグラウンドで鳴らし始める。
  /// ホーム画面の周期タイマーから毎秒呼ばれる。
  Future<bool> checkAndStartRinging() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      // バックグラウンドisolateが立てたフラグを読むためリロードが必要
      await prefs.reload();
    } catch (_) {}
    var ringing = prefs.getBool(prefRinging) ?? false;
    final epoch = prefs.getInt(prefScheduledEpoch);
    if (!ringing &&
        epoch != null &&
        DateTime.now().millisecondsSinceEpoch >= epoch) {
      // アプリを開いたまま時刻を迎えた場合(iOSは常にこの経路)
      ringing = true;
      await prefs.setBool(prefRinging, true);
    }
    if (ringing) {
      await startRinging();
    }
    return ringing;
  }

  /// フォアグラウンドでアラーム音のループ再生を開始する。
  Future<void> startRinging() async {
    if (_foregroundPlaying) return;
    _foregroundPlaying = true;
    // Androidのバックグラウンドisolateで鳴っている音を止めて引き継ぐ
    IsolateNameServer.lookupPortByName(_stopPortName)?.send('stop');
    try {
      await _player.setAsset('assets/audio/alarm1.wav');
      await _player.setLoopMode(LoopMode.one);
      unawaited(_player.play());
    } catch (e) {
      debugPrint('アラーム音の再生に失敗: $e');
    }
  }

  /// クイズ正解時に呼ぶ。音・通知・予約をすべて止める。
  Future<void> stopRinging() async {
    _foregroundPlaying = false;
    try {
      await _player.stop();
    } catch (_) {}
    IsolateNameServer.lookupPortByName(_stopPortName)?.send('stop');
    await cancel();
  }

  /// デバッグ・動作確認用: いますぐ鳴動状態にする。
  Future<void> startTestRinging() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefRinging, true);
    await startRinging();
  }
}

/// AndroidAlarmManagerがバックグラウンドで呼ぶエントリポイント。
///
/// メインとは別のisolateで実行されるため、通知プラグインと音声プレイヤーは
/// ここで改めて初期化する必要がある(メインisolateの初期化は引き継がれない)。
@pragma('vm:entry-point')
Future<void> alarmCallback() async {
  DartPluginRegistrant.ensureInitialized();
  debugPrint('アラーム発火(バックグラウンド)');

  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(AlarmService.prefRinging, true);

  // フォアグラウンド側から音を止められるように停止用ポートを公開する
  final receivePort = ReceivePort();
  IsolateNameServer.removePortNameMapping(AlarmService._stopPortName);
  IsolateNameServer.registerPortWithName(
      receivePort.sendPort, AlarmService._stopPortName);

  final player = AudioPlayer();
  receivePort.listen((message) {
    if (message == 'stop') {
      player.stop();
    }
  });

  try {
    final notifications = FlutterLocalNotificationsPlugin();
    await notifications.initialize(const InitializationSettings(
        android: AndroidInitializationSettings('icon')));
    await notifications.show(
      AlarmService.alarmId,
      '絶対アラーム',
      '起きる時間です!問題に正解すると止まります',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'alarm_channel_id',
          'アラーム',
          channelDescription: 'アラーム発動時の通知',
          importance: Importance.max,
          priority: Priority.high,
          category: AndroidNotificationCategory.alarm,
          fullScreenIntent: true,
          ongoing: true,
          autoCancel: false,
          playSound: false,
        ),
      ),
    );
  } catch (e) {
    debugPrint('通知の表示に失敗: $e');
  }

  try {
    await player.setAsset('assets/audio/alarm1.wav');
    await player.setLoopMode(LoopMode.one);
    // 再生し続けている間はこのawaitが返らず、その間wake lockが維持される
    await player.play();
  } catch (e) {
    debugPrint('アラーム音の再生に失敗: $e');
  }
}
