import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../db/database.dart';
import '../services/sync_service.dart';
import '../utils/photo_storage.dart';

const _uuid = Uuid();

const milestoneCategories = {
  'movement': '运动',
  'speech': '语言',
  'social': '社交',
  'cognitive': '认知',
  'other': '其他',
};

final milestoneListProvider = StreamProvider<List<Milestone>>((ref) {
  return ref.watch(databaseProvider).watchAllMilestones();
});

class MilestoneNotifier extends StateNotifier<AsyncValue<void>> {
  final AppDatabase _db;
  final VoidCallback _triggerSync;

  MilestoneNotifier(this._db, this._triggerSync) : super(const AsyncData(null));

  Future<void> saveMilestone({
    String? existingId,
    required DateTime date,
    required String title,
    String? description,
    String category = 'other',
    String author = '',
    XFile? photo,
  }) async {
    final id = existingId ?? _uuid.v4();
    final now = DateTime.now();

    String? photoPath;
    if (photo != null) {
      photoPath = await savePickedPhoto(photo, 'milestone_photos');
    }

    await _db.upsertMilestone(MilestonesCompanion(
      id: Value(id),
      date: Value(date),
      title: Value(title),
      description: Value(description?.isEmpty == true ? null : description),
      category: Value(category),
      author: Value(author),
      localPhotoPath: photoPath != null ? Value(photoPath) : const Value.absent(),
      createdAt: Value(now),
      updatedAt: Value(now),
    ));

    _triggerSync();
  }

  Future<void> deleteMilestone(Milestone milestone) async {
    if (milestone.localPhotoPath != null) {
      await deletePhotoFile(milestone.localPhotoPath!);
    }
    await _db.softDeleteMilestone(milestone.id);
    _triggerSync();
  }
}

final milestoneNotifierProvider = StateNotifierProvider<MilestoneNotifier, AsyncValue<void>>((ref) {
  return MilestoneNotifier(
    ref.watch(databaseProvider),
    () {
      final sync = ref.read(syncServiceProvider.notifier);
      if (sync.state.status == SyncStatus.connected) sync.syncAll();
    },
  );
});
