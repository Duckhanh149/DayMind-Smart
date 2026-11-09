import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show LicenseRegistry, LicenseEntryWithLineBreaks;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app/app.dart';
import 'app/controller.dart';
import 'features/tasks/data/database.dart';
import 'features/companion/data/asset_importer.dart';

bool _fontLicenseRegistered = false;
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!_fontLicenseRegistered) {
    _fontLicenseRegistered = true;
    LicenseRegistry.addLicense(() async* {
      yield LicenseEntryWithLineBreaks([
        'Be Vietnam Pro',
      ], await rootBundle.loadString('assets/fonts/OFL.txt'));
    });
  }
  try {
    final support = await getApplicationSupportDirectory();
    await support.create(recursive: true);
    final database = DaymindDatabase(
      NativeDatabase.createInBackground(
        File(p.join(support.path, 'daymind.sqlite')),
      ),
    );
    final controller = WorkspaceController(
      SqliteTaskRepository(database),
      StaticAssetImporter(Directory(p.join(support.path, 'characters'))),
    );
    await controller.load();
    runApp(
      ProviderScope(
        overrides: [workspaceProvider.overrideWith((ref) => controller)],
        child: const DaymindApp(),
      ),
    );
  } catch (error) {
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.storage_rounded, size: 48),
                  const SizedBox(height: 20),
                  const Text('Chưa mở được dữ liệu DayMind.'),
                  const SizedBox(height: 8),
                  Text('$error', textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  FilledButton(onPressed: main, child: const Text('Thử lại')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
