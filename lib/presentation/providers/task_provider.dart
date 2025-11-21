import 'package:flutter/foundation.dart';
import 'package:q_task/domain/models/task.dart';
import 'package:q_task/domain/models/task_filter.dart';
import 'package:q_task/domain/models/task_list.dart';
import 'package:q_task/domain/models/task_sort.dart';
import 'package:q_task/domain/repositories/i_repository.dart';

class TaskProvider extends ChangeNotifier {
  static const String unlistedTasksId = '__unlisted__';

  final ITaskRepository _taskRepository;
  final ITaskService _taskService;

  List<Task> _allTasks = [];
  List<Task> _filteredTasks = [];
  TaskFilter _currentFilter = TaskFilter(isCompleted: false);
  TaskSortMode _currentSortMode = TaskSortMode.dateAdded;
  bool _isAscending = false;
  Map<String, String> _listNames = {};
  bool _isLoading = false;
  String? _selectedListId;
  Set<String> _hiddenListIds = {};

  TaskProvider({
    required ITaskRepository taskRepository,
    required ITaskService taskService,
  })  : _taskRepository = taskRepository,
        _taskService = taskService;

  // Getters
  List<Task> get tasks => _filteredTasks;
  List<Task> get allTasks => _allTasks;
  bool get isLoading => _isLoading;
  TaskFilter get currentFilter => _currentFilter;
  TaskSortMode get currentSortMode => _currentSortMode;
  bool get isSortAscending => _isAscending;
  String? get selectedListId => _selectedListId;
  bool get hasUnlistedTasks =>
      _allTasks.any((task) => task.listIds.isEmpty && !task.isCompleted);

  // Initialization
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      _allTasks = await _taskRepository.loadTasks();
      _applyCurrentFilter();
    } catch (e) {
      _allTasks = [];
      _filteredTasks = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  // Task Management
  Future<void> addTask(Task task) async {
    _allTasks.add(task);
    await _taskRepository.saveTasks(_allTasks);
    _applyCurrentFilter();
    notifyListeners();
  }

  Future<void> updateTask(Task updatedTask) async {
    final index = _allTasks.indexWhere((t) => t.id == updatedTask.id);
    if (index != -1) {
      _allTasks[index] = updatedTask;
      await _taskRepository.saveTasks(_allTasks);
      _applyCurrentFilter();
      notifyListeners();
    }
  }

  Future<void> deleteTask(String taskId) async {
    _allTasks.removeWhere((t) => t.id == taskId);
    await _taskRepository.saveTasks(_allTasks);
    _applyCurrentFilter();
    notifyListeners();
  }

  Future<void> toggleTaskCompletion(String taskId) async {
    final index = _allTasks.indexWhere((t) => t.id == taskId);
    if (index != -1) {
      final task = _allTasks[index];
      final shouldComplete = !task.isCompleted;
      _allTasks[index] = task.copyWith(
        isCompleted: shouldComplete,
        completedAt: shouldComplete ? DateTime.now() : null,
        resetCompletedAt: !shouldComplete,
      );
      await _taskRepository.saveTasks(_allTasks);
      _applyCurrentFilter();
      notifyListeners();
    }
  }

  // Position/Reordering
  Future<void> reorderTasks(int oldIndex, int newIndex) async {
    if (_currentSortMode != TaskSortMode.custom || !_isAscending) {
      _currentSortMode = TaskSortMode.custom;
      _isAscending = true;
    }

    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    final task = _filteredTasks.removeAt(oldIndex);
    _filteredTasks.insert(newIndex, task);

    // Update positions in all tasks
    for (int i = 0; i < _allTasks.length; i++) {
      final filteredIndex =
          _filteredTasks.indexWhere((t) => t.id == _allTasks[i].id);
      _allTasks[i] = _allTasks[i].copyWith(position: filteredIndex);
    }

    await _taskRepository.saveTasks(_allTasks);
    notifyListeners();
  }

  // Filtering
  Future<void> applyFilter(TaskFilter filter) async {
    _currentFilter = filter;
    _applyCurrentFilter();
    notifyListeners();
  }

  void _applyCurrentFilter() {
    List<Task> result = _allTasks;

    // Filter by selected list if one is selected
    if (_selectedListId != null) {
      if (_selectedListId == unlistedTasksId) {
        // Show only tasks with no lists
        result = result.where((task) => task.listIds.isEmpty).toList();
      } else {
        // Show tasks in the selected list
        result = result
            .where((task) => task.listIds.contains(_selectedListId!))
            .toList();
      }
    } else {
      result = result.where((task) => !_shouldHideFromAll(task)).toList();
    }

    // Apply additional filters
    if (!_currentFilter.isEmpty()) {
      result = _taskService.filterTasks(result, _currentFilter);
    }

    _filteredTasks = _sortTasks(result);
  }

  void clearFilter() async {
    _currentFilter = TaskFilter(isCompleted: false);
    _applyCurrentFilter();
    notifyListeners();
  }

  void setCompletionFilter(bool? isCompleted) {
    _currentFilter = _currentFilter.copyWith(
      isCompleted: isCompleted,
      clearIsCompleted: isCompleted == null,
    );
    _applyCurrentFilter();
    notifyListeners();
  }

  void setSearchQuery(String query, int fuzzyTolerance) {
    _currentFilter = _currentFilter.copyWith(
      searchQuery: query.isEmpty ? null : query,
      clearSearchQuery: query.isEmpty,
      fuzzyTolerance: fuzzyTolerance,
    );
    _applyCurrentFilter();
    notifyListeners();
  }

  // List Management
  void selectList(String? listId) {
    _selectedListId = listId;
    _applyCurrentFilter();
    notifyListeners();
  }

  void clearListSelection() {
    _selectedListId = null;
    _applyCurrentFilter();
    notifyListeners();
  }

  void setSortMode(TaskSortMode mode) {
    if (_currentSortMode == mode) return;
    _currentSortMode = mode;
    _applyCurrentFilter();
    notifyListeners();
  }

  void toggleSortDirection() {
    _isAscending = !_isAscending;
    _applyCurrentFilter();
    notifyListeners();
  }

  void syncListMetadata(List<TaskList> lists) {
    final nextNames = {for (final list in lists) list.id: list.name};
    final nextHidden =
        lists.where((list) => list.isHidden).map((list) => list.id).toSet();

    final namesChanged = !mapEquals(_listNames, nextNames);
    final hiddenChanged = !setEquals(_hiddenListIds, nextHidden);

    if (!namesChanged && !hiddenChanged) {
      return;
    }

    _listNames = nextNames;
    _hiddenListIds = nextHidden;

    final shouldResort =
        namesChanged && _currentSortMode == TaskSortMode.taskList;
    final shouldRefilter = hiddenChanged && _selectedListId == null;

    if (shouldResort || shouldRefilter) {
      _applyCurrentFilter();
      notifyListeners();
    }
  }

  // Utilities
  Task? getTaskById(String taskId) {
    try {
      return _allTasks.firstWhere((t) => t.id == taskId);
    } catch (e) {
      return null;
    }
  }

  List<String> getAllTags() {
    final tags = <String>{};
    for (final task in _allTasks) {
      tags.addAll(task.tags);
    }
    return tags.toList();
  }

  /// Get count of tasks in a specific list
  int getTaskCountForList(String listId) {
    if (listId == unlistedTasksId) {
      return _allTasks
          .where((task) => task.listIds.isEmpty && !task.isCompleted)
          .length;
    }
    return _allTasks
        .where((task) => task.listIds.contains(listId) && !task.isCompleted)
        .length;
  }

  /// Get count of all tasks (excluding hidden lists)
  int getAllTasksCount() {
    return _allTasks
        .where((task) => !_shouldHideFromAll(task) && !task.isCompleted)
        .length;
  }

  List<Task> _sortTasks(List<Task> tasks) {
    final sorted = List<Task>.from(tasks);
    sorted.sort(_compareTasks);
    return sorted;
  }

  int _compareTasks(Task a, Task b) {
    switch (_currentSortMode) {
      case TaskSortMode.custom:
        return _applyDirection(a.position.compareTo(b.position));
      case TaskSortMode.alphabetic:
        final result = a.title.toLowerCase().compareTo(b.title.toLowerCase());
        return _applyDirection(result);
      case TaskSortMode.taskList:
        final result = _primaryListName(a).compareTo(_primaryListName(b));
        if (result != 0) {
          return _applyDirection(result);
        }
        final tieBreak = a.title.toLowerCase().compareTo(b.title.toLowerCase());
        return _applyDirection(tieBreak);
      case TaskSortMode.dueDate:
        return _compareDueDates(a, b);
      case TaskSortMode.dateAdded:
        final result = a.createdAt.compareTo(b.createdAt);
        return _applyDirection(result);
    }
  }

  int _compareDueDates(Task a, Task b) {
    final aDue = a.dueDate;
    final bDue = b.dueDate;
    if (aDue == null && bDue == null) {
      return _applyDirection(a.position.compareTo(b.position));
    }
    if (aDue == null) {
      return 1;
    }
    if (bDue == null) {
      return -1;
    }
    final result = aDue.compareTo(bDue);
    return _isAscending ? result : -result;
  }

  int _applyDirection(int comparison) {
    return _isAscending ? comparison : -comparison;
  }

  String _primaryListName(Task task) {
    if (task.listIds.isEmpty) {
      return '{zzz}';
    }
    final listId = task.listIds.first;
    return (_listNames[listId] ?? listId).toLowerCase();
  }

  bool _shouldHideFromAll(Task task) {
    if (task.listIds.isEmpty) {
      return false;
    }
    return task.listIds.every((listId) => _hiddenListIds.contains(listId));
  }
}
