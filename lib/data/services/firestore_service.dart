import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../domain/models/task.dart';
import '../../domain/models/task_list.dart';
import '../../presentation/providers/settings_provider.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _userId => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>>? get _tasksCollection {
    final uid = _userId;
    if (uid == null) return null;
    return _firestore.collection('users').doc(uid).collection('tasks');
  }

  DocumentReference<Map<String, dynamic>>? get _tasksMetadataDocument {
    final uid = _userId;
    if (uid == null) return null;
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('metadata')
        .doc('tasks');
  }

  /// Uploads or updates a task in Firestore
  Future<void> uploadTask(Task task) async {
    final collection = _tasksCollection;
    if (collection == null) return;

    await collection.doc(task.id).set(
          task.toMap(),
          SetOptions(merge: true), // Merge to preserve fields if needed
        );

    // Update metadata to trigger version change
    await _incrementMetadataVersion();
  }

  /// Deletes a task from Firestore (Soft Delete)
  Future<void> deleteTask(String taskId) async {
    final collection = _tasksCollection;
    if (collection == null) return;

    await collection.doc(taskId).update({
      'deletedAt': DateTime.now().toIso8601String(),
    });

    // Update metadata to trigger version change
    await _incrementMetadataVersion();
  }

  /// Streams all tasks for the current user
  Stream<List<Task>> getTasksStream() {
    final collection = _tasksCollection;
    if (collection == null) return Stream.value([]);

    return collection.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) {
            try {
              return Task.fromMap(doc.data());
            } catch (e) {
              // Handle potential parsing errors gracefully
              print('Error parsing task ${doc.id}: $e');
              return null;
            }
          })
          .whereType<Task>()
          .toList();
    });
  }
  // --- Task Lists ---

  CollectionReference<Map<String, dynamic>>? get _taskListsCollection {
    final uid = _userId;
    if (uid == null) return null;
    return _firestore.collection('users').doc(uid).collection('task_lists');
  }

  Future<void> uploadTaskList(TaskList list) async {
    final collection = _taskListsCollection;
    if (collection == null) return;

    await collection.doc(list.id).set(
          list.toMap(),
          SetOptions(merge: true),
        );
  }

  Future<void> deleteTaskList(String listId) async {
    final collection = _taskListsCollection;
    if (collection == null) return;

    await collection.doc(listId).delete();
  }

  Stream<List<TaskList>> getTaskListsStream() {
    final collection = _taskListsCollection;
    if (collection == null) return Stream.value([]);

    return collection.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) {
            try {
              return TaskList.fromMap(doc.data());
            } catch (e) {
              debugPrint('Error parsing task list ${doc.id}: $e');
              return null;
            }
          })
          .whereType<TaskList>()
          .toList();
    });
  }

  // --- Settings ---

  DocumentReference<Map<String, dynamic>>? get _settingsDocument {
    final uid = _userId;
    if (uid == null) return null;
    // For Phase 2, we sync global settings (theme, etc.)
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('settings')
        .doc('global');
  }

  Future<void> uploadSettings(SettingsModel settings) async {
    final doc = _settingsDocument;
    if (doc == null) return;

    await doc.set(
      settings.toJson(),
      SetOptions(merge: true),
    );
  }

  Stream<SettingsModel?> getSettingsStream() {
    final doc = _settingsDocument;
    if (doc == null) return Stream.value(null);

    return doc.snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) return null;
      try {
        return SettingsModel.fromJson(snapshot.data()!);
      } catch (e) {
        debugPrint('Error parsing settings: $e');
        return null;
      }
    });
  }

  // --- Tasks Metadata (for sync optimization) ---

  /// Fetches the tasks metadata document
  Future<Map<String, dynamic>?> getTasksMetadata() async {
    final doc = _tasksMetadataDocument;
    if (doc == null) return null;

    try {
      final snapshot = await doc.get();
      if (!snapshot.exists || snapshot.data() == null) {
        return null;
      }
      return snapshot.data();
    } catch (e) {
      debugPrint('Error fetching tasks metadata: $e');
      return null;
    }
  }

  /// Increments the metadata version to signal changes
  Future<void> _incrementMetadataVersion() async {
    final doc = _tasksMetadataDocument;
    if (doc == null) return;

    try {
      await doc.set(
        {
          'version': FieldValue.increment(1),
          'lastModified': DateTime.now().toIso8601String(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('Error updating tasks metadata: $e');
      // Non-critical error, don't block the upload
    }
  }

  /// Initializes metadata if it doesn't exist (called on first sync)
  Future<void> ensureMetadataExists() async {
    final doc = _tasksMetadataDocument;
    if (doc == null) return;

    try {
      final snapshot = await doc.get();
      if (!snapshot.exists) {
        debugPrint('SYNC: Initializing tasks metadata...');
        await doc.set({
          'version': 1,
          'lastModified': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      debugPrint('Error ensuring metadata exists: $e');
    }
  }
}
