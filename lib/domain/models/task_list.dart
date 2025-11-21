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
}
