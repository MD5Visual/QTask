enum TaskSortMode {
  custom,
  alphabetic,
  taskList,
  dueDate,
  dateAdded,
}

extension TaskSortModeLabel on TaskSortMode {
  String get label {
    switch (this) {
      case TaskSortMode.custom:
        return 'Custom';
      case TaskSortMode.alphabetic:
        return 'Alphabetic';
      case TaskSortMode.taskList:
        return 'Task List';
      case TaskSortMode.dueDate:
        return 'Due Date';
      case TaskSortMode.dateAdded:
        return 'Date Added';
    }
  }
}
