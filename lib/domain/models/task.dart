import 'package:flutter/foundation.dart';
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
  final DateTime? deletedAt;

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
    this.deletedAt,
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
    DateTime? deletedAt,
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
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
      'dueDate': dueDate?.toIso8601String(),
      'tags': tags,
      'attachedFiles': attachedFiles,
      'listIds': listIds,
      'position': position,
      'isCompleted': isCompleted,
      'completedAt': completedAt?.toIso8601String(),
      'deletedAt': deletedAt?.toIso8601String(),
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'] as String?,
      title: map['title'] as String,
      description: map['description'] as String? ?? '',
      createdAt: DateTime.parse(map['createdAt'] as String),
      dueDate: map['dueDate'] != null
          ? DateTime.parse(map['dueDate'] as String)
          : null,
      tags: (map['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      attachedFiles:
          (map['attachedFiles'] as List<dynamic>?)?.cast<String>() ?? [],
      listIds: (map['listIds'] as List<dynamic>?)?.cast<String>() ?? [],
      position: map['position'] as int? ?? 0,
      isCompleted: map['isCompleted'] as bool? ?? false,
      completedAt: map['completedAt'] != null
          ? DateTime.parse(map['completedAt'] as String)
          : null,
      deletedAt: map['deletedAt'] != null
          ? DateTime.parse(map['deletedAt'] as String)
          : null,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Task &&
        other.id == id &&
        other.title == title &&
        other.description == description &&
        other.createdAt == createdAt &&
        other.dueDate == dueDate &&
        listEquals(other.tags, tags) &&
        listEquals(other.attachedFiles, attachedFiles) &&
        listEquals(other.listIds, listIds) &&
        other.position == position &&
        other.isCompleted == isCompleted &&
        other.completedAt == completedAt &&
        other.deletedAt == deletedAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        title.hashCode ^
        description.hashCode ^
        createdAt.hashCode ^
        dueDate.hashCode ^
        Object.hashAll(tags) ^
        Object.hashAll(attachedFiles) ^
        Object.hashAll(listIds) ^
        position.hashCode ^
        isCompleted.hashCode ^
        completedAt.hashCode ^
        deletedAt.hashCode;
  }
}
