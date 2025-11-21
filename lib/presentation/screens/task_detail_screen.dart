import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:q_task/domain/models/task.dart';
import 'package:q_task/domain/models/task_list.dart';
import 'package:q_task/presentation/theme/outline_styles.dart';
import 'package:q_task/presentation/services/hunspell_spell_check_service.dart';

class TaskDetailScreen extends StatefulWidget {
  final Task? task;
  final List<TaskList> availableLists;

  const TaskDetailScreen(
      {this.task, this.availableLists = const [], super.key});

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _fileController;

  List<String> _files = [];
  List<String> _selectedListIds = [];
  List<TaskList> _availableLists = [];
  DateTime? _dueDate;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task?.title ?? '');
    _descriptionController =
        TextEditingController(text: widget.task?.description ?? '');
    _fileController = TextEditingController();
    _files = List.from(widget.task?.attachedFiles ?? []);
    _selectedListIds = List.from(widget.task?.listIds ?? []);
    _dueDate = widget.task?.dueDate;
    _availableLists = widget.availableLists;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _fileController.dispose();
    super.dispose();
  }

  void _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _dueDate = picked;
      });
    }
  }

  void _saveTask() {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a task title')),
      );
      return;
    }

    final updatedTask = Task(
      id: widget.task?.id,
      title: _titleController.text,
      description: _descriptionController.text,
      tags: widget.task?.tags ?? [],
      attachedFiles: _files,
      dueDate: _dueDate,
      createdAt: widget.task?.createdAt,
      completedAt: widget.task?.completedAt,
      listIds: _selectedListIds,
      position: widget.task?.position ?? 0,
      isCompleted: widget.task?.isCompleted ?? false,
    );

    Navigator.of(context).pop(updatedTask);
  }

  @override
  Widget build(BuildContext context) {
    final existingTask = widget.task;
    final dateFormatter = DateFormat.yMMMd().add_jm();
    final historyEntries = <_HistoryEntry>[];
    if (existingTask != null) {
      historyEntries.add(_HistoryEntry('Created', existingTask.createdAt));
      if (existingTask.completedAt != null) {
        historyEntries
            .add(_HistoryEntry('Checked off', existingTask.completedAt!));
      }
      historyEntries.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.task == null ? 'New Task' : 'Edit Task'),
        elevation: 0,
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saveTask,
              child: const Text('Save Task'),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            TextField(
              controller: _titleController,
              autofocus: widget.task == null,
              decoration: InputDecoration(
                labelText: 'Task Title',
                hintText: 'Enter task title',
                border: OutlineStyles.inputBorder(),
              ),
              style: Theme.of(context).textTheme.titleLarge,
              spellCheckConfiguration: hunspellSpellCheckConfiguration,
              contextMenuBuilder: spellCheckContextMenuBuilder,
              onSubmitted: (_) => _saveTask(),
            ),
            const SizedBox(height: 16),
            // Description
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: 'Description',
                hintText: 'Enter task description',
                border: OutlineStyles.inputBorder(),
              ),
              maxLines: 5,
              spellCheckConfiguration: hunspellSpellCheckConfiguration,
              contextMenuBuilder: spellCheckContextMenuBuilder,
            ),
            const SizedBox(height: 16),

            // Due Date
            ListTile(
              title: const Text('Due Date'),
              subtitle: Text(_dueDate == null
                  ? 'No due date'
                  : '${_dueDate!.toLocal()}'.split(' ')[0]),
              trailing: const Icon(Icons.calendar_today),
              onTap: _pickDueDate,
            ),
            const SizedBox(height: 16),

            // Files Section
            /* Text(
              'Attached Files',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _fileController,
                    decoration: InputDecoration(
                      hintText: 'Add file path',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _addFile,
                  child: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Column(
              children: _files
                  .map(
                    (file) => ListTile(
                      leading: const Icon(Icons.attach_file),
                      title: Text(file),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => _removeFile(file),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16), */

            // Lists Selection
            Text(
              'Add to Lists',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            if (_availableLists.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  'No lists created yet',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _availableLists.map((list) {
                  final isSelected = _selectedListIds.contains(list.id);
                  return FilterChip(
                    label: Text(list.name),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedListIds.add(list.id);
                        } else {
                          _selectedListIds.remove(list.id);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            const SizedBox(height: 32),

            if (existingTask != null) ...[
              const SizedBox(height: 24),
              Text(
                'History',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (historyEntries.isEmpty)
                Text(
                  'No recorded changes yet',
                  style: Theme.of(context).textTheme.bodySmall,
                )
              else
                ...historyEntries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          entry.label,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        Text(
                          dateFormatter.format(entry.timestamp.toLocal()),
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                  color: Theme.of(context).colorScheme.outline),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ],
        ),
      ),
    );
  }
}

class _HistoryEntry {
  final String label;
  final DateTime timestamp;

  _HistoryEntry(this.label, this.timestamp);
}
