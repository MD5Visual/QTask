import 'package:cross_file/cross_file.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:markdown_quill/markdown_quill.dart';
import 'package:provider/provider.dart';
import 'package:q_task/data/services/attachment_service.dart';
import 'package:q_task/domain/models/task.dart';
import 'package:q_task/domain/models/task_list.dart';
import 'package:q_task/presentation/theme/outline_styles.dart';
import 'package:q_task/presentation/services/hunspell_spell_check_service.dart';
import 'package:q_task/data/services/history_service.dart';
import 'package:q_task/domain/models/history_item.dart';

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

  List<String> _selectedListIds = [];
  List<TaskList> _availableLists = [];
  DateTime? _dueDate;
  final FocusNode _editorFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task?.title ?? '');

    final markdown = widget.task?.description ?? '';
    var delta = MarkdownToDelta(
      markdownDocument: md.Document(
        extensionSet: md.ExtensionSet.gitHubFlavored,
        encodeHtml: false,
      ),
    ).convert(markdown);
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

    // Extract image paths from delta
    final attachedFiles = <String>[];
    for (final op in delta.toList()) {
      if (op.data is Map && (op.data as Map).containsKey('image')) {
        final imagePath = (op.data as Map)['image'] as String;
        attachedFiles.add(imagePath);
      }
    }

    final updatedTask = Task(
      id: widget.task?.id,
      title: _titleController.text,
      description: markdown,
      tags: widget.task?.tags ?? [],
      attachedFiles: attachedFiles,
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
    final attachmentService = context.read<AttachmentService>();
    final taskId =
        widget.task?.id ?? DateTime.now().millisecondsSinceEpoch.toString();
    // Note: If it's a new task, we might be saving attachments to a temp ID.
    // Real implementation should handle this better, but for now we use a generated ID.

    for (final file in files) {
      final ext = file.name.split('.').last.toLowerCase();

      // 1. Block GIFs explicitly
      if (ext == 'gif') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('GIFs are not supported yet: ${file.name}')),
          );
        }
        continue;
      }

      // 2. Check supported types
      if (!['png', 'jpg', 'jpeg', 'webp'].contains(ext)) {
        continue;
      }

      // 3. Check file size (10MB limit)
      final size = await file.length();
      if (size > 10 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('File too large (max 10MB): ${file.name}')),
          );
        }
        continue;
      }

      final savedPath = await attachmentService.saveAttachment(taskId, file);

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

  @override
  Widget build(BuildContext context) {
    final existingTask = widget.task;
    final dateFormatter = DateFormat.yMMMd().add_jm();

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
            child: FilledButton.icon(
              onPressed: _saveTask,
              icon: const Icon(Icons.save),
              label: const Text('Save Task'),
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
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
                StreamBuilder<List<HistoryItem>>(
                  stream: context
                      .read<HistoryService>()
                      .getHistoryStream(existingTask.id),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Text('Error loading history: ${snapshot.error}');
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final items = snapshot.data!;
                    if (items.isEmpty) {
                      return Text(
                        'No recorded changes yet',
                        style: Theme.of(context).textTheme.bodySmall,
                      );
                    }

                    return Column(
                      children: items.map((item) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _getHistoryActionLabel(item),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    dateFormatter
                                        .format(item.timestamp.toLocal()),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .outline,
                                        ),
                                  ),
                                ],
                              ),
                              if (item.changes.isNotEmpty)
                                Padding(
                                  padding:
                                      const EdgeInsets.only(left: 8.0, top: 2),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: item.changes.entries.map((e) {
                                      return Text(
                                        '• ${e.key}: ${_formatChangeValue(e.value)}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      );
                                    }).toList(),
                                  ),
                                ),
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _getHistoryActionLabel(HistoryItem item) {
    switch (item.action) {
      case HistoryAction.create:
        return 'Task Created';
      case HistoryAction.update:
        return 'Task Updated';
      case HistoryAction.delete:
        return 'Task Deleted';
    }
  }

  String _formatChangeValue(dynamic value) {
    if (value is Map && value.containsKey('old') && value.containsKey('new')) {
      return '${value['old']} -> ${value['new']}';
    }
    return value.toString();
  }
}
