import 'package:uuid/uuid.dart';

class TaskList {
  final String id;
  final String name;
  final String color;
  final DateTime createdAt;
  final int position;
  final bool isHidden;

  TaskList({
    String? id,
    required this.name,
    this.color = '#3F51B5',
    DateTime? createdAt,
    this.position = 0,
    this.isHidden = false,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  TaskList copyWith({
    String? name,
    String? color,
    int? position,
    bool? isHidden,
  }) {
    return TaskList(
      id: id,
      name: name ?? this.name,
      color: color ?? this.color,
      createdAt: createdAt,
      position: position ?? this.position,
      isHidden: isHidden ?? this.isHidden,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'color': color,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'position': position,
      'isHidden': isHidden,
    };
  }

  factory TaskList.fromMap(Map<String, dynamic> map) {
    return TaskList(
      id: map['id'],
      name: map['name'] ?? 'Untitled List',
      color: map['color'] ?? '#3F51B5',
      createdAt: map['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'])
          : null,
      position: map['position'] ?? 0,
      isHidden: map['isHidden'] ?? false,
    );
  }
}
