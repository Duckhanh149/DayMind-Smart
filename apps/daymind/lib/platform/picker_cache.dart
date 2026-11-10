import 'dart:io';

import 'package:file_picker/file_picker.dart';

/// Android's document picker makes private cache copies. Remove only the
/// plugin-owned copies, never the original user files selected on Windows.
Future<bool> clearAndroidPickerCache() async {
  if (!Platform.isAndroid) return true;
  try {
    await FilePicker.clearTemporaryFiles();
    return true;
  } catch (_) {
    return false;
  }
}
