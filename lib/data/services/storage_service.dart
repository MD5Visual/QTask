import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:q_task/presentation/providers/settings_provider.dart';

class StorageService {
  final SettingsProvider _settingsProvider;

  StorageService(this._settingsProvider);

  Future<Directory> getRootDirectory() async {
    final customPath = _settingsProvider.settings.customDataPath;
    if (customPath != null && customPath.isNotEmpty) {
      final dir = Directory(customPath);
      if (await dir.exists()) {
        return dir;
      }
    }

    final appDir = await getApplicationDocumentsDirectory();
    return Directory(path.join(appDir.path, 'QTask'));
  }

  Future<void> ensureDirectoryExists() async {
    final rootDir = await getRootDirectory();
    if (!await rootDir.exists()) {
      await rootDir.create(recursive: true);
    }

    // Ensure subdirectories exist
    await Directory(path.join(rootDir.path, 'tasks')).create(recursive: true);
    await Directory(path.join(rootDir.path, 'lists')).create(recursive: true);
    await Directory(path.join(rootDir.path, 'task_attachments'))
        .create(recursive: true);
  }
}
