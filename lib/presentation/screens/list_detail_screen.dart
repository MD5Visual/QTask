import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:q_task/domain/models/task_list.dart';
import 'package:q_task/presentation/theme/outline_styles.dart';
import 'package:q_task/presentation/services/hunspell_spell_check_service.dart';

class ListDetailScreen extends StatefulWidget {
  final TaskList? list;

  const ListDetailScreen({this.list, super.key});

  @override
  State<ListDetailScreen> createState() => _ListDetailScreenState();
}

class _ListDetailScreenState extends State<ListDetailScreen> {
  late TextEditingController _nameController;
  late Color _selectedColor;
  late bool _isHidden;

  static const List<Color> _colorOptions = [
    Color(0xFF3F51B5),
    Color(0xFF2196F3),
    Color(0xFF00BCD4),
    Color(0xFF009688),
    Color(0xFF4CAF50),
    Color(0xFF8BC34A),
    Color(0xFFFFC107),
    Color(0xFFFF9800),
    Color(0xFFFF5722),
    Color(0xFFE91E63),
    Color(0xFF9C27B0),
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.list?.name ?? '');
    _selectedColor = widget.list != null
        ? Color(int.parse('0xFF${widget.list!.color.replaceFirst('#', '')}'))
        : _colorOptions.first;
    _isHidden = widget.list?.isHidden ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _saveList() {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a list name')),
      );
      return;
    }

    final colorHex =
        '#${_selectedColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

    final updatedList = TaskList(
      id: widget.list?.id,
      name: _nameController.text,
      color: colorHex,
      createdAt: widget.list?.createdAt,
      position: widget.list?.position ?? 0,
      isHidden: _isHidden,
    );

    Navigator.of(context).pop(updatedList);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.list == null ? 'New List' : 'Edit List'),
        elevation: 0,
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saveList,
              child: Text(widget.list == null ? 'Create List' : 'Update List'),
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Name
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'List Name',
              hintText: 'Enter list name',
              border: OutlineStyles.inputBorder(),
            ),
            style: Theme.of(context).textTheme.titleLarge,
            spellCheckConfiguration: hunspellSpellCheckConfiguration,
            contextMenuBuilder: spellCheckContextMenuBuilder,
          ),
          const SizedBox(height: 24),

          // Color Selection
          Text(
            'List Color',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              ..._colorOptions.map((color) {
                final isSelected =
                    color.toARGB32() == _selectedColor.toARGB32();
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedColor = color;
                    });
                  },
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(color: Colors.white, width: 4)
                          : null,
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: color.withValues(alpha: 0.5),
                                blurRadius: 8,
                                spreadRadius: 2,
                              )
                            ]
                          : null,
                    ),
                  ),
                );
              }),
              // Custom Color Button
              GestureDetector(
                onTap: _showCustomColorPicker,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _isCustomColor(_selectedColor)
                          ? _selectedColor
                          : Theme.of(context).dividerColor,
                      width: _isCustomColor(_selectedColor) ? 4 : 2,
                    ),
                  ),
                  child: Icon(
                    Icons.add,
                    color: _isCustomColor(_selectedColor)
                        ? _selectedColor
                        : Theme.of(context).iconTheme.color,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool _isCustomColor(Color color) {
    return !_colorOptions.any((c) => c.toARGB32() == color.toARGB32());
  }

  void _showCustomColorPicker() {
    showDialog(
      context: context,
      builder: (context) {
        Color pickerColor = _selectedColor;
        return AlertDialog(
          title: const Text('Pick a color'),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: pickerColor,
              onColorChanged: (color) {
                pickerColor = color;
              },
              enableAlpha: false,
              labelTypes: ColorLabelType.values,
              paletteType: PaletteType.hsv,
              pickerAreaHeightPercent: 0.8,
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            FilledButton(
              child: const Text('Select'),
              onPressed: () {
                setState(() {
                  _selectedColor = pickerColor;
                });
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
