import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:q_task/data/services/firestore_service.dart';
import 'package:q_task/domain/models/task_list.dart';
import 'package:q_task/domain/repositories/i_repository.dart';
import 'package:q_task/presentation/providers/settings_provider.dart';

class SyncTaskListRepository implements ITaskListRepository {
  final ITaskListRepository _localRepository;
  final FirestoreService _firestoreService;
  final SettingsProvider _settingsProvider;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  StreamSubscription<List<TaskList>>? _firestoreSubscription;
  final _listStreamController = StreamController<List<TaskList>>.broadcast();
  StreamSubscription<List<TaskList>>? _localSubscription;
  StreamSubscription<User?>? _authSubscription;

  List<TaskList>? _pendingRemoteLists;
  bool _isSyncingLocal = false;
  DateTime _lastSyncTime = DateTime.fromMillisecondsSinceEpoch(0);
  static const _minSyncInterval = Duration(milliseconds: 60);

  SyncTaskListRepository(
    this._localRepository,
    this._firestoreService,
    this._settingsProvider,
  ) {
    _init();
  }

  void _init() {
    // Listen to local changes and forward them
    _localSubscription = _localRepository.watchTaskLists().listen((lists) {
      _listStreamController.add(lists);
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
    _listStreamController.close();
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

  void _startSync() {
    if (_firestoreSubscription != null) return;

    debugPrint('Starting Task List Sync...');
    _firestoreSubscription = _firestoreService.getTaskListsStream().listen(
      (remoteLists) {
        _pendingRemoteLists = remoteLists;
        _processRemoteLists();
      },
      onError: (e) {
        debugPrint('Task List Sync Error: $e');
      },
    );
  }

  Future<void> _processRemoteLists() async {
    if (_isSyncingLocal) return;
    _isSyncingLocal = true;

    try {
      while (_pendingRemoteLists != null) {
        final remoteLists = _pendingRemoteLists!;
        _pendingRemoteLists = null;

        // Rate limiting
        final now = DateTime.now();
        final timeSinceLast = now.difference(_lastSyncTime);
        if (timeSinceLast < _minSyncInterval) {
          await Future.delayed(_minSyncInterval - timeSinceLast);
        }
        _lastSyncTime = DateTime.now();

        debugPrint('Processing ${remoteLists.length} lists from Cloud');

        // Load all local lists once
        final localLists = await _localRepository.loadTaskLists();
        final localMap = {for (var l in localLists) l.id: l};
        bool hasChanges = false;

        for (final remoteList in remoteLists) {
          final localList = localMap[remoteList.id];

          if (localList == null) {
            // New list from cloud
            localLists.add(remoteList);
            localMap[remoteList.id] = remoteList;
            hasChanges = true;
          } else if (localList.name != remoteList.name ||
              localList.color != remoteList.color ||
              localList.position != remoteList.position ||
              localList.isHidden != remoteList.isHidden) {
            // Update existing if different
            final index = localLists.indexWhere((l) => l.id == remoteList.id);
            if (index != -1) {
              localLists[index] = remoteList;
              localMap[remoteList.id] = remoteList;
              hasChanges = true;
            }
          }
        }

        if (hasChanges) {
          await _localRepository.saveTaskLists(localLists);
        }
      }
    } catch (e) {
      debugPrint('Error processing remote lists: $e');
    } finally {
      _isSyncingLocal = false;
    }
  }

  void _stopSync() {
    debugPrint('Stopping Task List Sync...');
    _firestoreSubscription?.cancel();
    _firestoreSubscription = null;
    _pendingRemoteLists = null;
    _isSyncingLocal = false;
  }

  @override
  Future<void> addTaskList(TaskList list) async {
    await _localRepository.addTaskList(list);
    if (_settingsProvider.settings.isSyncEnabled) {
      _firestoreService.uploadTaskList(list);
    }
  }

  @override
  Future<void> deleteTaskList(String listId) async {
    await _localRepository.deleteTaskList(listId);
    if (_settingsProvider.settings.isSyncEnabled) {
      _firestoreService.deleteTaskList(listId);
    }
  }

  @override
  Future<List<TaskList>> loadTaskLists() {
    return _localRepository.loadTaskLists();
  }

  @override
  Future<void> saveTaskLists(List<TaskList> lists) async {
    await _localRepository.saveTaskLists(lists);
    if (_settingsProvider.settings.isSyncEnabled) {
      for (final list in lists) {
        _firestoreService.uploadTaskList(list);
      }
    }
  }

  @override
  Future<void> updateTaskList(TaskList list) async {
    await _localRepository.updateTaskList(list);
    if (_settingsProvider.settings.isSyncEnabled) {
      _firestoreService.uploadTaskList(list);
    }
  }

  @override
  Stream<List<TaskList>> watchTaskLists() => _listStreamController.stream;
}
