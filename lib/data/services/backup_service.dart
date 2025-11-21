import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:q_task/data/services/storage_service.dart';

class BackupService {
  final StorageService _storageService;

  BackupService(this._storageService);

  Future<String> createBackup() async {
    final rootDir = await _storageService.getRootDirectory();
    final appDir =
        await getApplicationDocumentsDirectory(); // Keep for temp file
    final encoder = ZipFileEncoder();

    final timestamp =
        DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
    final backupFileName = 'qtask_backup_$timestamp.zip';
    final backupFile = path.join(appDir.path, backupFileName);

    try {
      encoder.create(backupFile);

      // Add tasks directory
      final tasksDir = Directory(path.join(rootDir.path, 'tasks'));
      if (await tasksDir.exists()) {
        await encoder.addDirectory(tasksDir);
      }

      // Add lists directory
      final listsDir = Directory(path.join(rootDir.path, 'lists'));
      if (await listsDir.exists()) {
        await encoder.addDirectory(listsDir);
      }

      // Add attachments directory
      final attachmentsDir =
          Directory(path.join(rootDir.path, 'task_attachments'));
      if (await attachmentsDir.exists()) {
        await encoder.addDirectory(attachmentsDir);
      }

      // Add settings.json (always in default app dir or custom?)
      // Settings are managed by SettingsProvider which uses getApplicationDocumentsDirectory
      // We should probably keep settings in the default location for now or move them too.
      // The plan said "Consolidate all app data into a QTask folder".
      // But SettingsProvider currently uses getApplicationDocumentsDirectory().
      // Let's keep settings.json where it is for now as it contains the path to the custom folder!

      final defaultAppDir = await getApplicationDocumentsDirectory();
      final settingsFileObj =
          File(path.join(defaultAppDir.path, 'settings.json'));

      if (await settingsFileObj.exists()) {
        await encoder.addFile(settingsFileObj);
      }

      encoder.close();
      return backupFile;
    } catch (e) {
      debugPrint('Error creating backup: $e');
      rethrow;
    }
  }

  Future<void> restoreBackup(String zipPath) async {
    final rootDir = await _storageService.getRootDirectory();
    final defaultAppDir = await getApplicationDocumentsDirectory();

    try {
      final bytes = await File(zipPath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      for (final file in archive.files) {
        if (file.isFile) {
          // If it's settings.json, restore to default app dir
          String outputPath;
          if (file.name == 'settings.json') {
            outputPath = path.join(defaultAppDir.path, file.name);
          } else {
            // Otherwise restore to rootDir (custom or default QTask folder)
            // The zip structure has folders 'tasks/', 'lists/', etc.
            // So we just join rootDir with file.name
            outputPath = path.join(rootDir.path, file.name);
          }

          final outputStream = OutputFileStream(outputPath);
          file.writeContent(outputStream);
          outputStream.close();
        }
      }
    } catch (e) {
      debugPrint('Error restoring backup: $e');
      rethrow;
    }
  }
}
