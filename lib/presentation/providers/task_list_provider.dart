import 'package:flutter/foundation.dart';
import 'package:q_task/domain/models/task_list.dart';
import 'package:q_task/domain/repositories/i_repository.dart';

class TaskListProvider extends ChangeNotifier {
  ITaskListRepository _taskListRepository;

  List<TaskList> _taskLists = [];
  bool _isLoading = false;

  TaskListProvider({
    required ITaskListRepository taskListRepository,
  }) : _taskListRepository = taskListRepository;

  void updateDependencies(ITaskListRepository taskListRepository) {
    _taskListRepository = taskListRepository;
    // Defer initialization to avoid notifying during build
    Future.microtask(() => initialize());
  }

  // Getters
  List<TaskList> get lists => _sortedByPosition(_taskLists);
  List<TaskList> get visibleLists =>
      _sortedByPosition(_taskLists.where((l) => !l.isHidden).toList());
  List<TaskList> get hiddenLists =>
      _sortedByPosition(_taskLists.where((l) => l.isHidden).toList());
  bool get isLoading => _isLoading;

  // Initialization
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      _taskLists = await _taskListRepository.loadTaskLists();
    } catch (e) {
      _taskLists = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  // List Management
  Future<void> addList(TaskList taskList) async {
    _taskLists.add(taskList);
    await _taskListRepository.saveTaskLists(_taskLists);
    notifyListeners();
  }

  Future<void> updateList(TaskList updatedList) async {
    final index = _taskLists.indexWhere((l) => l.id == updatedList.id);
    if (index != -1) {
      _taskLists[index] = updatedList;
      await _taskListRepository.saveTaskLists(_taskLists);
      notifyListeners();
    }
  }

  Future<void> deleteList(String listId) async {
    _taskLists.removeWhere((l) => l.id == listId);
    await _taskListRepository.saveTaskLists(_taskLists);
    notifyListeners();
  }

  Future<void> setListHidden(String listId, bool isHidden) async {
    final index = _taskLists.indexWhere((l) => l.id == listId);
    if (index == -1) return;
    _taskLists[index] = _taskLists[index].copyWith(isHidden: isHidden);
    await _taskListRepository.saveTaskLists(_taskLists);
    notifyListeners();
  }

  // Utilities
  TaskList? getListById(String listId) {
    try {
      return _taskLists.firstWhere((l) => l.id == listId);
    } catch (e) {
      return null;
    }
  }

  String getListName(String listId) {
    return getListById(listId)?.name ?? 'Unknown List';
  }

  List<TaskList> _sortedByPosition(List<TaskList> lists) {
    final copy = List<TaskList>.from(lists);
    copy.sort((a, b) => a.position.compareTo(b.position));
    return copy;
  }
}
