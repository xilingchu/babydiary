import 'package:drift_flutter/drift_flutter.dart';
import 'package:drift/drift.dart';

QueryExecutor openConnection() {
  return driftDatabase(
    name: 'baby_diary',
    web: DriftWebOptions(
      sqlite3Wasm: Uri.parse('sqlite3.wasm'),
      driftWorker: Uri.parse('drift_worker.dart.js'),
    ),
  );
}
