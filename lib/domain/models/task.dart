import 'package:uuid/uuid.dart';

class Task {
  final String id;
  final String title;
  final String description;
  final DateTime createdAt;
  final DateTime? dueDate;
  final List<String> tags;
  final List<String> attachedFiles;
  final List<String> listIds;
  final int position;
  final bool isCompleted;
  final DateTime? completedAt;

  Task({
    String? id,
    required this.title,
    this.description = '',
    DateTime? createdAt,
    this.dueDate,
    this.tags = const [],
    this.attachedFiles = const [],
    this.listIds = const [],
    this.position = 0,
    this.isCompleted = false,
    this.completedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  Task copyWith({
    String? title,
    String? description,
    DateTime? dueDate,
    List<String>? tags,
    List<String>? attachedFiles,
    List<String>? listIds,
    int? position,
    bool? isCompleted,
    DateTime? completedAt,
    bool resetCompletedAt = false,
  }) {
    return Task(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      createdAt: createdAt,
      dueDate: dueDate ?? this.dueDate,
      tags: tags ?? this.tags,
      attachedFiles: attachedFiles ?? this.attachedFiles,
      listIds: listIds ?? this.listIds,
      position: position ?? this.position,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: resetCompletedAt ? null : (completedAt ?? this.completedAt),
    );
  }
}
