import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../db/database.dart';
import '../providers/settings_provider.dart';
import 'package:drift/drift.dart';
import '../utils/sync_io.dart';
import 'notification_service.dart';

const _kServerUrl = 'sync_server_url';

enum SyncStatus { disconnected, connecting, connected, syncing, error }

class SyncState {
  final SyncStatus status;
  final String? serverUrl;
  final String? error;
  final DateTime? lastSync;

  const SyncState({
    this.status = SyncStatus.disconnected,
    this.serverUrl,
    this.error,
    this.lastSync,
  });

  SyncState copyWith({
    SyncStatus? status,
    String? serverUrl,
    String? error,
    DateTime? lastSync,
  }) =>
      SyncState(
        status: status ?? this.status,
        serverUrl: serverUrl ?? this.serverUrl,
        error: error ?? this.error,
        lastSync: lastSync ?? this.lastSync,
      );
}

class SyncService extends StateNotifier<SyncState> {
  final AppDatabase _db;
  final SettingsNotifier _settings;
  PocketBase? _pb;

  int _pendingDiaryCount = 0;
  int _pendingMilestoneCount = 0;
  String _pendingAuthor = '';

  SyncService(this._db, this._settings) : super(const SyncState()) {
    _autoConnect();
  }

  Future<void> _autoConnect() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString(_kServerUrl);
    if (url != null && url.isNotEmpty) {
      final ok = await connect(url);
      if (ok) await syncAll();
    }
  }

  Future<String> setupCollections(String url, String adminEmail, String adminPassword) async {
    try {
      final pb = PocketBase(url);
      await pb.collection('_superusers').authWithPassword(adminEmail, adminPassword);

      final existing = await pb.collections.getFullList();
      final existingNames = existing.map((c) => c.name).toSet();

      final collections = [
        {
          'name': 'diary_entries',
          'type': 'base',
          'fields': [
            {'name': 'local_id', 'type': 'text'},
            {'name': 'date', 'type': 'text', 'required': true},
            {'name': 'title', 'type': 'text'},
            {'name': 'content', 'type': 'text', 'required': true},
            {'name': 'mood', 'type': 'text'},
            {'name': 'author', 'type': 'text'},
            {'name': 'deleted_at', 'type': 'text'},
            {'name': 'created_at', 'type': 'text'},
            {'name': 'updated_at', 'type': 'text'},
          ],
        },
        {
          'name': 'diary_photos',
          'type': 'base',
          'fields': [
            {'name': 'local_id', 'type': 'text'},
            {'name': 'diary_id', 'type': 'text', 'required': true},
            {'name': 'photo', 'type': 'file', 'maxSelect': 1, 'maxSize': 52428800},
            {'name': 'caption', 'type': 'text'},
          ],
        },
        {
          'name': 'milestones',
          'type': 'base',
          'fields': [
            {'name': 'local_id', 'type': 'text'},
            {'name': 'date', 'type': 'text', 'required': true},
            {'name': 'title', 'type': 'text', 'required': true},
            {'name': 'description', 'type': 'text'},
            {'name': 'category', 'type': 'text'},
            {'name': 'author', 'type': 'text'},
            {'name': 'deleted_at', 'type': 'text'},
            {'name': 'photo', 'type': 'file', 'maxSelect': 1, 'maxSize': 52428800},
            {'name': 'created_at', 'type': 'text'},
            {'name': 'updated_at', 'type': 'text'},
          ],
        },
        {
          'name': 'comments',
          'type': 'base',
          'fields': [
            {'name': 'local_id', 'type': 'text'},
            {'name': 'parent_id', 'type': 'text', 'required': true},
            {'name': 'parent_type', 'type': 'text', 'required': true},
            {'name': 'content', 'type': 'text', 'required': true},
            {'name': 'author', 'type': 'text'},
            {'name': 'deleted_at', 'type': 'text'},
            {'name': 'created_at', 'type': 'text'},
          ],
        },
        {
          'name': 'baby_profile',
          'type': 'base',
          'fields': [
            {'name': 'baby_name', 'type': 'text'},
            {'name': 'birthday_ms', 'type': 'number'},
            {'name': 'height', 'type': 'number'},
            {'name': 'weight', 'type': 'number'},
            {'name': 'updated_at', 'type': 'text'},
          ],
        },
      ];

      int created = 0;
      int skipped = 0;
      for (final col in collections) {
        final name = col['name'] as String;
        if (existingNames.contains(name)) {
          skipped++;
        } else {
          await pb.collections.create(body: col);
          created++;
        }
      }

      // Migrate existing collections: add missing fields
      for (final colName in ['diary_entries', 'milestones']) {
        try {
          final colModel = await pb.collections.getFirstListItem('name="$colName"');
          final existingFieldNames = colModel.fields.map((f) => f.name).toSet();
          final missing = <Map<String, String>>[];
          if (!existingFieldNames.contains('author')) missing.add({'name': 'author', 'type': 'text'});
          if (!existingFieldNames.contains('deleted_at')) missing.add({'name': 'deleted_at', 'type': 'text'});
          if (missing.isNotEmpty) {
            final updatedFields = colModel.fields.map((f) => f.toJson()).toList();
            updatedFields.addAll(missing);
            await pb.collections.update(colModel.id, body: {'fields': updatedFields});
          }
        } catch (_) {}
      }

      // Migrate photo field maxSize to 50MB for diary_photos and milestones
      for (final colName in ['diary_photos', 'milestones']) {
        try {
          final colModel = await pb.collections.getFirstListItem('name="$colName"');
          final updatedFields = colModel.fields.map((f) {
            final json = f.toJson();
            if (f.name == 'photo' && (json['maxSize'] as num? ?? 0) < 52428800) {
              json['maxSize'] = 52428800;
            }
            return json;
          }).toList();
          await pb.collections.update(colModel.id, body: {'fields': updatedFields});
        } catch (_) {}
      }

      // Set all collections to allow API access without auth (家庭局域网模式)
      for (final col in collections) {
        final name = col['name'] as String;
        try {
          final colModel = await pb.collections.getFirstListItem('name="$name"');
          await pb.collections.update(colModel.id, body: {
            'listRule': '',
            'viewRule': '',
            'createRule': '',
            'updateRule': '',
            'deleteRule': '',
          });
        } catch (_) {}
      }

      return '完成：创建 $created 个集合，跳过 $skipped 个已存在的集合';
    } catch (e) {
      throw '初始化失败: $e';
    }
  }

  Future<bool> connect(String url) async {
    state = state.copyWith(status: SyncStatus.connecting, error: null);
    try {
      final pb = PocketBase(url);
      await pb.health.check();
      _pb = pb;
      state = state.copyWith(status: SyncStatus.connected, serverUrl: url);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kServerUrl, url);
      return true;
    } catch (e) {
      state = state.copyWith(
        status: SyncStatus.error,
        error: '无法连接到服务器: $e',
      );
      return false;
    }
  }

  Future<void> disconnect() async {
    _pb = null;
    state = state.copyWith(status: SyncStatus.disconnected, serverUrl: null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kServerUrl);
  }

  Future<void> syncAll() async {
    if (_pb == null) return;
    state = state.copyWith(status: SyncStatus.syncing);
    _pendingDiaryCount = 0;
    _pendingMilestoneCount = 0;
    _pendingAuthor = '';
    try {
      await _syncBabyProfile();
      await _syncDiaries();
      await _syncOrphanedPhotos();
      await _syncMilestones();
      await _pullRemoteMilestones();
      await _syncComments();
      state = state.copyWith(
        status: SyncStatus.connected,
        lastSync: DateTime.now(),
      );
      await NotificationService.showNewContent(
        author: _pendingAuthor,
        diaryCount: _pendingDiaryCount,
        milestoneCount: _pendingMilestoneCount,
      );
    } catch (e) {
      state = state.copyWith(
        status: SyncStatus.error,
        error: '同步失败: $e',
      );
    }
  }

  Future<void> _syncDiaries() async {
    final pb = _pb!;

    final unsynced = await _db.getUnsyncedDiaries();
    for (final diary in unsynced) {
      try {
        // If deleted locally, propagate to remote then hard-delete locally
        if (diary.deletedAt != null) {
          if (diary.remoteId != null) {
            try {
              await pb.collection('diary_entries').update(diary.remoteId!, body: {
                'deleted_at': diary.deletedAt!.toIso8601String(),
              });
            } catch (_) {}
          }
          await _db.hardDeleteDiary(diary.id);
          continue;
        }

        final body = {
          'local_id': diary.id,
          'date': diary.date.toIso8601String(),
          'title': diary.title ?? '',
          'content': diary.content,
          'mood': diary.mood ?? '',
          'author': diary.author,
          'deleted_at': '',
          'created_at': diary.createdAt.toIso8601String(),
          'updated_at': diary.updatedAt.toIso8601String(),
        };

        RecordModel record;
        if (diary.remoteId != null) {
          record = await pb.collection('diary_entries').update(diary.remoteId!, body: body);
        } else {
          record = await pb.collection('diary_entries').create(body: body);
        }

        await _db.upsertDiary(DiaryEntriesCompanion(
          id: Value(diary.id),
          remoteId: Value(record.id),
          syncedAt: Value(DateTime.now()),
          date: Value(diary.date),
          title: Value(diary.title),
          content: Value(diary.content),
          mood: Value(diary.mood),
          author: Value(diary.author),
          createdAt: Value(diary.createdAt),
          updatedAt: Value(diary.updatedAt),
        ));

        await _syncPhotosForDiary(diary.id);
      } catch (_) {}
    }

    await _pullRemoteDiaries();
  }

  Future<void> _syncPhotosForDiary(String diaryId) async {
    final pb = _pb!;
    final diary = await _db.getDiaryById(diaryId);
    if (diary == null || diary.remoteId == null) return;

    final unsynced = await _db.getUnsyncedPhotos();
    final diaryPhotos = unsynced.where((ph) => ph.diaryId == diaryId);

    for (final photo in diaryPhotos) {
      try {
        final multipartFile = await photoToMultipart(photo.localPath, 'photo');
        if (multipartFile == null) continue;

        final body = {
          'local_id': photo.id,
          'diary_id': diary.remoteId!,
          'caption': photo.caption ?? '',
        };

        RecordModel record;
        if (photo.remoteId != null) {
          record = await pb.collection('diary_photos').update(
            photo.remoteId!,
            body: body,
            files: [multipartFile],
          );
        } else {
          record = await pb.collection('diary_photos').create(
            body: body,
            files: [multipartFile],
          );
        }

        final fileName = record.get<String>('photo', '');
        await _db.upsertPhoto(DiaryPhotosCompanion(
          id: Value(photo.id),
          diaryId: Value(photo.diaryId),
          localPath: Value(photo.localPath),
          remoteId: Value(record.id),
          remoteFileName: Value(fileName.isNotEmpty ? fileName : null),
          caption: Value(photo.caption),
          createdAt: Value(photo.createdAt),
          syncedAt: Value(DateTime.now()),
        ));
      } catch (_) {}
    }
  }

  // Retry photos that were left unsynced because their diary was already synced
  // when the photo upload previously failed.
  Future<void> _syncOrphanedPhotos() async {
    final unsyncedPhotos = await _db.getUnsyncedPhotos();
    for (final photo in unsyncedPhotos) {
      final diary = await _db.getDiaryById(photo.diaryId);
      if (diary == null || diary.remoteId == null) continue;
      await _syncPhotosForDiary(photo.diaryId);
    }
  }

  Future<void> _pullRemoteDiaries() async {
    final pb = _pb!;
    try {
      final records = await pb.collection('diary_entries').getFullList();
      for (final record in records) {
        final localId = record.get<String>('local_id', record.id);
        final existing = await _db.getDiaryById(localId);

        final remoteUpdatedStr = record.get<String>('updated_at', '');
        final remoteUpdated = DateTime.tryParse(remoteUpdatedStr) ?? DateTime.now();

        final remoteDeletedStr = record.get<String>('deleted_at', '');
        if (remoteDeletedStr.isNotEmpty && DateTime.tryParse(remoteDeletedStr) != null) {
          await _db.hardDeleteDiary(localId);
          continue;
        }

        if (existing == null || existing.updatedAt.isBefore(remoteUpdated)) {
          final createdStr = record.get<String>('created_at', '');
          final remoteAuthor = record.get<String>('author', '');
          if (existing == null &&
              remoteAuthor.isNotEmpty &&
              remoteAuthor != _settings.state.currentAuthor) {
            _pendingDiaryCount++;
            if (_pendingAuthor.isEmpty) _pendingAuthor = remoteAuthor;
          }
          await _db.upsertDiary(DiaryEntriesCompanion(
            id: Value(localId),
            date: Value(DateTime.parse(record.get<String>('date'))),
            title: Value(record.get<String>('title', '') as String?),
            content: Value(record.get<String>('content', '')),
            mood: Value(record.get<String>('mood', '') as String?),
            author: Value(remoteAuthor.isNotEmpty ? remoteAuthor : (existing?.author ?? '')),
            remoteId: Value(record.id),
            createdAt: Value(DateTime.tryParse(createdStr) ?? DateTime.now()),
            updatedAt: Value(remoteUpdated),
            syncedAt: Value(DateTime.now()),
          ));
        }

        // 拉取该日记的照片（对方设备上传的）
        await _pullRemotePhotosForDiary(localId, record.id);
      }
    } catch (_) {}
  }

  Future<void> _pullRemotePhotosForDiary(String localDiaryId, String remoteDiaryId) async {
    final pb = _pb!;
    try {
      final remotePhotos = await pb.collection('diary_photos')
          .getFullList(filter: 'diary_id="$remoteDiaryId"');

      final localPhotos = await _db.getPhotosForDiary(localDiaryId);
      final localRemoteIds = localPhotos.map((p) => p.remoteId).whereType<String>().toSet();

      for (final rp in remotePhotos) {
        if (localRemoteIds.contains(rp.id)) continue; // 已有

        final fileName = rp.get<String>('photo', '');
        if (fileName.isEmpty) continue;

        final localPath = await _downloadFile('diary_photos', rp.id, fileName);
        final localId = rp.get<String>('local_id', rp.id);

        await _db.upsertPhoto(DiaryPhotosCompanion(
          id: Value(localId),
          diaryId: Value(localDiaryId),
          localPath: Value(localPath),
          remoteId: Value(rp.id),
          remoteFileName: Value(fileName),
          caption: Value(rp.get<String>('caption', '') as String?),
          createdAt: Value(DateTime.now()),
          syncedAt: Value(DateTime.now()),
        ));
      }
    } catch (_) {}
  }

  Future<void> _pullRemoteMilestones() async {
    final pb = _pb!;
    try {
      final records = await pb.collection('milestones').getFullList();
      final localAll = await _db.getAllMilestones();
      final localIds = {for (final m in localAll) m.id: m};

      for (final record in records) {
        final localId = record.get<String>('local_id', record.id);
        final existing = localIds[localId];

        final remoteUpdatedStr = record.get<String>('updated_at', '');
        final remoteUpdated = DateTime.tryParse(remoteUpdatedStr) ?? DateTime.now();

        final remoteDeletedStr = record.get<String>('deleted_at', '');
        if (remoteDeletedStr.isNotEmpty && DateTime.tryParse(remoteDeletedStr) != null) {
          await _db.hardDeleteMilestone(localId);
          continue;
        }

        if (existing != null && !existing.updatedAt.isBefore(remoteUpdated)) continue;

        final remoteAuthor = record.get<String>('author', '');
        if (existing == null &&
            remoteAuthor.isNotEmpty &&
            remoteAuthor != _settings.state.currentAuthor) {
          _pendingMilestoneCount++;
          if (_pendingAuthor.isEmpty) _pendingAuthor = remoteAuthor;
        }

        // 下载里程碑照片
        String? localPhotoPath = existing?.localPhotoPath;
        final fileName = record.get<String>('photo', '');
        if (fileName.isNotEmpty && (existing?.remoteFileName != fileName)) {
          localPhotoPath = await _downloadFile('milestones', record.id, fileName);
        }

        final createdStr = record.get<String>('created_at', '');
        await _db.upsertMilestone(MilestonesCompanion(
          id: Value(localId),
          date: Value(DateTime.parse(record.get<String>('date'))),
          title: Value(record.get<String>('title', '')),
          description: Value(record.get<String>('description', '') as String?),
          category: Value(record.get<String>('category', 'other')),
          author: Value(remoteAuthor.isNotEmpty ? remoteAuthor : (existing?.author ?? '')),
          localPhotoPath: Value(localPhotoPath),
          remoteId: Value(record.id),
          remoteFileName: Value(fileName.isNotEmpty ? fileName : null),
          createdAt: Value(DateTime.tryParse(createdStr) ?? DateTime.now()),
          updatedAt: Value(remoteUpdated),
          syncedAt: Value(DateTime.now()),
        ));
      }
    } catch (_) {}
  }

  Future<String> _downloadFile(String collection, String recordId, String fileName) async {
    final record = RecordModel({'id': recordId, 'collectionName': collection});
    final url = _pb!.files.getURL(record, fileName).toString();
    return downloadAndSaveFile(url, fileName);
  }

  Future<void> _syncMilestones() async {
    final pb = _pb!;
    final unsynced = await _db.getUnsyncedMilestones();

    for (final milestone in unsynced) {
      try {
        if (milestone.deletedAt != null) {
          if (milestone.remoteId != null) {
            try {
              await pb.collection('milestones').update(milestone.remoteId!, body: {
                'deleted_at': milestone.deletedAt!.toIso8601String(),
              });
            } catch (_) {}
          }
          await _db.hardDeleteMilestone(milestone.id);
          continue;
        }

        final body = {
          'local_id': milestone.id,
          'date': milestone.date.toIso8601String(),
          'title': milestone.title,
          'description': milestone.description ?? '',
          'category': milestone.category,
          'author': milestone.author,
          'deleted_at': '',
          'created_at': milestone.createdAt.toIso8601String(),
          'updated_at': milestone.updatedAt.toIso8601String(),
        };

        final files = <http.MultipartFile>[];
        if (milestone.localPhotoPath != null) {
          final mf = await photoToMultipart(milestone.localPhotoPath!, 'photo');
          if (mf != null) files.add(mf);
        }

        RecordModel record;
        if (milestone.remoteId != null) {
          record = await pb.collection('milestones').update(
            milestone.remoteId!,
            body: body,
            files: files.isNotEmpty ? files : const [],
          );
        } else {
          record = await pb.collection('milestones').create(
            body: body,
            files: files.isNotEmpty ? files : const [],
          );
        }

        final fileName = record.get<String>('photo', '');
        await _db.upsertMilestone(MilestonesCompanion(
          id: Value(milestone.id),
          date: Value(milestone.date),
          title: Value(milestone.title),
          description: Value(milestone.description),
          category: Value(milestone.category),
          localPhotoPath: Value(milestone.localPhotoPath),
          remoteId: Value(record.id),
          remoteFileName: Value(fileName.isNotEmpty ? fileName : null),
          createdAt: Value(milestone.createdAt),
          updatedAt: Value(milestone.updatedAt),
          syncedAt: Value(DateTime.now()),
        ));
      } catch (_) {}
    }
  }

  Future<void> _syncBabyProfile() async {
    final pb = _pb!;
    final local = _settings.state;
    final localUpdated = local.profileUpdatedAt;

    try {
      final records = await pb.collection('baby_profile').getFullList(batch: 1);

      if (records.isEmpty) {
        // 远端没有记录，推送本地
        if (local.babyName.isNotEmpty || local.babyBirthday != null) {
          await pb.collection('baby_profile').create(body: {
            'baby_name': local.babyName,
            'birthday_ms': local.babyBirthday?.millisecondsSinceEpoch,
            'height': local.babyHeight,
            'weight': local.babyWeight,
            'updated_at': (localUpdated ?? DateTime.now()).toIso8601String(),
          });
        }
      } else {
        final record = records.first;
        final remoteUpdatedStr = record.get<String>('updated_at', '');
        final remoteUpdated = DateTime.tryParse(remoteUpdatedStr) ?? DateTime(2000);

        if (localUpdated != null && localUpdated.isAfter(remoteUpdated)) {
          // 本地更新，推送到远端
          await pb.collection('baby_profile').update(record.id, body: {
            'baby_name': local.babyName,
            'birthday_ms': local.babyBirthday?.millisecondsSinceEpoch,
            'height': local.babyHeight,
            'weight': local.babyWeight,
            'updated_at': localUpdated.toIso8601String(),
          });
        } else {
          // 远端更新，同步到本地
          final birthdayMs = record.get<num?>('birthday_ms')?.toInt();
          await _settings.applyRemoteProfile(
            name: record.get<String>('baby_name', ''),
            birthdayMs: birthdayMs,
            height: record.get<num?>('height')?.toDouble(),
            weight: record.get<num?>('weight')?.toDouble(),
            remoteUpdatedAt: remoteUpdated,
          );
        }
      }
    } catch (_) {}
  }

  Future<void> _syncComments() async {
    final pb = _pb!;
    final unsynced = await _db.getUnsyncedComments();

    for (final comment in unsynced) {
      try {
        if (comment.deletedAt != null) {
          if (comment.remoteId != null) {
            try {
              await pb.collection('comments').update(comment.remoteId!, body: {
                'deleted_at': comment.deletedAt!.toIso8601String(),
              });
            } catch (_) {}
          }
          await _db.hardDeleteComment(comment.id);
          continue;
        }

        final body = {
          'local_id': comment.id,
          'parent_id': comment.parentId,
          'parent_type': comment.parentType,
          'content': comment.content,
          'author': comment.author,
          'deleted_at': '',
          'created_at': comment.createdAt.toIso8601String(),
        };

        RecordModel record;
        if (comment.remoteId != null) {
          record = await pb.collection('comments').update(comment.remoteId!, body: body);
        } else {
          record = await pb.collection('comments').create(body: body);
        }

        await _db.upsertComment(CommentsCompanion(
          id: Value(comment.id),
          parentId: Value(comment.parentId),
          parentType: Value(comment.parentType),
          content: Value(comment.content),
          author: Value(comment.author),
          createdAt: Value(comment.createdAt),
          remoteId: Value(record.id),
          syncedAt: Value(DateTime.now()),
        ));
      } catch (_) {}
    }

    // Pull remote comments
    try {
      final records = await pb.collection('comments').getFullList();
      for (final record in records) {
        final localId = record.get<String>('local_id', record.id);

        final remoteDeletedStr = record.get<String>('deleted_at', '');
        if (remoteDeletedStr.isNotEmpty && DateTime.tryParse(remoteDeletedStr) != null) {
          await _db.hardDeleteComment(localId);
          continue;
        }

        final createdStr = record.get<String>('created_at', '');
        await _db.upsertComment(CommentsCompanion(
          id: Value(localId),
          parentId: Value(record.get<String>('parent_id', '')),
          parentType: Value(record.get<String>('parent_type', 'diary')),
          content: Value(record.get<String>('content', '')),
          author: Value(record.get<String>('author', '')),
          createdAt: Value(DateTime.tryParse(createdStr) ?? DateTime.now()),
          remoteId: Value(record.id),
          syncedAt: Value(DateTime.now()),
        ));
      }
    } catch (_) {}
  }

}

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final syncServiceProvider = StateNotifierProvider<SyncService, SyncState>((ref) {
  return SyncService(ref.watch(databaseProvider), ref.read(settingsProvider.notifier));
});
