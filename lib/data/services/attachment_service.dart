import 'dart:io';
import 'package:cross_file/cross_file.dart';
import 'package:path/path.dart' as path;
import 'package:q_task/data/services/storage_service.dart';

class AttachmentService {
  final StorageService _storageService;

  AttachmentService(this._storageService);

  Future<String> saveAttachment(String taskId, XFile file) async {
    final rootDir = await _storageService.getRootDirectory();
    final taskAttachmentsDir =
        Directory(path.join(rootDir.path, 'task_attachments', taskId));

    if (!taskAttachmentsDir.existsSync()) {
      await taskAttachmentsDir.create(recursive: true);
    }

    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}_${path.basename(file.path)}';
    final savedFile = File(path.join(taskAttachmentsDir.path, fileName));

    await file.saveTo(savedFile.path);
    return savedFile.path;
  }

  Future<String> getAttachmentsDirectory(String taskId) async {
    final rootDir = await _storageService.getRootDirectory();
    return path.join(rootDir.path, 'task_attachments', taskId);
  }
}
