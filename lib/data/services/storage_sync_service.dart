import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as path;

class StorageSyncService {
  final FirebaseStorage _storage;

  // Max file size: 10MB
  static const int maxFileSize = 10 * 1024 * 1024;

  StorageSyncService({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  Future<String> uploadFile({
    required File file,
    required String storagePath,
  }) async {
    try {
      final ref = _storage.ref().child(storagePath);
      debugPrint('SYNC: Starting upload for $storagePath');

      // Optimization: Check if file already exists and is the same size
      try {
        debugPrint('SYNC: Checking if file exists...');
        final metadata = await ref.getMetadata();
        final localSize = await file.length();
        debugPrint(
            'SYNC: Remote size: ${metadata.size}, Local size: $localSize');
        if (metadata.size == localSize) {
          debugPrint(
              'SYNC: File $storagePath already exists with same size. Skipping upload.');
          return storagePath;
        }
      } catch (e) {
        // File doesn't exist or error getting metadata, proceed with upload
        debugPrint('SYNC: File check failed (expected if new): $e');
      }

      // 1. Validate file size
      final int sizeInBytes = await file.length();
      if (sizeInBytes > maxFileSize) {
        throw Exception('File is too large. Max size is 10MB.');
      }

      // 2. Validate file type (Images only for now)
      final extension = path.extension(file.path).toLowerCase();
      if (!['.jpg', '.jpeg', '.png', '.webp'].contains(extension)) {
        throw Exception(
            'Unsupported file type. Only JPG, PNG, and WebP are supported.');
      }

      // 3. Compress image
      final compressedFile = await _compressImage(file);
      final fileToUpload =
          compressedFile != null ? File(compressedFile.path) : file;

      if (compressedFile == null) {
        debugPrint(
            'SYNC: Warning: Compression failed or skipped, uploading original.');
      }

      final contentType = _getContentType(extension);

      // Windows Workaround: Use REST API directly to avoid plugin threading issues
      if (defaultTargetPlatform == TargetPlatform.windows) {
        debugPrint('SYNC: Using REST API fallback for Windows upload...');
        await _uploadViaRestApi(fileToUpload, storagePath, contentType);
      } else {
        // Standard Plugin Upload for other platforms
        final metadata = SettableMetadata(
          contentType: contentType,
          customMetadata: {
            'originalName': path.basename(file.path),
            'uploadedAt': DateTime.now().toIso8601String(),
          },
        );

        debugPrint('SYNC: Reading file bytes...');
        final bytes = await fileToUpload.readAsBytes();
        debugPrint('SYNC: Uploading ${bytes.length} bytes via Plugin...');

        await ref.putData(bytes, metadata);
      }

      debugPrint('SYNC: Upload complete.');

      // Clean up compressed file
      try {
        if (compressedFile != null && compressedFile.path != file.path) {
          File(compressedFile.path).delete().ignore();
        }
      } catch (e) {
        debugPrint('Error deleting temp file: $e');
      }

      return storagePath;
    } catch (e) {
      debugPrint('Error uploading file: $e');
      rethrow;
    }
  }

  Future<void> _uploadViaRestApi(
      File file, String storagePath, String contentType) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not logged in');

    final token = await user.getIdToken();
    var bucket = _storage.bucket;
    if (bucket.startsWith('gs://')) {
      bucket = bucket.substring(5);
    }

    // Probe buckets to find the correct one
    final candidates = [
      bucket, // Configured bucket
      bucket.replaceAll('.firebasestorage.app', '.appspot.com'), // Legacy
      bucket.split('.').first, // Project ID only?
      'qtask-backend-service-c667a2.appspot.com', // Hardcoded fallback
    ];

    String? validBucket;
    for (final candidate in candidates) {
      if (candidate.isEmpty) continue;
      debugPrint('SYNC: Probing bucket: $candidate');
      if (await _probeBucket(candidate, token!)) {
        debugPrint('SYNC: Found valid bucket: $candidate');
        validBucket = candidate;
        break;
      }
    }

    if (validBucket == null) {
      debugPrint(
          'SYNC: Could not find any valid bucket. Defaulting to configured: $bucket');
      validBucket = bucket;
    }

    try {
      await _performRestUpload(
          file, validBucket, storagePath, contentType, token!);
    } catch (e) {
      debugPrint('SYNC: Upload failed to $validBucket: $e');
      rethrow;
    }
  }

  Future<bool> _probeBucket(String bucket, String token) async {
    try {
      final url = Uri.parse(
          'https://firebasestorage.googleapis.com/v0/b/$bucket/o?maxResults=1');
      final client = HttpClient();
      final request = await client.getUrl(url);
      request.headers.add(HttpHeaders.authorizationHeader, 'Bearer $token');
      final response = await request.close();

      // 200 = OK, 401/403 = Exists but auth error (good enough for existence check), 404 = Not Found
      debugPrint('SYNC: Probe $bucket returned ${response.statusCode}');
      return response.statusCode != 404;
    } catch (e) {
      debugPrint('SYNC: Probe failed for $bucket: $e');
      return false;
    }
  }

  Future<void> _performRestUpload(File file, String bucket, String storagePath,
      String contentType, String token) async {
    // Encode path: / becomes %2F
    final encodedPath = Uri.encodeComponent(storagePath);

    final url = Uri.parse(
        'https://firebasestorage.googleapis.com/v0/b/$bucket/o?name=$encodedPath');

    debugPrint('SYNC: REST URL: $url');

    final bytes = await file.readAsBytes();

    final client = HttpClient();
    final request = await client.postUrl(url);

    request.headers.add(HttpHeaders.authorizationHeader, 'Bearer $token');
    request.headers.contentType = ContentType.parse(contentType);
    request.contentLength = bytes.length;

    request.add(bytes);

    final response = await request.close();

    if (response.statusCode != 200) {
      final responseBody =
          await response.transform(SystemEncoding().decoder).join();
      throw Exception(
          'REST Upload failed: ${response.statusCode} - $responseBody');
    }

    debugPrint('SYNC: REST Upload Success: ${response.statusCode}');
  }

  Future<File> downloadFile({
    required String storagePath,
    required String localPath,
  }) async {
    final file = File(localPath);

    // Check if already exists
    if (await file.exists()) {
      return file;
    }

    // Ensure directory exists
    await file.parent.create(recursive: true);

    try {
      final ref = _storage.ref().child(storagePath);
      await ref.writeToFile(file);
      return file;
    } catch (e) {
      debugPrint('Error downloading file: $e');
      rethrow;
    }
  }

  Future<void> deleteFile(String storagePath) async {
    try {
      await _storage.ref().child(storagePath).delete();
    } catch (e) {
      debugPrint('Error deleting file from storage: $e');
      // Don't rethrow if it's just "object not found"
    }
  }

  Future<XFile?> _compressImage(File file) async {
    final filePath = file.path;
    final extension = path.extension(filePath);
    final basename = path.basenameWithoutExtension(filePath);
    final dir = path.dirname(filePath);
    final outPath = path.join(dir, '${basename}_out$extension');

    try {
      // Check if platform supports compression (Windows/Linux/MacOS often don't with this package)
      if (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS) {
        debugPrint('SYNC: Skipping compression on desktop platform.');
        return XFile(file.path);
      }

      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        outPath,
        quality: 85,
        minWidth: 1920,
        minHeight: 1920,
      );

      if (result == null) {
        debugPrint('SYNC: Compression returned null, using original file.');
        return XFile(file.path);
      }

      return result;
    } catch (e) {
      debugPrint('SYNC: Compression failed: $e. Using original file.');
      // Fallback to original file
      return XFile(file.path);
    }
  }

  String _getContentType(String extension) {
    switch (extension) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.webp':
        return 'image/webp';
      default:
        return 'application/octet-stream';
    }
  }
}
