import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../domain/models/history_item.dart';

class HistoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _userId => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>>? _getHistoryCollection(
      String taskId) {
    final uid = _userId;
    if (uid == null) return null;
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('tasks')
        .doc(taskId)
        .collection('history');
  }

  Future<void> logAction(String taskId, HistoryAction action,
      {Map<String, dynamic>? changes}) async {
    final collection = _getHistoryCollection(taskId);
    if (collection == null) return;

    final userId = _userId;
    if (userId == null) return;

    try {
      final item = HistoryItem(
        taskId: taskId,
        userId: userId,
        action: action,
        changes: changes ?? {},
      );

      await collection.doc(item.id).set(item.toMap());
      debugPrint('HISTORY: Logged ${action.name} for task $taskId');
    } catch (e) {
      debugPrint('HISTORY: Failed to log action: $e');
    }
  }

  Stream<List<HistoryItem>> getHistoryStream(String taskId) {
    final collection = _getHistoryCollection(taskId);
    if (collection == null) return Stream.value([]);

    return collection
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) {
            try {
              return HistoryItem.fromMap(doc.data());
            } catch (e) {
              debugPrint('HISTORY: Error parsing history item: $e');
              return null;
            }
          })
          .whereType<HistoryItem>()
          .toList();
    });
  }
}
