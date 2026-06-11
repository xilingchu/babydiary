import 'dart:io';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:drift/drift.dart';

QueryExecutor openConnection() {
  return driftDatabase(
    name: 'baby_diary',
    native: DriftNativeOptions(
      databaseDirectory: () async {
        final dir = await getApplicationDocumentsDirectory();
        return Directory(p.join(dir.path, 'baby_diary_db'));
      },
    ),
  );
}
