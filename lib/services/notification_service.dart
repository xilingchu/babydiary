import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> init() async {
    if (kIsWeb) return;
    try {
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      await _plugin.initialize(
        settings: const InitializationSettings(android: androidInit),
      );
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestNotificationsPermission();
      _initialized = true;
    } catch (_) {}
  }

  static Future<void> showNewContent({
    required String author,
    required int diaryCount,
    required int milestoneCount,
  }) async {
    if (!_initialized || (diaryCount == 0 && milestoneCount == 0)) return;

    final parts = <String>[];
    if (diaryCount > 0) parts.add('$diaryCount条日记');
    if (milestoneCount > 0) parts.add('$milestoneCount个里程碑');

    const details = AndroidNotificationDetails(
      'baby_diary_new_content',
      '新内容提醒',
      channelDescription: '当对方发布新日记或里程碑时通知您',
      importance: Importance.high,
      priority: Priority.high,
    );
    await _plugin.show(
      id: 42,
      title: author.isNotEmpty ? '$author发布了新内容' : '有新内容',
      body: parts.join('，'),
      notificationDetails: const NotificationDetails(android: details),
    );
  }
}
