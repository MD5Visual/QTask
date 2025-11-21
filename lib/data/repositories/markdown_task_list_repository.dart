import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:q_task/domain/models/task_list.dart';
import 'package:q_task/domain/repositories/i_repository.dart';

class MarkdownTaskListRepository implements ITaskListRepository {
  late Directory _listsDir;
  static const String _indexFileName = 'lists_index.md';

  Future<void> _ensureDirectoryExists() async {
    final appDir = await getApplicationDocumentsDirectory();
    _listsDir = Directory('${appDir.path}/lists');
    if (!await _listsDir.exists()) {
      await _listsDir.create(recursive: true);
    }
  }

  String _listToMarkdown(TaskList taskList) {
    final buffer = StringBuffer();
    buffer.writeln('# ${taskList.name}');
    buffer.writeln();
    buffer.writeln('**ID:** ${taskList.id}');
    buffer.writeln('**Color:** ${taskList.color}');
    buffer.writeln('**Created:** ${taskList.createdAt.toIso8601String()}');
    buffer.writeln('**Position:** ${taskList.position}');
    buffer.writeln('**Hidden:** ${taskList.isHidden ? 'true' : 'false'}');

    return buffer.toString();
  }

  Future<void> _saveListMarkdown(TaskList taskList) async {
    await _ensureDirectoryExists();
    final file = File('${_listsDir.path}/${taskList.id}.md');
    await file.writeAsString(_listToMarkdown(taskList));
  }

  Future<void> _saveIndex(List<TaskList> lists) async {
    await _ensureDirectoryExists();
    final indexFile = File('${_listsDir.path}/$_indexFileName');
    final sortedLists = lists..sort((a, b) => a.position.compareTo(b.position));

    final buffer = StringBuffer();
    buffer.writeln('# Task Lists Index');
    buffer.writeln();
    for (final list in sortedLists) {
      buffer.writeln('- ${list.id}|${list.name}|${list.position}');
    }

    await indexFile.writeAsString(buffer.toString());
  }

  @override
  Future<void> saveTaskLists(List<TaskList> lists) async {
    for (final list in lists) {
      await _saveListMarkdown(list);
    }
    await _saveIndex(lists);
  }

  @override
  Future<List<TaskList>> loadTaskLists() async {
    await _ensureDirectoryExists();
    final lists = <TaskList>[];

    final indexFile = File('${_listsDir.path}/$_indexFileName');
    if (!await indexFile.exists()) {
      return [];
    }

    final indexContent = await indexFile.readAsString();
    final lines = indexContent.split('\n');

    for (final line in lines) {
      if (line.isEmpty || line.startsWith('#')) continue;

      final parts = line.split('|');
      if (parts.length >= 3) {
        final listId = parts[0].trim().replaceFirst('- ', '');
        final listFile = File('${_listsDir.path}/$listId.md');

        if (await listFile.exists()) {
          final listContent = await listFile.readAsString();
          final taskList = _parseListMarkdown(listContent, listId);
          if (taskList != null) {
            lists.add(taskList);
          }
        }
      }
    }

    return lists;
  }

  TaskList? _parseListMarkdown(String content, String listId) {
    try {
      final lines = content.split('\n');
      String name = '';
      String color = '#3F51B5';
      DateTime? createdAt;
      int position = 0;
      bool isHidden = false;

      for (final line in lines) {
        if (line.startsWith('# ')) {
          name = line.substring(2).trim();
        } else if (line.startsWith('**Color:**')) {
          color = line.replaceFirst('**Color:**', '').trim();
        } else if (line.startsWith('**Created:**')) {
          final dateStr = line.replaceFirst('**Created:**', '').trim();
          createdAt = DateTime.tryParse(dateStr);
        } else if (line.startsWith('**Position:**')) {
          final posStr = line.replaceFirst('**Position:**', '').trim();
          position = int.tryParse(posStr) ?? 0;
        } else if (line.startsWith('**Hidden:**')) {
          final hiddenStr = line.replaceFirst('**Hidden:**', '').trim();
          isHidden = hiddenStr.toLowerCase() == 'true';
        }
      }

      return TaskList(
        id: listId,
        name: name.isEmpty ? 'Untitled List' : name,
        color: color,
        createdAt: createdAt ?? DateTime.now(),
        position: position,
        isHidden: isHidden,
      );
    } catch (e) {
      return null;
    }
  }
}
