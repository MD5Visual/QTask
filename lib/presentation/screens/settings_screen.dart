import 'dart:io';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:path/path.dart' as path;
import 'package:provider/provider.dart';
import 'package:q_task/data/services/backup_service.dart';
import 'package:q_task/data/services/storage_service.dart';
import 'package:q_task/presentation/providers/settings_provider.dart';
import 'package:q_task/presentation/providers/auth_provider.dart';
import 'package:macos_secure_bookmarks/macos_secure_bookmarks.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';

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
              _buildSectionHeader(context, 'Cloud Sync'),
              SwitchListTile(
                title: const Text('Enable Cloud Sync'),
                subtitle:
                    const Text('Sync tasks across devices using Firebase'),
                value: settings.isSyncEnabled,
                onChanged: (value) {
                  provider
                      .updateSettings(settings.copyWith(isSyncEnabled: value));
                },
              ),
              if (settings.isSyncEnabled) ...[
                Consumer<AuthProvider>(
                  builder: (context, auth, _) {
                    if (auth.isAuthenticated) {
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: auth.user?.photoURL != null
                              ? NetworkImage(auth.user!.photoURL!)
                              : null,
                          child: auth.user?.photoURL == null
                              ? const Icon(Icons.person)
                              : null,
                        ),
                        title: Text(auth.user?.displayName ?? 'User'),
                        subtitle: Text(auth.user?.email ?? ''),
                        trailing: TextButton(
                          onPressed: () => auth.signOut(),
                          child: const Text('Sign Out'),
                        ),
                      );
                    } else {
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 8.0),
                        child: FilledButton.icon(
                          icon: const Icon(Icons.login),
                          label: const Text('Sign in with Google'),
                          onPressed: () async {
                            try {
                              await auth.signInWithGoogle();
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Login failed: $e')),
                                );
                              }
                            }
                          },
                        ),
                      );
                    }
                  },
                ),
              ],
              const Divider(),
              _buildSectionHeader(context, 'Data & Storage'),
              FutureBuilder<Directory>(
                future: context.read<StorageService>().getRootDirectory(),
                builder: (context, snapshot) {
                  final path = snapshot.data?.path ?? 'Loading...';
                  final isDefault = provider.settings.customDataPath == null;

                  return Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.folder_open),
                        title: const Text('Storage Location'),
                        subtitle: Text(isDefault
                            ? 'Default (Sandboxed)\n$path'
                            : 'Custom\n$path'),
                        isThreeLine: true,
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _pickStorageLocation(context, provider),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.open_in_new),
                                label: const Text('Open Data Folder'),
                                onPressed: snapshot.hasData
                                    ? () => _openDataFolder(snapshot.data!.path)
                                    : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.download),
                title: const Text('Export Data'),
                subtitle:
                    const Text('Save all tasks and settings to a zip file'),
                onTap: () async {
                  try {
                    final backupService = context.read<BackupService>();
                    final backupPath = await backupService.createBackup();

                    // Platform-specific export logic
                    if (Platform.isAndroid || Platform.isIOS) {
                      await Share.shareXFiles([XFile(backupPath)]);
                    } else {
                      // Desktop: Prompt user to save the file
                      final fileName = path.basename(backupPath);
                      final saveLocation = await getSaveLocation(
                        suggestedName: fileName,
                        acceptedTypeGroups: [
                          const XTypeGroup(
                            label: 'Zip',
                            extensions: ['zip'],
                          ),
                        ],
                      );

                      if (saveLocation != null) {
                        final file = File(backupPath);
                        await file.copy(saveLocation.path);
                        // Cleanup temp file
                        await file.delete();

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content:
                                    Text('Exported to ${saveLocation.path}')),
                          );
                        }
                      } else {
                        // User cancelled, cleanup
                        await File(backupPath).delete();
                      }
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Export failed: $e')),
                      );
                    }
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.upload),
                title: const Text('Import Data'),
                subtitle: const Text('Restore from a backup zip file'),
                onTap: () async {
                  const typeGroup = XTypeGroup(
                    label: 'Zip',
                    extensions: ['zip'],
                  );
                  final file = await openFile(acceptedTypeGroups: [typeGroup]);

                  if (file != null && context.mounted) {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Confirm Import'),
                        content: const Text(
                          'This will overwrite all current data with the backup content. Are you sure?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Import'),
                          ),
                        ],
                      ),
                    );

                    if (confirmed == true && context.mounted) {
                      try {
                        final backupService = context.read<BackupService>();
                        await backupService.restoreBackup(file.path);

                        // Reload settings
                        if (context.mounted) {
                          await provider.loadSettings();

                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (context) => AlertDialog(
                              title: const Text('Import Successful'),
                              content: const Text(
                                'Data restored successfully. The app needs to restart to apply all changes.',
                              ),
                              actions: [
                                FilledButton(
                                  onPressed: () {
                                    // In a real app we might restart, here we just close dialog
                                    // and maybe navigate home or let user manually restart if needed.
                                    // For Flutter desktop, we can't easily "restart" programmatically
                                    // without external help, but reloading providers helps.
                                    Navigator.pop(context);
                                  },
                                  child: const Text('OK'),
                                ),
                              ],
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Import failed: $e')),
                          );
                        }
                      }
                    }
                  }
                },
              ),
              const Divider(),
              _buildSectionHeader(context, 'Advanced'),
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

  Future<void> _pickStorageLocation(
      BuildContext context, SettingsProvider provider) async {
    final String? directoryPath = await getDirectoryPath();
    if (directoryPath != null) {
      // Confirm change
      if (context.mounted) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Change Storage Location'),
            content: Text(
              'This will change where your data is saved to:\n$directoryPath\n\n'
              'Existing data will NOT be moved automatically. You will start with an empty workspace in the new location.\n\n'
              'Are you sure?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Change'),
              ),
            ],
          ),
        );

        if (confirmed == true) {
          String? bookmark;
          if (Platform.isMacOS) {
            try {
              final secureBookmarks = SecureBookmarks();
              bookmark = await secureBookmarks.bookmark(File(directoryPath));
            } catch (e) {
              debugPrint('Failed to create bookmark: $e');
            }
          }

          provider.updateSettings(
            provider.settings.copyWith(
              customDataPath: directoryPath,
              macosBookmark: bookmark,
              forceMacosBookmarkNull: bookmark == null,
            ),
          );

          if (context.mounted) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => AlertDialog(
                title: const Text('Location Changed'),
                content: const Text(
                  'Storage location updated. Please restart the app to apply changes.',
                ),
                actions: [
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          }
        }
      }
    }
  }

  Future<void> _openDataFolder(String path) async {
    final uri = Uri.directory(path);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      debugPrint('Could not launch $uri');
    }
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
