import 'package:q_task/domain/models/task.dart';
import 'package:q_task/domain/models/task_filter.dart';
import 'package:q_task/domain/models/task_list.dart';

abstract class ITaskRepository {
  Future<void> saveTasks(List<Task> tasks);
  Future<List<Task>> loadTasks();
  Future<void> deleteTask(String taskId);
  Future<void> updateTask(Task task);
  Future<void> addTask(Task task);
  Stream<List<Task>> watchTasks();
}

abstract class ITaskListRepository {
  Future<void> saveTaskLists(List<TaskList> lists);
  Future<List<TaskList>> loadTaskLists();
  Future<void> addTaskList(TaskList list);
  Future<void> updateTaskList(TaskList list);
  Future<void> deleteTaskList(String listId);
  Stream<List<TaskList>> watchTaskLists();
}

abstract class ITaskService {
  List<Task> filterTasks(List<Task> tasks, TaskFilter filter);
  List<Task> sortTasksByPosition(List<Task> tasks);
  Task updateTaskPosition(Task task, int newPosition);
}
