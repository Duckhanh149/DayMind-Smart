import 'dart:io';

import 'package:timezone/data/latest_all.dart' as tzdata;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show LicenseRegistry, LicenseEntryWithLineBreaks;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'app/app.dart';
import 'app/controller.dart';
import 'app/workspace_host.dart';
import 'platform/secure_session_store.dart';
import 'features/account_sync/data/firebase_rest.dart';
import 'features/account_sync/data/firestore_gateway.dart';

bool _fontLicenseRegistered = false;
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tzdata.initializeTimeZones();
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
    final http = JsonTransport();
    const configuredHost = String.fromEnvironment('DAYMIND_EMULATOR_HOST');
    final endpoints = FirebaseEndpoints(
      host: configuredHost.isNotEmpty
          ? configuredHost
          : Platform.isAndroid
          ? '10.0.2.2'
          : '127.0.0.1',
    );
    final host = WorkspaceHost(
      support,
      NativeSessionStore(),
      FirebaseRestAuth(endpoints, http),
      FirestoreRestGateway(endpoints, http),
    );
    await host.start();
    runApp(WorkspaceApplication(host: host));
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

class WorkspaceApplication extends StatefulWidget {
  const WorkspaceApplication({super.key, required this.host});
  final WorkspaceHost host;
  @override
  State<WorkspaceApplication> createState() => _WorkspaceApplicationState();
}

class _WorkspaceApplicationState extends State<WorkspaceApplication> {
  int? generation;
  Widget? scope;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.host,
    builder: (context, _) {
      final host = widget.host;
      if (generation != host.generation) {
        generation = host.generation;
        final controller = host.controller!;
        scope = ProviderScope(
          key: ValueKey(generation),
          overrides: [
            workspaceProvider.overrideWith((ref) => controller),
            workspaceHostProvider.overrideWithValue(host),
          ],
          child: const DaymindApp(),
        );
      }
      return Stack(
        textDirection: TextDirection.ltr,
        children: [
          scope!,
          if (host.switching)
            const Positioned.fill(
              child: AbsorbPointer(
                child: ColoredBox(
                  color: Color(0xccf5f6f1),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
            ),
        ],
      );
    },
  );
}
