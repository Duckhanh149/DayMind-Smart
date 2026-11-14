import 'dart:convert';

import 'package:drift/drift.dart';

import '../features/tasks/data/database.dart';

class RecordStore {
  RecordStore(this.db);
  final DaymindDatabase db;
  Future<Map<String, dynamic>?> get(String area, String id) async {
    final row = await (db.select(
      db.extensionRecords,
    )..where((r) => r.area.equals(area) & r.id.equals(id))).getSingleOrNull();
    return row == null ? null : jsonDecode(row.value) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> list(String area) async =>
      (await (db.select(
            db.extensionRecords,
          )..where((r) => r.area.equals(area))).get())
          .map((r) => jsonDecode(r.value) as Map<String, dynamic>)
          .toList();
  Future<void> put(String area, String id, Map<String, dynamic> value) async {
    await db
        .into(db.extensionRecords)
        .insertOnConflictUpdate(
          ExtensionRecordsCompanion.insert(
            area: area,
            id: id,
            value: jsonEncode(value),
            updatedMs: DateTime.now().millisecondsSinceEpoch,
          ),
        );
  }

  Future<void> remove(String area, String id) async {
    await (db.delete(
      db.extensionRecords,
    )..where((r) => r.area.equals(area) & r.id.equals(id))).go();
  }
}
