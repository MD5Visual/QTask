import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:provider/provider.dart';
import 'package:q_task/presentation/providers/settings_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings & Debug'),
      ),
      body: Consumer<SettingsProvider>(
        builder: (context, provider, child) {
          final settings = provider.settings;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildSectionHeader(context, 'Appearance'),
              ListTile(
                title: const Text('Theme Mode'),
                subtitle: Text(
                  settings.isDarkMode == null
                      ? 'System Default'
                      : (settings.isDarkMode! ? 'Dark' : 'Light'),
                ),
                trailing: DropdownButton<bool?>(
                  value: settings.isDarkMode,
                  items: const [
                    DropdownMenuItem(value: null, child: Text('System')),
                    DropdownMenuItem(value: false, child: Text('Light')),
                    DropdownMenuItem(value: true, child: Text('Dark')),
                  ],
                  onChanged: (value) {
                    provider.updateSettings(
                      settings.copyWith(
                        isDarkMode: value,
                        forceDarkModeNull: value == null,
                      ),
                    );
                  },
                ),
              ),
              ListTile(
                title: const Text('Primary Color'),
                trailing: CircleAvatar(
                  backgroundColor: Color(settings.primaryColor),
                ),
                onTap: () => _showColorPicker(context, provider),
              ),
              const Divider(),
              _buildSectionHeader(context, 'Sizing & Spacing'),
              _buildSlider(
                context,
                'Base Font Size',
                settings.baseFontSize,
                10.0,
                32.0,
                (value) => provider
                    .updateSettings(settings.copyWith(baseFontSize: value)),
              ),
              _buildSlider(
                context,
                'Base Padding',
                settings.basePadding,
                0.0,
                48.0,
                (value) => provider
                    .updateSettings(settings.copyWith(basePadding: value)),
              ),
              _buildSlider(
                context,
                'Base Spacing',
                settings.baseSpacing,
                0.0,
                48.0,
                (value) => provider
                    .updateSettings(settings.copyWith(baseSpacing: value)),
              ),
              _buildSlider(
                context,
                'Corner Radius',
                settings.cornerRadius,
                0.0,
                32.0,
                (value) => provider
                    .updateSettings(settings.copyWith(cornerRadius: value)),
              ),
              const Divider(),
              _buildSectionHeader(context, 'Search'),
              _SettingsSliderRow(
                label: 'Fuzzy Search Tolerance',
                value: settings.fuzzySearchTolerance.toDouble(),
                min: 0.0,
                max: 5.0,
                onChanged: (value) => provider.updateSettings(
                    settings.copyWith(fuzzySearchTolerance: value.toInt())),
              ),
              const Divider(),
              _buildSectionHeader(context, 'Data Management'),
              ListTile(
                leading: const Icon(Icons.upload),
                title: const Text('Export Settings'),
                subtitle: const Text('Copy settings JSON to clipboard'),
                onTap: () {
                  final json = provider.exportSettings();
                  Clipboard.setData(ClipboardData(text: json));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Settings copied to clipboard')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.download),
                title: const Text('Import Settings'),
                subtitle: const Text('Paste settings JSON from clipboard'),
                onTap: () async {
                  final data = await Clipboard.getData(Clipboard.kTextPlain);
                  if (data?.text != null && context.mounted) {
                    try {
                      await provider.importSettings(data!.text!);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Settings imported')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Invalid JSON: $e')),
                        );
                      }
                    }
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  Widget _buildSlider(
    BuildContext context,
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    return _SettingsSliderRow(
      label: label,
      value: value,
      min: min,
      max: max,
      onChanged: onChanged,
    );
  }

  void _showColorPicker(BuildContext context, SettingsProvider provider) {
    showDialog(
      context: context,
      builder: (context) {
        Color pickerColor = Color(provider.settings.primaryColor);
        return AlertDialog(
          title: const Text('Pick a color'),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: pickerColor,
              onColorChanged: (color) {
                pickerColor = color;
              },
              labelTypes: ColorLabelType.values,
              pickerAreaHeightPercent: 0.8,
            ),
          ),
          actions: <Widget>[
            ElevatedButton(
              child: const Text('Got it'),
              onPressed: () {
                provider.updateSettings(
                  provider.settings
                      .copyWith(primaryColor: pickerColor.toARGB32()),
                );
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}

class _SettingsSliderRow extends StatefulWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  const _SettingsSliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  State<_SettingsSliderRow> createState() => _SettingsSliderRowState();
}

class _SettingsSliderRowState extends State<_SettingsSliderRow> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value.toStringAsFixed(2));
  }

  @override
  void didUpdateWidget(covariant _SettingsSliderRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      // Only update text if the value change didn't come from the text field itself
      // (checked by comparing parsed text value with new value, allowing for small precision diffs)
      final textValue = double.tryParse(_controller.text);
      if (textValue == null || (textValue - widget.value).abs() > 0.01) {
        _controller.text = widget.value.toStringAsFixed(2);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTextChange(String value) {
    final newValue = double.tryParse(value);
    if (newValue != null) {
      final clampedValue = newValue.clamp(widget.min, widget.max);
      widget.onChanged(clampedValue);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(widget.label),
              SizedBox(
                width: 60,
                child: TextField(
                  controller: _controller,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.end,
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                    border: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    enabledBorder: InputBorder.none,
                  ),
                  onSubmitted: _handleTextChange,
                  onEditingComplete: () {
                    _handleTextChange(_controller.text);
                    FocusScope.of(context).unfocus();
                  },
                ),
              ),
            ],
          ),
        ),
        Slider(
          value: widget.value,
          min: widget.min,
          max: widget.max,
          onChanged: widget.onChanged,
        ),
      ],
    );
  }
}
