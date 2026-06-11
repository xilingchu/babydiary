import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../db/database.dart';
import '../services/sync_service.dart';

const _uuid = Uuid();

final commentsProvider = StreamProvider.family<List<Comment>, String>((ref, parentId) {
  return ref.watch(databaseProvider).watchComments(parentId);
});

class CommentNotifier extends StateNotifier<AsyncValue<void>> {
  final AppDatabase _db;
  final VoidCallback _triggerSync;

  CommentNotifier(this._db, this._triggerSync) : super(const AsyncData(null));

  Future<void> addComment({
    required String parentId,
    required String parentType,
    required String content,
    required String author,
  }) async {
    await _db.upsertComment(CommentsCompanion(
      id: Value(_uuid.v4()),
      parentId: Value(parentId),
      parentType: Value(parentType),
      content: Value(content),
      author: Value(author),
      createdAt: Value(DateTime.now()),
    ));
    _triggerSync();
  }

  Future<void> deleteComment(Comment comment) async {
    await _db.softDeleteComment(comment.id);
    _triggerSync();
  }
}

final commentNotifierProvider = StateNotifierProvider<CommentNotifier, AsyncValue<void>>((ref) {
  return CommentNotifier(
    ref.watch(databaseProvider),
    () {
      final sync = ref.read(syncServiceProvider.notifier);
      if (sync.state.status == SyncStatus.connected) sync.syncAll();
    },
  );
});
