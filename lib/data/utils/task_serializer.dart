import 'package:q_task/domain/models/task.dart';

class TaskSerializer {
  static String toMarkdown(Task task) {
    final buffer = StringBuffer();
    buffer.writeln('# ${task.title}');
    buffer.writeln();
    buffer.writeln('**ID:** ${task.id}');
    buffer.writeln('**Created:** ${task.createdAt.toIso8601String()}');
    if (task.dueDate != null) {
      buffer.writeln('**Due Date:** ${task.dueDate!.toIso8601String()}');
    }
    buffer.writeln('**Completed:** ${task.isCompleted}');
    if (task.completedAt != null) {
      buffer
          .writeln('**Completed At:** ${task.completedAt!.toIso8601String()}');
    }
    buffer.writeln('**Position:** ${task.position}');
    buffer.writeln();

    if (task.tags.isNotEmpty) {
      buffer.writeln('**Tags:** ${task.tags.join(', ')}');
      buffer.writeln();
    }

    if (task.listIds.isNotEmpty) {
      buffer.writeln('**Lists:** ${task.listIds.join(', ')}');
      buffer.writeln();
    }

    if (task.attachedFiles.isNotEmpty) {
      buffer.writeln('**Attached Files:**');
      for (final file in task.attachedFiles) {
        buffer.writeln('- $file');
      }
      buffer.writeln();
    }

    buffer.writeln('## Description');
    buffer.writeln();
    buffer.writeln(
        task.description.isEmpty ? '(No description)' : task.description);

    return buffer.toString();
  }

  static Task? fromMarkdown(String content, String taskId) {
    try {
      final lines = content.split('\n');
      String title = '';
      DateTime? createdAt;
      DateTime? dueDate;
      List<String> tags = [];
      List<String> listIds = [];
      List<String> attachedFiles = [];
      int position = 0;
      bool isCompleted = false;

      bool inDescription = false;
      bool inAttachedFiles = false;
      final descriptionLines = <String>[];
      DateTime? completedAt;

      for (final line in lines) {
        if (line.startsWith('# ')) {
          title = line.substring(2).trim();
        } else if (line.startsWith('**ID:**')) {
          // Already have ID
        } else if (line.startsWith('**Created:**')) {
          final dateStr = line.replaceFirst('**Created:**', '').trim();
          createdAt = DateTime.tryParse(dateStr);
        } else if (line.startsWith('**Due Date:**')) {
          final dateStr = line.replaceFirst('**Due Date:**', '').trim();
          dueDate = DateTime.tryParse(dateStr);
        } else if (line.startsWith('**Completed:**')) {
          isCompleted = line.contains('true');
        } else if (line.startsWith('**Completed At:**')) {
          final dateStr = line.replaceFirst('**Completed At:**', '').trim();
          completedAt = DateTime.tryParse(dateStr);
        } else if (line.startsWith('**Position:**')) {
          final posStr = line.replaceFirst('**Position:**', '').trim();
          position = int.tryParse(posStr) ?? 0;
        } else if (line.startsWith('**Tags:**')) {
          final tagsStr = line.replaceFirst('**Tags:**', '').trim();
          tags = tagsStr.isEmpty
              ? []
              : tagsStr.split(', ').map((t) => t.trim()).toList();
        } else if (line.startsWith('**Lists:**')) {
          final listsStr = line.replaceFirst('**Lists:**', '').trim();
          listIds = listsStr.isEmpty
              ? []
              : listsStr.split(', ').map((l) => l.trim()).toList();
        } else if (line.startsWith('**Attached Files:**')) {
          inAttachedFiles = true;
          inDescription = false;
        } else if (line.startsWith('## Description')) {
          inDescription = true;
          inAttachedFiles = false;
        } else if (inAttachedFiles && line.startsWith('- ')) {
          attachedFiles.add(line.substring(2).trim());
        } else if (inDescription &&
            line.isNotEmpty &&
            !line.startsWith('## ')) {
          if (line != '(No description)') {
            descriptionLines.add(line);
          }
        }
      }

      return Task(
        id: taskId,
        title: title.isEmpty ? 'Untitled' : title,
        description: descriptionLines.join('\n').trim(),
        createdAt: createdAt ?? DateTime.now(),
        dueDate: dueDate,
        tags: tags,
        listIds: listIds,
        attachedFiles: attachedFiles,
        position: position,
        isCompleted: isCompleted,
        completedAt: completedAt,
      );
    } catch (e) {
      return null;
    }
  }
}
