import 'dart:io';
import 'package:cross_file/cross_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class AttachmentService {
  Future<String> saveAttachment(String taskId, XFile file) async {
    final appDir = await getApplicationDocumentsDirectory();
    final taskAttachmentsDir =
        Directory(path.join(appDir.path, 'task_attachments', taskId));

    if (!await taskAttachmentsDir.exists()) {
      await taskAttachmentsDir.create(recursive: true);
    }

    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}_${path.basename(file.path)}';
    final savedFile = File(path.join(taskAttachmentsDir.path, fileName));

    await file.saveTo(savedFile.path);
    return savedFile.path;
  }

  Future<String> getAttachmentsDirectory(String taskId) async {
    final appDir = await getApplicationDocumentsDirectory();
    return path.join(appDir.path, 'task_attachments', taskId);
  }
}
