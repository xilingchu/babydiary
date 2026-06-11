import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 默认记录人颜色
const defaultAuthorColors = {
  '爸爸': 0xFF1976D2, // 蓝色
  '妈妈': 0xFFE91E63, // 粉色
};

class AppSettings {
  final String babyName;
  final DateTime? babyBirthday;
  final double? babyHeight;
  final double? babyWeight;
  final String currentAuthor;
  final List<String> authors;
  final Map<String, int> authorColors; // author -> color value
  final DateTime? profileUpdatedAt;
  final bool loaded;

  const AppSettings({
    this.babyName = '',
    this.babyBirthday,
    this.babyHeight,
    this.babyWeight,
    this.currentAuthor = '',
    this.authors = const ['爸爸', '妈妈'],
    this.authorColors = const {},
    this.profileUpdatedAt,
    this.loaded = false,
  });

  AppSettings copyWith({
    String? babyName,
    DateTime? babyBirthday,
    double? babyHeight,
    double? babyWeight,
    String? currentAuthor,
    List<String>? authors,
    Map<String, int>? authorColors,
    DateTime? profileUpdatedAt,
    bool? loaded,
  }) =>
      AppSettings(
        babyName: babyName ?? this.babyName,
        babyBirthday: babyBirthday ?? this.babyBirthday,
        babyHeight: babyHeight ?? this.babyHeight,
        babyWeight: babyWeight ?? this.babyWeight,
        currentAuthor: currentAuthor ?? this.currentAuthor,
        authors: authors ?? this.authors,
        authorColors: authorColors ?? this.authorColors,
        profileUpdatedAt: profileUpdatedAt ?? this.profileUpdatedAt,
        loaded: loaded ?? this.loaded,
      );

  Color colorFor(String author) {
    final value = authorColors[author] ?? defaultAuthorColors[author];
    return value != null ? Color(value) : Colors.grey;
  }

  String get babyAge {
    if (babyBirthday == null) return '';
    final now = DateTime.now();
    final months = (now.year - babyBirthday!.year) * 12 + now.month - babyBirthday!.month;
    if (months < 1) {
      final days = now.difference(babyBirthday!).inDays;
      return '$days天';
    }
    if (months < 24) return '$months个月';
    final years = months ~/ 12;
    final rem = months % 12;
    return rem == 0 ? '$years岁' : '$years岁$rem个月';
  }
}

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier() : super(const AppSettings()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final birthdayMs = prefs.getInt('baby_birthday');
    final authorsRaw = prefs.getStringList('authors');
    final colorsRaw = prefs.getStringList('author_colors') ?? [];
    final authorColors = <String, int>{};
    for (final entry in colorsRaw) {
      final parts = entry.split(':');
      if (parts.length == 2) {
        authorColors[parts[0]] = int.tryParse(parts[1]) ?? 0;
      }
    }
    final profileUpdatedMs = prefs.getInt('profile_updated_at');
    state = AppSettings(
      babyName: prefs.getString('baby_name') ?? '',
      babyBirthday: birthdayMs != null ? DateTime.fromMillisecondsSinceEpoch(birthdayMs) : null,
      babyHeight: prefs.getDouble('baby_height'),
      babyWeight: prefs.getDouble('baby_weight'),
      currentAuthor: prefs.getString('current_author') ?? '',
      authors: authorsRaw ?? ['爸爸', '妈妈'],
      authorColors: authorColors,
      profileUpdatedAt: profileUpdatedMs != null ? DateTime.fromMillisecondsSinceEpoch(profileUpdatedMs) : null,
      loaded: true,
    );
  }

  Future<void> save({
    String? babyName,
    DateTime? babyBirthday,
    double? babyHeight,
    double? babyWeight,
    String? currentAuthor,
    List<String>? authors,
    Map<String, int>? authorColors,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    // 档案字段有变化时更新时间戳
    final profileChanged = babyName != null || babyBirthday != null || babyHeight != null || babyWeight != null;

    if (babyName != null) await prefs.setString('baby_name', babyName);
    if (babyBirthday != null) await prefs.setInt('baby_birthday', babyBirthday.millisecondsSinceEpoch);
    if (babyHeight != null) await prefs.setDouble('baby_height', babyHeight);
    if (babyWeight != null) await prefs.setDouble('baby_weight', babyWeight);
    if (currentAuthor != null) await prefs.setString('current_author', currentAuthor);
    if (authors != null) await prefs.setStringList('authors', authors);
    if (authorColors != null) {
      await prefs.setStringList('author_colors',
          authorColors.entries.map((e) => '${e.key}:${e.value}').toList());
    }
    if (profileChanged) {
      await prefs.setInt('profile_updated_at', now.millisecondsSinceEpoch);
    }

    state = state.copyWith(
      babyName: babyName,
      babyBirthday: babyBirthday,
      babyHeight: babyHeight,
      babyWeight: babyWeight,
      currentAuthor: currentAuthor,
      authors: authors,
      authorColors: authorColors,
      profileUpdatedAt: profileChanged ? now : null,
    );
  }

  // 从远端同步覆盖本地档案（仅当远端更新时间更新）
  Future<void> applyRemoteProfile({
    required String name,
    required int? birthdayMs,
    required double? height,
    required double? weight,
    required DateTime remoteUpdatedAt,
  }) async {
    final local = state.profileUpdatedAt;
    if (local != null && !local.isBefore(remoteUpdatedAt)) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('baby_name', name);
    if (birthdayMs != null) await prefs.setInt('baby_birthday', birthdayMs);
    if (height != null) await prefs.setDouble('baby_height', height);
    if (weight != null) await prefs.setDouble('baby_weight', weight);
    await prefs.setInt('profile_updated_at', remoteUpdatedAt.millisecondsSinceEpoch);

    state = state.copyWith(
      babyName: name,
      babyBirthday: birthdayMs != null ? DateTime.fromMillisecondsSinceEpoch(birthdayMs) : null,
      babyHeight: height,
      babyWeight: weight,
      profileUpdatedAt: remoteUpdatedAt,
    );
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier();
});
