import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:q_task/domain/models/task.dart';
import 'package:q_task/domain/repositories/i_repository.dart';

class MarkdownTaskRepository implements ITaskRepository {
  late Directory _tasksDir;
  static const String _indexFileName = 'tasks_index.md';

  Future<void> _ensureDirectoryExists() async {
    final appDir = await getApplicationDocumentsDirectory();
    _tasksDir = Directory('${appDir.path}/tasks');
    if (!await _tasksDir.exists()) {
      await _tasksDir.create(recursive: true);
    }
  }

  String _taskToMarkdown(Task task) {
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

  Future<void> _saveTaskMarkdown(Task task) async {
    await _ensureDirectoryExists();
    final file = File('${_tasksDir.path}/${task.id}.md');
    await file.writeAsString(_taskToMarkdown(task));
  }

  Future<void> _saveIndex(List<Task> tasks) async {
    await _ensureDirectoryExists();
    final indexFile = File('${_tasksDir.path}/$_indexFileName');
    final sortedTasks = tasks..sort((a, b) => a.position.compareTo(b.position));

    final buffer = StringBuffer();
    buffer.writeln('# Task Index');
    buffer.writeln();
    for (final task in sortedTasks) {
      buffer.writeln(
          '- ${task.id}|${task.title}|${task.position}|${task.isCompleted}');
    }

    await indexFile.writeAsString(buffer.toString());
  }

  @override
  Future<void> saveTasks(List<Task> tasks) async {
    for (final task in tasks) {
      await _saveTaskMarkdown(task);
    }
    await _saveIndex(tasks);
  }

  @override
  Future<void> addTask(Task task) async {
    await _saveTaskMarkdown(task);
    final allTasks = await loadTasks();
    await _saveIndex([...allTasks, task]);
  }

  @override
  Future<void> updateTask(Task task) async {
    await _saveTaskMarkdown(task);
    final allTasks = await loadTasks();
    final index = allTasks.indexWhere((t) => t.id == task.id);
    if (index != -1) {
      allTasks[index] = task;
      await _saveIndex(allTasks);
    }
  }

  @override
  Future<void> deleteTask(String taskId) async {
    await _ensureDirectoryExists();
    final file = File('${_tasksDir.path}/$taskId.md');
    if (await file.exists()) {
      await file.delete();
    }
    final allTasks = await loadTasks();
    allTasks.removeWhere((t) => t.id == taskId);
    await _saveIndex(allTasks);
  }

  @override
  Future<List<Task>> loadTasks() async {
    await _ensureDirectoryExists();
    final tasks = <Task>[];

    final indexFile = File('${_tasksDir.path}/$_indexFileName');
    if (!await indexFile.exists()) {
      return [];
    }

    final indexContent = await indexFile.readAsString();
    final lines = indexContent.split('\n');

    for (final line in lines) {
      if (line.isEmpty || line.startsWith('#')) continue;

      final parts = line.split('|');
      if (parts.length >= 4) {
        final taskId = parts[0].trim().replaceFirst('- ', '');
        final taskFile = File('${_tasksDir.path}/$taskId.md');

        if (await taskFile.exists()) {
          final taskContent = await taskFile.readAsString();
          final task = _parseTaskMarkdown(taskContent, taskId);
          if (task != null) {
            tasks.add(task);
          }
        }
      }
    }

    return tasks;
  }

  Task? _parseTaskMarkdown(String content, String taskId) {
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
