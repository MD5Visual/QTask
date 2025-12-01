import 'package:uuid/uuid.dart';

enum HistoryAction { create, update, delete }

class HistoryItem {
  final String id;
  final String taskId;
  final String userId;
  final HistoryAction action;
  final Map<String, dynamic> changes;
  final DateTime timestamp;

  HistoryItem({
    String? id,
    required this.taskId,
    required this.userId,
    required this.action,
    this.changes = const {},
    DateTime? timestamp,
  })  : id = id ?? const Uuid().v4(),
        timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'taskId': taskId,
      'userId': userId,
      'action': action.name,
      'changes': changes,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory HistoryItem.fromMap(Map<String, dynamic> map) {
    return HistoryItem(
      id: map['id'] as String?,
      taskId: map['taskId'] as String,
      userId: map['userId'] as String,
      action: HistoryAction.values.firstWhere(
        (e) => e.name == map['action'],
        orElse: () => HistoryAction.update,
      ),
      changes: Map<String, dynamic>.from(map['changes'] ?? {}),
      timestamp: DateTime.parse(map['timestamp'] as String),
    );
  }
}
