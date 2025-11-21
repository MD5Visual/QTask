import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class SettingsModel {
  final int primaryColor;
  final double baseFontSize;
  final double basePadding;
  final double baseSpacing;
  final double cornerRadius;
  final bool? isDarkMode; // null = system
  final int fuzzySearchTolerance;
  final String? customDataPath;
  final String? macosBookmark;

  const SettingsModel({
    this.primaryColor = 0xFF3F51B5,
    this.baseFontSize = 16.0,
    this.basePadding = 16.0,
    this.baseSpacing = 8.0,
    this.cornerRadius = 8.0,
    this.isDarkMode,
    this.fuzzySearchTolerance = 2,
    this.customDataPath,
    this.macosBookmark,
  });

  SettingsModel copyWith({
    int? primaryColor,
    double? baseFontSize,
    double? basePadding,
    double? baseSpacing,
    double? cornerRadius,
    bool? isDarkMode,
    bool forceDarkModeNull = false,
    int? fuzzySearchTolerance,
    String? customDataPath,
    bool forceCustomDataPathNull = false,
    String? macosBookmark,
    bool forceMacosBookmarkNull = false,
  }) {
    return SettingsModel(
      primaryColor: primaryColor ?? this.primaryColor,
      baseFontSize: baseFontSize ?? this.baseFontSize,
      basePadding: basePadding ?? this.basePadding,
      baseSpacing: baseSpacing ?? this.baseSpacing,
      cornerRadius: cornerRadius ?? this.cornerRadius,
      isDarkMode: forceDarkModeNull ? null : (isDarkMode ?? this.isDarkMode),
      fuzzySearchTolerance: fuzzySearchTolerance ?? this.fuzzySearchTolerance,
      customDataPath: forceCustomDataPathNull
          ? null
          : (customDataPath ?? this.customDataPath),
      macosBookmark:
          forceMacosBookmarkNull ? null : (macosBookmark ?? this.macosBookmark),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'primaryColor': primaryColor,
      'baseFontSize': baseFontSize,
      'basePadding': basePadding,
      'baseSpacing': baseSpacing,
      'cornerRadius': cornerRadius,
      'isDarkMode': isDarkMode,
      'fuzzySearchTolerance': fuzzySearchTolerance,
      'customDataPath': customDataPath,
      'macosBookmark': macosBookmark,
    };
  }

  factory SettingsModel.fromJson(Map<String, dynamic> json) {
    return SettingsModel(
      primaryColor: json['primaryColor'] ?? 0xFF3F51B5,
      baseFontSize: (json['baseFontSize'] ?? 16.0).toDouble(),
      basePadding: (json['basePadding'] ?? 16.0).toDouble(),
      baseSpacing: (json['baseSpacing'] ?? 8.0).toDouble(),
      cornerRadius: (json['cornerRadius'] ?? 8.0).toDouble(),
      isDarkMode: json['isDarkMode'],
      fuzzySearchTolerance: json['fuzzySearchTolerance'] ?? 2,
      customDataPath: json['customDataPath'],
      macosBookmark: json['macosBookmark'],
    );
  }
}

class SettingsProvider extends ChangeNotifier {
  SettingsModel _settings = const SettingsModel();

  SettingsModel get settings => _settings;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> loadSettings() async {
    await _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/settings.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        final json = jsonDecode(content);
        _settings = SettingsModel.fromJson(json);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }
  }

  Future<void> _saveSettings() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/settings.json');
      final json = _settings.toJson();
      await file.writeAsString(jsonEncode(json));
    } catch (e) {
      debugPrint('Error saving settings: $e');
    }
  }

  void updateSettings(SettingsModel newSettings) {
    _settings = newSettings;
    _saveSettings();
    notifyListeners();
  }

  Future<void> importSettings(String jsonString) async {
    try {
      final json = jsonDecode(jsonString);
      _settings = SettingsModel.fromJson(json);
      await _saveSettings();
      notifyListeners();
    } catch (e) {
      debugPrint('Error importing settings: $e');
      rethrow;
    }
  }

  String exportSettings() {
    return jsonEncode(_settings.toJson());
  }
}
