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
  bool _isToolbarVisible = false;

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

    for (final file in files) {
      final ext = file.name.split('.').last.toLowerCase();

      if (ext == 'gif') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('GIFs are not supported yet: ${file.name}')),
          );
        }
        continue;
      }

      if (!['png', 'jpg', 'jpeg', 'webp'].contains(ext)) {
        continue;
      }

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

      _quillController.moveCursorToPosition(index + 1);
    }
  }

  void _showListSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Select Lists'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView(
                  shrinkWrap: true,
                  children: _availableLists.map((list) {
                    final isSelected = _selectedListIds.contains(list.id);
                    return CheckboxListTile(
                      title: Text(list.name),
                      value: isSelected,
                      onChanged: (bool? value) {
                        setState(() {
                          if (value == true) {
                            _selectedListIds.add(list.id);
                          } else {
                            _selectedListIds.remove(list.id);
                          }
                        });
                        // Update the parent state as well so the UI reflects changes immediately
                        this.setState(() {});
                      },
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Done'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
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
      body: DefaultTabController(
        length: 1,
        child: DropTarget(
          onDragDone: (detail) => _handleDrop(detail.files),
          child: Column(
            children: [
              // Title Section (Always visible)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: TextField(
                  controller: _titleController,
                  autofocus: widget.task == null,
                  decoration: InputDecoration(
                    labelText: 'Task Title',
                    hintText: 'Enter task title',
                    border: OutlineStyles.inputBorder(),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                  ),
                  style: Theme.of(context).textTheme.titleLarge,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _saveTask(),
                  spellCheckConfiguration: hunspellSpellCheckConfiguration,
                  contextMenuBuilder: spellCheckContextMenuBuilder,
                ),
              ),

              // const TabBar(
              //   tabs: [
              //     Tab(text: 'Details'),
              //     Tab(text: 'History'),
              //   ],
              // ),

              Expanded(
                child: _buildDetailsTab(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailsTab() {
    return Column(
      children: [
        // Meta Row: Due Date & Lists
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).dividerColor.withOpacity(0.1),
              ),
            ),
          ),
          child: Row(
            children: [
              // Due Date
              InkWell(
                onTap: _pickDueDate,
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: _dueDate != null
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).iconTheme.color,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _dueDate == null
                            ? 'Due Date'
                            : DateFormat.yMMMd().format(_dueDate!),
                        style: TextStyle(
                          color: _dueDate != null
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).textTheme.bodyMedium?.color,
                          fontWeight: _dueDate != null
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 16),
              Container(
                height: 24,
                width: 1,
                color: Theme.of(context).dividerColor,
              ),
              const SizedBox(width: 16),

              // Lists
              Expanded(
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: _showListSelectionDialog,
                      tooltip: 'Add to List',
                      visualDensity: VisualDensity.compact,
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            ..._availableLists
                                .where((l) => _selectedListIds.contains(l.id))
                                .map((list) => Padding(
                                      padding:
                                          const EdgeInsets.only(right: 8.0),
                                      child: Chip(
                                        label: Text(list.name),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 4, vertical: 2),
                                        backgroundColor: Color(
                                          int.parse(
                                            '0xFF${list.color.replaceFirst('#', '')}',
                                          ),
                                        ),
                                        labelStyle: TextStyle(
                                          color: Color(int.parse(
                                                          '0xFF${list.color.replaceFirst('#', '')}'))
                                                      .computeLuminance() >
                                                  0.5
                                              ? Colors.black
                                              : Colors.white,
                                        ),
                                        visualDensity: VisualDensity.compact,
                                        materialTapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                        deleteIconColor: Color(int.parse(
                                                        '0xFF${list.color.replaceFirst('#', '')}'))
                                                    .computeLuminance() >
                                                0.5
                                            ? Colors.black
                                            : Colors.white,
                                        onDeleted: () {
                                          setState(() {
                                            _selectedListIds.remove(list.id);
                                          });
                                        },
                                      ),
                                    ))
                                .toList(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Toolbar Toggle
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Description',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              IconButton(
                icon: Icon(
                  _isToolbarVisible ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                ),
                onPressed: () {
                  setState(() {
                    _isToolbarVisible = !_isToolbarVisible;
                  });
                },
                tooltip: _isToolbarVisible ? 'Hide Toolbar' : 'Show Toolbar',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),

        // Toolbar
        if (_isToolbarVisible)
          Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).dividerColor,
                ),
              ),
            ),
            child: quill.QuillSimpleToolbar(
              controller: _quillController,
              config: const quill.QuillSimpleToolbarConfig(
                showFontFamily: false,
                showFontSize: false,
                showSearchButton: false,
                showSubscript: false,
                showSuperscript: false,
                toolbarIconAlignment: WrapAlignment.start,
              ),
            ),
          ),

        // Editor
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: quill.QuillEditor.basic(
              controller: _quillController,
              focusNode: _editorFocusNode,
              config: quill.QuillEditorConfig(
                padding: const EdgeInsets.all(8),
                placeholder: 'Enter task description...',
                embedBuilders: FlutterQuillEmbeds.editorBuilders(),
                autoFocus: false,
                expands: true, // Important for taking up space
              ),
            ),
          ),
        ),
      ],
    );
  }
}
