import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../db/database.dart';
import '../services/sync_service.dart';
import '../utils/photo_storage.dart';

const _uuid = Uuid();

final diaryListProvider = StreamProvider<List<DiaryEntry>>((ref) {
  return ref.watch(databaseProvider).watchAllDiaries();
});

final diaryPhotosProvider = StreamProvider.family<List<DiaryPhoto>, String>((ref, diaryId) {
  return ref.watch(databaseProvider).watchPhotosForDiary(diaryId);
});

class DiaryNotifier extends StateNotifier<AsyncValue<void>> {
  final AppDatabase _db;
  final VoidCallback _triggerSync;

  DiaryNotifier(this._db, this._triggerSync) : super(const AsyncData(null));

  Future<String> saveDiary({
    String? existingId,
    required DateTime date,
    String? title,
    required String content,
    String? mood,
    String author = '',
    List<XFile> newPhotos = const [],
  }) async {
    final id = existingId ?? _uuid.v4();
    final now = DateTime.now();

    await _db.upsertDiary(DiaryEntriesCompanion(
      id: Value(id),
      date: Value(date),
      title: Value(title?.isEmpty == true ? null : title),
      content: Value(content),
      mood: Value(mood),
      author: Value(author),
      createdAt: Value(now),
      updatedAt: Value(now),
    ));

    for (final photo in newPhotos) {
      await _addPhoto(id, photo);
    }

    _triggerSync();
    return id;
  }

  Future<void> _addPhoto(String diaryId, XFile xfile) async {
    final destPath = await savePickedPhoto(xfile, 'diary_photos');
    await _db.upsertPhoto(DiaryPhotosCompanion(
      id: Value(_uuid.v4()),
      diaryId: Value(diaryId),
      localPath: Value(destPath),
      createdAt: Value(DateTime.now()),
    ));
  }

  Future<void> deletePhoto(DiaryPhoto photo) async {
    await _db.deletePhoto(photo.id);
    await deletePhotoFile(photo.localPath);
  }

  Future<void> deleteDiary(String id) async {
    final photos = await _db.getPhotosForDiary(id);
    for (final photo in photos) {
      await deletePhotoFile(photo.localPath);
      await _db.deletePhoto(photo.id);
    }
    await _db.softDeleteDiary(id);
    _triggerSync();
  }
}

final diaryNotifierProvider = StateNotifierProvider<DiaryNotifier, AsyncValue<void>>((ref) {
  return DiaryNotifier(
    ref.watch(databaseProvider),
    () {
      final sync = ref.read(syncServiceProvider.notifier);
      if (sync.state.status == SyncStatus.connected) sync.syncAll();
    },
  );
});
