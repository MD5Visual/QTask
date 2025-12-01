import 'dart:async';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:q_task/data/services/firestore_service.dart';
import 'package:q_task/data/services/storage_service.dart';
import 'package:q_task/data/services/storage_sync_service.dart';
import 'package:q_task/domain/models/task.dart';
import 'package:q_task/domain/repositories/i_repository.dart';
import 'package:q_task/presentation/providers/settings_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:q_task/data/services/history_service.dart';
import 'package:q_task/domain/models/history_item.dart';

enum SyncStatus {
  idle,
  syncing,
  error,
  offline,
}

class SyncTaskRepository implements ITaskRepository {
  final ITaskRepository _localRepository;
  final FirestoreService _firestoreService;
  final SettingsProvider _settingsProvider;
  final StorageSyncService _storageSyncService;
  final StorageService _storageService;
  final HistoryService _historyService;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  StreamSubscription<List<Task>>? _firestoreSubscription;
  final _taskStreamController = StreamController<List<Task>>.broadcast();
  StreamSubscription<List<Task>>? _localSubscription;
  StreamSubscription<User?>? _authSubscription;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  final Set<String> _pendingUploads = {};
  final Set<String> _pendingDeletes = {};
  bool _isOnline = true;
  int? _localMetadataVersion; // Cached local version for comparison

  final ValueNotifier<SyncStatus> syncStatus = ValueNotifier(SyncStatus.idle);
  String? _lastSyncError;
  String? get lastSyncError => _lastSyncError;

  SyncTaskRepository(
    this._localRepository,
    this._firestoreService,
    this._settingsProvider,
    this._storageSyncService,
    this._storageService,
    this._historyService,
  ) {
    _init();
  }

  void _init() {
    // Listen to connectivity
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      _isOnline = results.any((result) =>
          result == ConnectivityResult.mobile ||
          result == ConnectivityResult.wifi ||
          result == ConnectivityResult.ethernet);

      if (_isOnline) {
        if (syncStatus.value == SyncStatus.offline) {
          syncStatus.value = SyncStatus.idle;
        }
        _processUploadQueue();
      } else {
        syncStatus.value = SyncStatus.offline;
      }
    });

    // Listen to local changes and forward them
    _localSubscription = _localRepository.watchTasks().listen((tasks) {
      _taskStreamController.add(tasks);
    });

    // Listen to settings changes to enable/disable sync
    _settingsProvider.addListener(_onSettingsChanged);

    // Listen to auth state changes
    _authSubscription = _auth.authStateChanges().listen((_) {
      _onSettingsChanged();
    });

    _onSettingsChanged();
  }

  void dispose() {
    _settingsProvider.removeListener(_onSettingsChanged);
    _firestoreSubscription?.cancel();
    _localSubscription?.cancel();
    _authSubscription?.cancel();
    _connectivitySubscription?.cancel();
    _taskStreamController.close();
  }

  Future<void> _processUploadQueue() async {
    if (_isSyncingLocal) return;

    // Process Deletes first
    if (_pendingDeletes.isNotEmpty) {
      debugPrint(
          'SYNC: Processing offline delete queue: ${_pendingDeletes.length} tasks');
      final deletesToProcess = Set<String>.from(_pendingDeletes);
      for (final taskId in deletesToProcess) {
        try {
          await _firestoreService.deleteTask(taskId);
          _pendingDeletes.remove(taskId);
        } catch (e) {
          debugPrint('SYNC: Failed to sync queued delete for $taskId: $e');
        }
      }
    }

    // Process Uploads
    if (_pendingUploads.isNotEmpty) {
      debugPrint(
          'SYNC: Processing offline upload queue: ${_pendingUploads.length} tasks');
      final tasksToUpload = Set<String>.from(_pendingUploads);

      for (final taskId in tasksToUpload) {
        // If we also have a pending delete for this task, skip upload
        if (_pendingDeletes.contains(taskId)) {
          _pendingUploads.remove(taskId);
          continue;
        }

        try {
          // Check if task still exists locally
          final tasks = await _localRepository.loadTasks();
          try {
            final task = tasks.firstWhere((t) => t.id == taskId);
            // Upload attachments first
            final taskWithUrls = await _uploadAttachments(task);
            await _firestoreService.uploadTask(taskWithUrls);
            _pendingUploads.remove(taskId);
          } catch (e) {
            // Task not found locally.
            debugPrint(
                'SYNC: Task $taskId not found for upload (maybe deleted locally). Removing from upload queue.');
            _pendingUploads.remove(taskId);
          }
        } catch (e) {
          debugPrint('SYNC: Failed to upload queued task $taskId: $e');
        }
      }
    }
  }

  void _onSettingsChanged() {
    final shouldSync =
        _settingsProvider.settings.isSyncEnabled && _auth.currentUser != null;

    if (shouldSync) {
      _startSync();
    } else {
      _stopSync();
    }
  }

  List<Task>? _pendingRemoteTasks;
  bool _isSyncingLocal = false;
  DateTime _lastSyncTime = DateTime.fromMillisecondsSinceEpoch(0);
  static const _minSyncInterval =
      Duration(milliseconds: 60); // ~1000 updates/min

  void _startSync() async {
    if (_firestoreSubscription != null) return;

    debugPrint('SYNC: Starting Cloud Sync...');
    syncStatus.value = SyncStatus.syncing;
    _lastSyncError = null;

    // 1. Ensure metadata document exists
    await _firestoreService.ensureMetadataExists();

    // 2. Load local metadata version from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    _localMetadataVersion = prefs.getInt('tasks_metadata_version');
    debugPrint('SYNC: Local metadata version: $_localMetadataVersion');

    // 3. Fetch remote metadata
    final remoteMetadata = await _firestoreService.getTasksMetadata();
    final remoteVersion = remoteMetadata?['version'] as int?;
    debugPrint('SYNC: Remote metadata version: $remoteVersion');

    // 4. Decide whether to do initial bulk fetch
    bool shouldFetchAll = false;

    if (_localMetadataVersion == null || remoteVersion == null) {
      // First sync or metadata missing - fetch all
      debugPrint('SYNC: First sync or missing metadata. Fetching all tasks.');
      shouldFetchAll = true;
    } else if (_localMetadataVersion != remoteVersion) {
      // Version mismatch - fetch all
      debugPrint(
          'SYNC: Version mismatch (local: $_localMetadataVersion, remote: $remoteVersion). Fetching all tasks.');
      shouldFetchAll = true;
    } else {
      // Versions match - skip initial fetch!
      debugPrint(
          'SYNC: Versions match! Skipping initial fetch (SAVED ${(await _localRepository.loadTasks()).length} READS!).');
    }

    // 5. Perform initial fetch if needed
    if (shouldFetchAll) {
      debugPrint('SYNC: Performing one-time bulk fetch...');
      final remoteTasks = await _firestoreService.getTasksStream().first;

      // Process the fetched tasks
      _pendingRemoteTasks = remoteTasks;
      await _processRemoteTasks();

      // Update local version
      if (remoteVersion != null) {
        await prefs.setInt('tasks_metadata_version', remoteVersion);
        _localMetadataVersion = remoteVersion;
        debugPrint('SYNC: Updated local version to $remoteVersion');
      }
    }

    // 6. Enable real-time stream (for instant updates while app is open)
    debugPrint('SYNC: Enabling real-time stream...');
    _firestoreSubscription = _firestoreService.getTasksStream().listen(
      (remoteTasks) async {
        // Update local version when we get new data
        final metadata = await _firestoreService.getTasksMetadata();
        final newVersion = metadata?['version'] as int?;
        if (newVersion != null && newVersion != _localMetadataVersion) {
          _localMetadataVersion = newVersion;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt('tasks_metadata_version', newVersion);
          debugPrint('SYNC: Updated local version to $newVersion from stream');
        }

        _pendingRemoteTasks = remoteTasks;
        _processRemoteTasks();

        // If we get here, sync is working
        if (syncStatus.value != SyncStatus.offline) {
          syncStatus.value = SyncStatus.idle;
        }
      },
      onError: (e) {
        debugPrint('SYNC: Cloud Sync Error: $e');
        _lastSyncError = e.toString();
        syncStatus.value = SyncStatus.error;
      },
    );

    // Check connectivity initially
    Connectivity().checkConnectivity().then((results) {
      _isOnline = results.any((result) =>
          result == ConnectivityResult.mobile ||
          result == ConnectivityResult.wifi ||
          result == ConnectivityResult.ethernet);
      if (_isOnline) _processUploadQueue();
    });
  }

  Future<void> _processRemoteTasks() async {
    if (_isSyncingLocal) return;
    _isSyncingLocal = true;

    try {
      while (_pendingRemoteTasks != null) {
        final remoteTasks = _pendingRemoteTasks!;
        _pendingRemoteTasks = null;

        // Rate limiting
        final now = DateTime.now();
        final timeSinceLast = now.difference(_lastSyncTime);
        if (timeSinceLast < _minSyncInterval) {
          await Future.delayed(_minSyncInterval - timeSinceLast);
        }
        _lastSyncTime = DateTime.now();

        debugPrint('SYNC: Processing ${remoteTasks.length} tasks from Cloud');

        // Optimization: Load all local tasks once
        final localTasks = await _localRepository.loadTasks();
        final localMap = {for (var t in localTasks) t.id: t};
        bool hasChanges = false;

        for (final remoteTask in remoteTasks) {
          debugPrint(
              'SYNC: Checking remote task ${remoteTask.id} (${remoteTask.title})');

          // 1. Check if we are waiting to delete this task locally
          if (_pendingDeletes.contains(remoteTask.id)) {
            debugPrint(
                'SYNC: Ignoring remote task ${remoteTask.id} because it is pending delete locally.');
            continue;
          }

          // 2. Handle Soft Deletes from Cloud
          if (remoteTask.deletedAt != null) {
            if (localMap.containsKey(remoteTask.id)) {
              debugPrint(
                  'SYNC: Remote task ${remoteTask.id} is deleted. Removing locally.');
              localTasks.removeWhere((t) => t.id == remoteTask.id);
              hasChanges = true;
            } else {
              debugPrint(
                  'SYNC: Remote task ${remoteTask.id} is deleted, but not found locally. Ignoring.');
            }
            continue;
          }

          // 3. Download Attachments
          final taskWithLocalPaths = await _downloadAttachments(remoteTask);

          final localTask = localMap[remoteTask.id];

          // 4. Conflict Resolution
          if (localTask == null) {
            // New task from cloud
            debugPrint('SYNC: New task from cloud: ${remoteTask.id}');
            localTasks.add(taskWithLocalPaths);
            localMap[remoteTask.id] = taskWithLocalPaths;
            hasChanges = true;
          } else if (localTask != taskWithLocalPaths) {
            // Update existing
            debugPrint('SYNC: Updating local task ${remoteTask.id} from cloud');
            final index = localTasks.indexWhere((t) => t.id == remoteTask.id);
            if (index != -1) {
              localTasks[index] = taskWithLocalPaths;
              localMap[remoteTask.id] = taskWithLocalPaths;
              hasChanges = true;
            }
          } else {
            debugPrint('SYNC: Task ${remoteTask.id} is in sync.');
          }
        }

        if (hasChanges) {
          debugPrint(
              'SYNC: Saving ${localTasks.length} tasks to local repository');
          await _localRepository.saveTasks(localTasks);
        } else {
          debugPrint('SYNC: No changes to save.');
        }
      }
    } catch (e) {
      debugPrint('SYNC: Error processing remote tasks: $e');
    } finally {
      _isSyncingLocal = false;
    }
  }

  void _stopSync() {
    debugPrint('SYNC: Stopping Cloud Sync...');
    _firestoreSubscription?.cancel();
    _firestoreSubscription = null;
    _pendingRemoteTasks = null;
    _isSyncingLocal = false;
  }

  @override
  Future<void> addTask(Task task) async {
    debugPrint('SYNC: addTask called for ${task.id}');
    await _localRepository.addTask(task);

    // Log History
    _historyService.logAction(task.id, HistoryAction.create, changes: {
      'title': task.title,
      'description': task.description,
    });

    // ALWAYS queue the new task, even if sync is disabled.
    // This ensures that when sync is re-enabled, we upload it.
    _pendingUploads.add(task.id);

    // If sync is enabled, try to sync immediately
    if (_settingsProvider.settings.isSyncEnabled) {
      if (_isOnline) {
        try {
          debugPrint('SYNC: Uploading new task ${task.id} immediately');
          final taskWithUrls = await _uploadAttachments(task);
          await _firestoreService.uploadTask(taskWithUrls);
          // Remove from queue if successful
          _pendingUploads.remove(task.id);
        } catch (e) {
          debugPrint('SYNC: Upload failed, will retry later: $e');
          // Keep in queue for later
        }
      } else {
        debugPrint('SYNC: Offline, new task queued for ${task.id}');
      }
    } else {
      debugPrint(
          'SYNC: Sync disabled, new task queued for later sync for ${task.id}');
    }
  }

  @override
  Future<void> deleteTask(String taskId) async {
    debugPrint('SYNC: deleteTask called for $taskId');
    await _localRepository.deleteTask(taskId);

    // Log History
    _historyService.logAction(taskId, HistoryAction.delete);

    // ALWAYS queue the delete, even if sync is disabled.
    // This ensures that when sync is re-enabled, we don't re-download the task.
    _pendingDeletes.add(taskId);
    _pendingUploads.remove(taskId);

    // If sync is enabled, try to sync immediately
    if (_settingsProvider.settings.isSyncEnabled) {
      if (_isOnline) {
        try {
          debugPrint('SYNC: Deleting task $taskId from cloud immediately');
          await _firestoreService.deleteTask(taskId);
          // Remove from queue if successful
          _pendingDeletes.remove(taskId);
        } catch (e) {
          debugPrint('SYNC: Delete sync failed, will retry later: $e');
          // Keep in queue for later
        }
      } else {
        debugPrint('SYNC: Offline, delete queued for $taskId');
      }
    } else {
      debugPrint(
          'SYNC: Sync disabled, delete queued for later sync for $taskId');
    }
  }

  @override
  Future<List<Task>> loadTasks() {
    return _localRepository.loadTasks();
  }

  @override
  Future<void> saveTasks(List<Task> tasks) async {
    debugPrint('SYNC: saveTasks called for ${tasks.length} tasks');

    // 1. Load current state for diffing BEFORE saving new state
    final oldTasks = await _localRepository.loadTasks();
    final oldTaskMap = {for (var t in oldTasks) t.id: t};

    // 2. Save to local repository (Disk write)
    await _localRepository.saveTasks(tasks);

    // 3. Diff and Queue only changed tasks
    int queuedCount = 0;
    for (final task in tasks) {
      final oldTask = oldTaskMap[task.id];

      // Only queue if new or changed
      if (oldTask == null || oldTask != task) {
        _pendingUploads.add(task.id);
        queuedCount++;
      }
    }

    debugPrint(
        'SYNC: Queued $queuedCount tasks for upload (out of ${tasks.length})');

    // 4. Trigger Sync (only for queued tasks)
    if (_settingsProvider.settings.isSyncEnabled) {
      if (_isOnline) {
        // Only iterate through tasks that are actually in the queue
        final tasksToUpload =
            tasks.where((t) => _pendingUploads.contains(t.id)).toList();

        for (final task in tasksToUpload) {
          try {
            final taskWithUrls = await _uploadAttachments(task);
            await _firestoreService.uploadTask(taskWithUrls);
            _pendingUploads.remove(task.id);
          } catch (e) {
            debugPrint(
                'SYNC: Upload failed for ${task.id}, will retry later: $e');
            // Keep in queue
          }
        }
      } else {
        debugPrint('SYNC: Offline, $queuedCount tasks queued');
      }
    } else {
      debugPrint(
          'SYNC: Sync disabled, $queuedCount tasks queued for later sync');
    }
  }

  @override
  Future<void> updateTask(Task task) async {
    debugPrint('SYNC: updateTask called for ${task.id}');
    // Calculate diff for history
    try {
      final oldTasks = await _localRepository.loadTasks();
      final oldTask = oldTasks.firstWhere((t) => t.id == task.id);
      final changes = _calculateChanges(oldTask, task);

      if (changes.isNotEmpty) {
        _historyService.logAction(task.id, HistoryAction.update,
            changes: changes);
      }
    } catch (e) {
      debugPrint('SYNC: Failed to log history for update: $e');
    }

    await _localRepository.updateTask(task);

    // ALWAYS queue the update, even if sync is disabled.
    // This ensures that when sync is re-enabled, we upload the latest version.
    _pendingUploads.add(task.id);

    // If sync is enabled, try to sync immediately
    if (_settingsProvider.settings.isSyncEnabled) {
      if (_isOnline) {
        try {
          debugPrint('SYNC: Uploading updated task ${task.id} immediately');
          final taskWithUrls = await _uploadAttachments(task);
          await _firestoreService.uploadTask(taskWithUrls);
          // Remove from queue if successful
          _pendingUploads.remove(task.id);
        } catch (e) {
          debugPrint('SYNC: Upload failed, will retry later: $e');
          // Keep in queue for later
        }
      } else {
        debugPrint('SYNC: Offline, update queued for ${task.id}');
      }
    } else {
      debugPrint(
          'SYNC: Sync disabled, update queued for later sync for ${task.id}');
    }
  }

  @override
  Stream<List<Task>> watchTasks() => _taskStreamController.stream;

  Future<Task> _uploadAttachments(Task task) async {
    if (task.attachedFiles.isEmpty) return task;

    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      debugPrint('SYNC: User ID is null, skipping attachment upload.');
      return task;
    }

    final newAttachedFiles = <String>[];
    bool hasChanges = false;
    String newDescription = task.description;

    debugPrint(
        'SYNC: Processing ${task.attachedFiles.length} attachments for task ${task.id}');

    for (final filePath in task.attachedFiles) {
      debugPrint('SYNC: Processing attachment path: $filePath');

      final isLocal = _isLocalPath(filePath);
      debugPrint('SYNC: isLocalPath($filePath) = $isLocal');

      if (isLocal) {
        try {
          final file = File(filePath);
          final exists = file.existsSync();
          debugPrint('SYNC: File exists: $exists');

          if (exists) {
            final storagePath = _getStoragePath(userId, task.id, filePath);
            debugPrint('SYNC: Attempting upload to $storagePath');

            final uploadedPath = await _storageSyncService.uploadFile(
              file: file,
              storagePath: storagePath,
            );
            debugPrint('SYNC: Upload successful. Result path: $uploadedPath');

            newAttachedFiles.add(uploadedPath);

            // Rewrite Markdown
            bool replaced = false;

            // 1. Exact match
            if (newDescription.contains(filePath)) {
              newDescription =
                  newDescription.replaceAll(filePath, uploadedPath);
              replaced = true;
            }

            // 2. Escaped backslashes
            if (!replaced && filePath.contains(r'\')) {
              final escapedPath = filePath.replaceAll(r'\', r'\\');
              if (newDescription.contains(escapedPath)) {
                newDescription =
                    newDescription.replaceAll(escapedPath, uploadedPath);
                replaced = true;
              }
            }

            // 3. Forward slashes
            if (!replaced && filePath.contains(r'\')) {
              final forwardSlashPath = filePath.replaceAll(r'\', '/');
              if (newDescription.contains(forwardSlashPath)) {
                newDescription =
                    newDescription.replaceAll(forwardSlashPath, uploadedPath);
                replaced = true;
              }
            }

            // 4. URL Encoded
            if (!replaced) {
              final encodedPath = Uri.encodeFull(filePath);
              if (newDescription.contains(encodedPath)) {
                newDescription =
                    newDescription.replaceAll(encodedPath, uploadedPath);
                replaced = true;
              }
            }

            // 5. URL Encoded with forward slashes
            if (!replaced && filePath.contains(r'\')) {
              final forwardSlashPath = filePath.replaceAll(r'\', '/');
              final encodedPath = Uri.encodeFull(forwardSlashPath);
              if (newDescription.contains(encodedPath)) {
                newDescription =
                    newDescription.replaceAll(encodedPath, uploadedPath);
                replaced = true;
              }
            }

            if (replaced) {
              debugPrint('SYNC: Successfully rewrote Markdown path');
            } else {
              debugPrint(
                  'SYNC: WARNING: Could not find path in description to rewrite.');
            }

            hasChanges = true;
          } else {
            debugPrint('SYNC: Attachment not found locally: $filePath');
            newAttachedFiles.add(filePath);
          }
        } catch (e, stack) {
          debugPrint('SYNC: Failed to upload attachment $filePath: $e');
          debugPrint('SYNC: Stack trace: $stack');
          newAttachedFiles.add(filePath);
        }
      } else {
        debugPrint('SYNC: Path is not local, keeping as is.');
        newAttachedFiles.add(filePath);
      }
    }

    if (hasChanges) {
      debugPrint('SYNC: Task updated with new attachment paths.');
      return task.copyWith(
        attachedFiles: newAttachedFiles,
        description: newDescription,
      );
    }
    debugPrint('SYNC: No changes made to task attachments.');
    return task;
  }

  Future<Task> _downloadAttachments(Task task) async {
    if (task.attachedFiles.isEmpty) return task;

    final newAttachedFiles = <String>[];
    bool hasChanges = false;
    String newDescription = task.description;

    // Get attachments directory
    final rootDir = await _storageService.getRootDirectory();
    final attachmentsDir =
        Directory(path.join(rootDir.path, 'task_attachments'));
    if (!attachmentsDir.existsSync()) {
      await attachmentsDir.create(recursive: true);
    }

    for (final filePath in task.attachedFiles) {
      if (!_isLocalPath(filePath)) {
        // It's a storage path
        try {
          final fileName = path.basename(filePath);
          final localPath = path.join(attachmentsDir.path, fileName);

          debugPrint('SYNC: Downloading attachment $filePath to $localPath');

          await _storageSyncService.downloadFile(
            storagePath: filePath,
            localPath: localPath,
          );

          newAttachedFiles.add(localPath);

          // Rewrite Markdown: Replace storage path with local path
          if (newDescription.contains(filePath)) {
            newDescription = newDescription.replaceAll(filePath, localPath);
          }

          hasChanges = true;
        } catch (e) {
          debugPrint('SYNC: Failed to download attachment $filePath: $e');
          newAttachedFiles.add(filePath);
        }
      } else {
        newAttachedFiles.add(filePath);
      }
    }

    if (hasChanges) {
      return task.copyWith(
        attachedFiles: newAttachedFiles,
        description: newDescription,
      );
    }
    return task;
  }

  bool _isLocalPath(String filePath) {
    // Simple heuristic: if it starts with 'users/', it's likely a storage path
    // If it starts with '/' or 'C:', it's likely a local path
    // Also check if it's absolute
    if (filePath.startsWith('users/')) return false;
    return path.isAbsolute(filePath);
  }

  String _getStoragePath(String userId, String taskId, String localPath) {
    final fileName = path.basename(localPath);
    return 'users/$userId/tasks/$taskId/attachments/$fileName';
  }

  Map<String, dynamic> _calculateChanges(Task oldTask, Task newTask) {
    final changes = <String, dynamic>{};

    if (oldTask.title != newTask.title) {
      changes['title'] = {'old': oldTask.title, 'new': newTask.title};
    }
    if (oldTask.description != newTask.description) {
      changes['description'] =
          'Description updated'; // Too long to store full diff
    }
    if (oldTask.isCompleted != newTask.isCompleted) {
      changes['isCompleted'] = {
        'old': oldTask.isCompleted,
        'new': newTask.isCompleted
      };
    }
    if (oldTask.dueDate != newTask.dueDate) {
      changes['dueDate'] = {
        'old': oldTask.dueDate?.toIso8601String(),
        'new': newTask.dueDate?.toIso8601String()
      };
    }
    if (!listEquals(oldTask.tags, newTask.tags)) {
      changes['tags'] = {'old': oldTask.tags, 'new': newTask.tags};
    }
    if (!listEquals(oldTask.attachedFiles, newTask.attachedFiles)) {
      changes['attachedFiles'] = {
        'old': oldTask.attachedFiles,
        'new': newTask.attachedFiles
      };
    }

    return changes;
  }
}
