import 'package:drift/drift.dart';
import 'db_connection.dart';

part 'database.g.dart';

class DiaryEntries extends Table {
  TextColumn get id => text()();
  DateTimeColumn get date => dateTime()();
  TextColumn get title => text().nullable()();
  TextColumn get content => text()();
  TextColumn get mood => text().nullable()();
  TextColumn get author => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn get remoteId => text().nullable()();
  DateTimeColumn get syncedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class DiaryPhotos extends Table {
  TextColumn get id => text()();
  TextColumn get diaryId => text().references(DiaryEntries, #id)();
  TextColumn get localPath => text()();
  TextColumn get remoteId => text().nullable()();
  TextColumn get remoteFileName => text().nullable()();
  TextColumn get caption => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Milestones extends Table {
  TextColumn get id => text()();
  DateTimeColumn get date => dateTime()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  TextColumn get category => text().withDefault(const Constant('other'))();
  TextColumn get author => text().withDefault(const Constant(''))();
  TextColumn get localPhotoPath => text().nullable()();
  TextColumn get remoteId => text().nullable()();
  TextColumn get remoteFileName => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get syncedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Comments extends Table {
  TextColumn get id => text()();
  TextColumn get parentId => text()();
  TextColumn get parentType => text()(); // 'diary' | 'milestone'
  TextColumn get content => text()();
  TextColumn get author => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get remoteId => text().nullable()();
  DateTimeColumn get syncedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [DiaryEntries, DiaryPhotos, Milestones, Comments])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(diaryEntries, diaryEntries.author);
        await m.addColumn(milestones, milestones.author);
      }
      if (from < 3) {
        await m.addColumn(diaryEntries, diaryEntries.deletedAt);
        await m.addColumn(milestones, milestones.deletedAt);
      }
      if (from < 4) {
        await m.createTable(comments);
      }
    },
  );

  static QueryExecutor _openConnection() => openConnection();

  // DiaryEntry queries
  Stream<List<DiaryEntry>> watchAllDiaries() =>
      (select(diaryEntries)
        ..where((t) => t.deletedAt.isNull())
        ..orderBy([(t) => OrderingTerm.desc(t.date)])).watch();

  Future<DiaryEntry?> getDiaryById(String id) =>
      (select(diaryEntries)
        ..where((t) => t.id.equals(id) & t.deletedAt.isNull())).getSingleOrNull();

  Future<void> upsertDiary(DiaryEntriesCompanion entry) =>
      into(diaryEntries).insertOnConflictUpdate(entry);

  Future<void> softDeleteDiary(String id) async {
    final now = DateTime.now();
    await (update(diaryEntries)..where((t) => t.id.equals(id))).write(
      DiaryEntriesCompanion(deletedAt: Value(now), syncedAt: const Value(null)),
    );
    await (update(comments)..where((t) => t.parentId.equals(id) & t.parentType.equals('diary'))).write(
      CommentsCompanion(deletedAt: Value(now), syncedAt: const Value(null)),
    );
  }

  Future<void> hardDeleteDiary(String id) async {
    await (delete(comments)..where((t) => t.parentId.equals(id))).go();
    await (delete(diaryPhotos)..where((t) => t.diaryId.equals(id))).go();
    await (delete(diaryEntries)..where((t) => t.id.equals(id))).go();
  }

  // DiaryPhoto queries
  Future<List<DiaryPhoto>> getPhotosForDiary(String diaryId) =>
      (select(diaryPhotos)..where((t) => t.diaryId.equals(diaryId))).get();

  Stream<List<DiaryPhoto>> watchPhotosForDiary(String diaryId) =>
      (select(diaryPhotos)..where((t) => t.diaryId.equals(diaryId))).watch();

  Future<void> upsertPhoto(DiaryPhotosCompanion photo) =>
      into(diaryPhotos).insertOnConflictUpdate(photo);

  Future<void> deletePhoto(String id) =>
      (delete(diaryPhotos)..where((t) => t.id.equals(id))).go();

  // Milestone queries
  Stream<List<Milestone>> watchAllMilestones() =>
      (select(milestones)
        ..where((t) => t.deletedAt.isNull())
        ..orderBy([(t) => OrderingTerm.desc(t.date)])).watch();

  Future<List<Milestone>> getAllMilestones() =>
      (select(milestones)
        ..where((t) => t.deletedAt.isNull())
        ..orderBy([(t) => OrderingTerm.desc(t.date)])).get();

  Future<void> upsertMilestone(MilestonesCompanion milestone) =>
      into(milestones).insertOnConflictUpdate(milestone);

  Future<void> softDeleteMilestone(String id) async {
    final now = DateTime.now();
    await (update(milestones)..where((t) => t.id.equals(id))).write(
      MilestonesCompanion(deletedAt: Value(now), syncedAt: const Value(null)),
    );
    await (update(comments)..where((t) => t.parentId.equals(id) & t.parentType.equals('milestone'))).write(
      CommentsCompanion(deletedAt: Value(now), syncedAt: const Value(null)),
    );
  }

  Future<void> hardDeleteMilestone(String id) async {
    await (delete(comments)..where((t) => t.parentId.equals(id))).go();
    await (delete(milestones)..where((t) => t.id.equals(id))).go();
  }

  // Comment queries
  Stream<List<Comment>> watchComments(String parentId) =>
      (select(comments)
        ..where((t) => t.parentId.equals(parentId) & t.deletedAt.isNull())
        ..orderBy([(t) => OrderingTerm.asc(t.createdAt)])).watch();

  Future<void> upsertComment(CommentsCompanion comment) =>
      into(comments).insertOnConflictUpdate(comment);

  Future<void> softDeleteComment(String id) async {
    final now = DateTime.now();
    await (update(comments)..where((t) => t.id.equals(id))).write(
      CommentsCompanion(deletedAt: Value(now), syncedAt: const Value(null)),
    );
  }

  Future<void> hardDeleteComment(String id) =>
      (delete(comments)..where((t) => t.id.equals(id))).go();

  // Sync helpers
  Future<List<DiaryEntry>> getUnsyncedDiaries() =>
      (select(diaryEntries)..where((t) => t.syncedAt.isNull())).get();

  Future<List<DiaryPhoto>> getUnsyncedPhotos() =>
      (select(diaryPhotos)..where((t) => t.syncedAt.isNull())).get();

  Future<List<Milestone>> getUnsyncedMilestones() =>
      (select(milestones)..where((t) => t.syncedAt.isNull())).get();

  Future<List<Comment>> getUnsyncedComments() =>
      (select(comments)..where((t) => t.syncedAt.isNull())).get();
}
