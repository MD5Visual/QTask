// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';

void main() {
  print('Generating build hash...');

  // List of critical files to hash
  final filesToHash = [
    'lib/main.dart',
    'lib/presentation/providers/task_provider.dart',
    'lib/data/repositories/sync_task_repository.dart',
    'lib/data/repositories/markdown_task_repository.dart',
    'lib/data/services/firestore_service.dart',
    'pubspec.yaml',
  ];

  final hashes = <String>[];

  for (final filePath in filesToHash) {
    final file = File(filePath);
    if (file.existsSync()) {
      final contents = file.readAsStringSync();
      final hash =
          sha256.convert(utf8.encode(contents)).toString().substring(0, 8);
      hashes.add(hash);
      print('  $filePath: $hash');
    } else {
      print('  WARNING: $filePath not found');
    }
  }

  // Combine all hashes
  final combinedHash =
      sha256.convert(utf8.encode(hashes.join())).toString().substring(0, 12);
  final timestamp = DateTime.now().toIso8601String();

  print('\nBuild Hash: $combinedHash');
  print('Generated at: $timestamp\n');

  // Generate Dart file
  final output = '''
// GENERATED FILE - DO NOT EDIT
// Generated at: $timestamp

class BuildInfo {
  static const String buildHash = '$combinedHash';
  static const String buildTime = '$timestamp';
  
  static String get displayHash => buildHash.toUpperCase();
  static String get shortHash => buildHash.substring(0, 6).toUpperCase();
}
''';

  final outputFile = File('lib/generated/build_info.dart');
  outputFile.createSync(recursive: true);
  outputFile.writeAsStringSync(output);

  print('Generated: lib/generated/build_info.dart');
}
