import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

const kBgTaskName = 'baby_diary_bg_sync';
const _kLastBgCheck = 'last_bg_check_ms';
const _kServerUrl = 'sync_server_url';
const _kCurrentAuthor = 'current_author';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, _) async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      await _checkForNewContent();
    } catch (_) {}
    return true;
  });
}

Future<void> _checkForNewContent() async {
  final prefs = await SharedPreferences.getInstance();
  final serverUrl = prefs.getString(_kServerUrl);
  if (serverUrl == null || serverUrl.isEmpty) return;

  final lastCheckMs = prefs.getInt(_kLastBgCheck);
  final now = DateTime.now();
  await prefs.setInt(_kLastBgCheck, now.millisecondsSinceEpoch);

  // 首次运行只记录时间，不通知（避免把所有历史内容当新内容）
  if (lastCheckMs == null) return;

  final lastCheck = DateTime.fromMillisecondsSinceEpoch(lastCheckMs).toUtc();
  final currentAuthor = prefs.getString(_kCurrentAuthor) ?? '';
  final base = Uri.parse(serverUrl);

  int diaryCount = 0;
  int milestoneCount = 0;
  String otherAuthor = '';

  Future<List<dynamic>> fetchItems(String collection) async {
    final uri = Uri(
      scheme: base.scheme,
      host: base.host,
      port: base.port,
      path: '/api/collections/$collection/records',
      queryParameters: {
        'filter': 'created > "${lastCheck.toIso8601String()}" && deleted_at = ""',
        'perPage': '50',
      },
    );
    final resp = await http.get(uri).timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) return [];
    return (jsonDecode(resp.body)['items'] as List? ?? []);
  }

  try {
    for (final item in await fetchItems('diary_entries')) {
      final author = item['author'] as String? ?? '';
      if (author.isNotEmpty && author != currentAuthor) {
        diaryCount++;
        if (otherAuthor.isEmpty) otherAuthor = author;
      }
    }
  } catch (_) {}

  try {
    for (final item in await fetchItems('milestones')) {
      final author = item['author'] as String? ?? '';
      if (author.isNotEmpty && author != currentAuthor) {
        milestoneCount++;
        if (otherAuthor.isEmpty) otherAuthor = author;
      }
    }
  } catch (_) {}

  if (diaryCount == 0 && milestoneCount == 0) return;

  final plugin = FlutterLocalNotificationsPlugin();
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  await plugin.initialize(
    settings: const InitializationSettings(android: androidInit),
  );

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
  await plugin.show(
    id: 43,
    title: otherAuthor.isNotEmpty ? '$otherAuthor发布了新内容' : '有新内容',
    body: parts.join('，'),
    notificationDetails: const NotificationDetails(android: details),
  );
}
