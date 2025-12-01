import 'dart:async';
import 'dart:io';
import 'package:q_task/data/services/storage_service.dart';
import 'package:q_task/data/utils/task_serializer.dart';
import 'package:q_task/domain/models/task.dart';
import 'package:q_task/domain/repositories/i_repository.dart';

class MarkdownTaskRepository implements ITaskRepository {
  late Directory _tasksDir;
  static const String _indexFileName = 'tasks_index.md';
  final StorageService _storageService;
  final _taskStreamController = StreamController<List<Task>>.broadcast();

  MarkdownTaskRepository(this._storageService);

  @override
  Stream<List<Task>> watchTasks() => _taskStreamController.stream;

  Future<void> _emitTasks() async {
    final tasks = await loadTasks();
    _taskStreamController.add(tasks);
  }

  Future<void> _ensureDirectoryExists() async {
    final rootDir = await _storageService.getRootDirectory();
    _tasksDir = Directory('${rootDir.path}/tasks');
    if (!_tasksDir.existsSync()) {
      await _tasksDir.create(recursive: true);
    }
  }

  Future<void> _saveTaskMarkdown(Task task) async {
    await _ensureDirectoryExists();
    final file = File('${_tasksDir.path}/${task.id}.md');
    await file.writeAsString(TaskSerializer.toMarkdown(task));
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
    _taskStreamController.add(tasks);
  }

  @override
  Future<void> addTask(Task task) async {
    await _saveTaskMarkdown(task);
    final allTasks = await loadTasks();
    await _saveIndex([...allTasks, task]);
    await _emitTasks();
  }

  @override
  Future<void> updateTask(Task task) async {
    await _saveTaskMarkdown(task);
    final allTasks = await loadTasks();
    final index = allTasks.indexWhere((t) => t.id == task.id);
    if (index != -1) {
      allTasks[index] = task;
      await _saveIndex(allTasks);
      _taskStreamController.add(allTasks);
    }
  }

  @override
  Future<void> deleteTask(String taskId) async {
    await _ensureDirectoryExists();
    final file = File('${_tasksDir.path}/$taskId.md');
    if (file.existsSync()) {
      await file.delete();
    }
    final allTasks = await loadTasks();
    allTasks.removeWhere((t) => t.id == taskId);
    await _saveIndex(allTasks);
    _taskStreamController.add(allTasks);
  }

  @override
  Future<List<Task>> loadTasks() async {
    await _ensureDirectoryExists();
    final tasks = <Task>[];

    final indexFile = File('${_tasksDir.path}/$_indexFileName');
    if (!indexFile.existsSync()) {
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

        if (taskFile.existsSync()) {
          final taskContent = await taskFile.readAsString();
          final task = TaskSerializer.fromMarkdown(taskContent, taskId);
          if (task != null) {
            tasks.add(task);
          }
        }
      }
    }

    return tasks;
  }
}
