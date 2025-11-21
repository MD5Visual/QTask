import 'package:cross_file/cross_file.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';
import 'package:intl/intl.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:markdown_quill/markdown_quill.dart';
import 'package:q_task/data/services/attachment_service.dart';
import 'package:q_task/domain/models/task.dart';
import 'package:q_task/domain/models/task_list.dart';
import 'package:q_task/presentation/theme/outline_styles.dart';
import 'package:q_task/presentation/services/hunspell_spell_check_service.dart';

class RichTaskDetailScreen extends StatefulWidget {
  final Task? task;
  final List<TaskList> availableLists;

  const RichTaskDetailScreen(
      {this.task, this.availableLists = const [], super.key});

  @override
  State<RichTaskDetailScreen> createState() => _RichTaskDetailScreenState();
}

class _RichTaskDetailScreenState extends State<RichTaskDetailScreen> {
  late TextEditingController _titleController;
  late quill.QuillController _quillController;
  final AttachmentService _attachmentService = AttachmentService();

  List<String> _selectedListIds = [];
  List<TaskList> _availableLists = [];
  DateTime? _dueDate;
  final FocusNode _editorFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task?.title ?? '');

    final markdown = widget.task?.description ?? '';
    var delta =
        MarkdownToDelta(markdownDocument: md.Document()).convert(markdown);
    if (delta.isEmpty) {
      delta = quill.Document().toDelta();
    }

    // Fix for Windows file paths being URL encoded by markdown_quill
    for (final op in delta.toList()) {
      if (op.data is Map && (op.data as Map).containsKey('image')) {
        final imagePath = (op.data as Map)['image'] as String;
        if (imagePath.contains('%')) {
          (op.data as Map)['image'] = Uri.decodeFull(imagePath);
        }
      }
    }

    _quillController = quill.QuillController(
      document: quill.Document.fromDelta(delta),
      selection: const TextSelection.collapsed(offset: 0),
    );

    _selectedListIds = List.from(widget.task?.listIds ?? []);
    _dueDate = widget.task?.dueDate;
    _availableLists = widget.availableLists;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _quillController.dispose();
    _editorFocusNode.dispose();
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

  Future<void> _saveTask() async {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a task title')),
      );
      return;
    }

    final delta = _quillController.document.toDelta();
    final markdown = DeltaToMarkdown().convert(delta);

    final updatedTask = Task(
      id: widget.task?.id,
      title: _titleController.text,
      description: markdown,
      tags: widget.task?.tags ?? [],
      attachedFiles: widget.task?.attachedFiles ?? [],
      dueDate: _dueDate,
      createdAt: widget.task?.createdAt,
      completedAt: widget.task?.completedAt,
      listIds: _selectedListIds,
      position: widget.task?.position ?? 0,
      isCompleted: widget.task?.isCompleted ?? false,
    );

    Navigator.of(context).pop(updatedTask);
  }

  Future<void> _handleDrop(List<XFile> files) async {
    final taskId = widget.task?.id ??
        'temp_${DateTime.now().millisecondsSinceEpoch}'; // Handle new task case better in real app

    for (final file in files) {
      final ext = file.name.split('.').last.toLowerCase();
      if (['png', 'jpg', 'jpeg', 'gif', 'webp'].contains(ext)) {
        final savedPath = await _attachmentService.saveAttachment(taskId, file);

        final index = _quillController.selection.baseOffset;
        final length = _quillController.selection.extentOffset - index;

        _quillController.replaceText(
          index,
          length,
          quill.BlockEmbed.image(savedPath),
          null,
        );

        // Move cursor after image
        _quillController.moveCursorToPosition(index + 1);
      }
    }
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
      body: DropTarget(
        onDragDone: (detail) => _handleDrop(detail.files),
        child: SingleChildScrollView(
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
              ),
              const SizedBox(height: 16),

              // Rich Text Description
              Text('Description',
                  style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  border:
                      Border.all(color: Theme.of(context).colorScheme.outline),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  children: [
                    quill.QuillSimpleToolbar(
                      controller: _quillController,
                      config: const quill.QuillSimpleToolbarConfig(
                        showFontFamily: false,
                        showFontSize: false,
                        showSearchButton: false,
                        showSubscript: false,
                        showSuperscript: false,
                      ),
                    ),
                    const Divider(height: 1),
                    SizedBox(
                      height: 300, // Fixed height for editor
                      child: quill.QuillEditor.basic(
                        controller: _quillController,
                        focusNode: _editorFocusNode,
                        config: quill.QuillEditorConfig(
                          padding: const EdgeInsets.all(8),
                          placeholder: 'Enter task description...',
                          embedBuilders: FlutterQuillEmbeds.editorBuilders(),
                        ),
                      ),
                    ),
                  ],
                ),
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
                                    color:
                                        Theme.of(context).colorScheme.outline),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ],
          ),
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
