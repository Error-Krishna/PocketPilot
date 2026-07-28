import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings =
        InitializationSettings(android: androidSettings);
    await _plugin.initialize(initSettings);

    // Android 13+ (API 33+) requires this runtime permission before any
    // notification — including the persistent daily-limit one — will
    // actually appear. Declaring POST_NOTIFICATIONS in the manifest alone
    // is not enough; without this call .show() silently does nothing.
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  static Future<void> showDailyLimitNotification({
    required double dailyLimit,
    required double spentToday,
    required double savedToday,
    bool isAwaitingFunds = false,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'daily_limit_channel',
      'Daily Limit',
      channelDescription: 'Shows your current daily spending limit',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
    );
    const details = NotificationDetails(android: androidDetails);

    if (isAwaitingFunds) {
      await _plugin.show(
        0,
        'Cycle complete',
        'Waiting for your next pocket money to start a new cycle.',
        details,
      );
      return;
    }

    final remaining = dailyLimit - spentToday;
    final status = remaining >= 0 ? '✅ Under limit' : '❌ Over limit';

    await _plugin.show(
      0,
      'Daily Limit: ₹${dailyLimit.toStringAsFixed(0)}',
      'Spent: ₹${spentToday.toStringAsFixed(0)} | Remaining: ₹${remaining.toStringAsFixed(0)} | $status',
      details,
    );
  }

  static Future<void> cancelDailyLimitNotification() async {
    await _plugin.cancel(0);
  }
}