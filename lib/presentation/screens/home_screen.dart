import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:q_task/domain/models/task.dart';

import 'package:q_task/presentation/providers/task_provider.dart';
import 'package:q_task/presentation/providers/task_list_provider.dart';
import 'package:q_task/presentation/providers/settings_provider.dart';
import 'package:q_task/presentation/screens/rich_task_detail_screen.dart';
import 'package:q_task/presentation/widgets/task_card.dart';
import 'package:q_task/presentation/widgets/completion_status_button.dart';
import 'package:q_task/presentation/widgets/sort_controls.dart';
import 'package:q_task/presentation/widgets/app_drawer.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? _initTimer;
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<bool> _isSearchBarVisible = ValueNotifier(true);

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _initTimer = Timer(Duration.zero, () async {
      if (!mounted) return;
      try {
        final taskProvider = context.read<TaskProvider>();
        final listProvider = context.read<TaskListProvider>();
        await taskProvider.initialize();
        await listProvider.initialize();
      } catch (e) {
        debugPrint('Error initializing providers: $e');
      }
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final direction = _scrollController.position.userScrollDirection;
    if (direction == ScrollDirection.reverse) {
      if (_isSearchBarVisible.value) _isSearchBarVisible.value = false;
    } else if (direction == ScrollDirection.forward) {
      if (!_isSearchBarVisible.value) _isSearchBarVisible.value = true;
    }
  }

  TaskListProvider? _listProvider;
  TaskProvider? _taskProvider;
  bool _isSyncScheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final listProvider = context.read<TaskListProvider>();
    final taskProvider = context.read<TaskProvider>();

    if (_taskProvider != taskProvider) {
      _taskProvider = taskProvider;
    }

    if (_listProvider != listProvider) {
      _listProvider?.removeListener(_scheduleHiddenSync);
      _listProvider = listProvider;
      _listProvider?.addListener(_scheduleHiddenSync);
    }

    _scheduleHiddenSync();
  }

  void _scheduleHiddenSync() {
    if (_isSyncScheduled) return;
    final listProvider = _listProvider;
    final taskProvider = _taskProvider;
    if (listProvider == null || taskProvider == null) return;

    _isSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _isSyncScheduled = false;
      taskProvider.syncListMetadata(listProvider.lists);
    });
  }

  @override
  void dispose() {
    _initTimer?.cancel();
    _listProvider?.removeListener(_scheduleHiddenSync);
    _scrollController.dispose();
    _isSearchBarVisible.dispose();
    super.dispose();
  }

  void _createNewTask() async {
    final listProvider = context.read<TaskListProvider>();
    final newTask = await Navigator.of(context).push<Task>(
      MaterialPageRoute(
        builder: (context) => RichTaskDetailScreen(
          availableLists: listProvider.lists,
        ),
      ),
    );

    if (newTask != null && mounted) {
      context.read<TaskProvider>().addTask(newTask);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter): _createNewTask,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: AppBar(
            title: Consumer2<TaskProvider, TaskListProvider>(
              builder: (context, taskProvider, listProvider, _) {
                if (taskProvider.selectedListId != null) {
                  // Check if it's the unlisted tasks special list
                  if (taskProvider.selectedListId ==
                      TaskProvider.unlistedTasksId) {
                    return Text(
                        'Unlisted Tasks (${taskProvider.hasUnlistedTasks ? taskProvider.getAllTasksCount() : 0})');
                  }
                  // Otherwise find the list by ID
                  final matches = listProvider.lists
                      .where((l) => l.id == taskProvider.selectedListId)
                      .toList();
                  if (matches.isNotEmpty) {
                    return Text(
                        '${matches.first.name} (${taskProvider.getTaskCountForList(matches.first.id)})');
                  }
                }
                return Text('All Tasks (${taskProvider.getAllTasksCount()})');
              },
            ),
            elevation: 0,
            actions: [
              // const SyncStatusIndicator(), // Removed for local-only version

              Consumer<TaskProvider>(
                builder: (context, taskProvider, _) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SortDirectionButton(
                      isAscending: taskProvider.isSortAscending,
                      onToggle: taskProvider.toggleSortDirection,
                    ),
                    SortButton(
                      currentMode: taskProvider.currentSortMode,
                      onSortSelected: (mode) {
                        taskProvider.setSortMode(mode);
                      },
                    ),
                  ],
                ),
              ),
              Consumer<TaskProvider>(
                builder: (context, taskProvider, _) => CompletionStatusButton(
                  currentStatus: taskProvider.currentFilter.isCompleted,
                  onStatusSelected: (status) {
                    taskProvider.setCompletionFilter(status);
                  },
                ),
              ),
            ],
          ),
          drawer: const AppDrawer(),
          body: Consumer3<TaskProvider, TaskListProvider, SettingsProvider>(
            builder:
                (context, taskProvider, listProvider, settingsProvider, _) {
              if (taskProvider.isLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              if (taskProvider.tasks.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inbox_outlined,
                        size: 64,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No tasks yet',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Create your first task to get started',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: [
                  // Search field with animation
                  ValueListenableBuilder<bool>(
                    valueListenable: _isSearchBarVisible,
                    builder: (context, isVisible, child) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: isVisible ? 70 : 0,
                        child: SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            child: TextField(
                              onChanged: (query) => taskProvider.setSearchQuery(
                                query,
                                settingsProvider.settings.fuzzySearchTolerance,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Search tasks...',
                                prefixIcon: const Icon(Icons.search),
                                suffixIcon:
                                    taskProvider.currentFilter.searchQuery !=
                                                null &&
                                            taskProvider.currentFilter
                                                .searchQuery!.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(Icons.clear),
                                            onPressed: () =>
                                                taskProvider.setSearchQuery(
                                              '',
                                              settingsProvider.settings
                                                  .fuzzySearchTolerance,
                                            ),
                                          )
                                        : null,
                                filled: true,
                                fillColor: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  // Task list
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () async {
                        taskProvider.syncListMetadata(listProvider.lists);
                      },
                      child: ReorderableListView.builder(
                        scrollController: _scrollController,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 8),
                        buildDefaultDragHandles: false,
                        onReorder: (oldIndex, newIndex) {
                          taskProvider.reorderTasks(oldIndex, newIndex);
                        },
                        proxyDecorator: (child, index, animation) {
                          return MouseRegion(
                            cursor: SystemMouseCursors.grabbing,
                            child: child,
                          );
                        },
                        itemCount: taskProvider.tasks.length,
                        itemBuilder: (context, index) {
                          final task = taskProvider.tasks[index];
                          final card = TaskCard(
                            key: Key(task.id),
                            task: task,
                            index: index,
                            onToggleComplete: () {
                              taskProvider.toggleTaskCompletion(task.id);
                            },
                            onDelete: () {
                              taskProvider.deleteTask(task.id);
                            },
                            onUpdate: (updatedTask) {
                              taskProvider.updateTask(updatedTask);
                            },
                            availableLists: listProvider.lists,
                          );

                          if (Platform.isAndroid) {
                            return Dismissible(
                              key: Key(task.id),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                color: Theme.of(context).colorScheme.error,
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 16),
                                child: Icon(
                                  Icons.delete,
                                  color: Theme.of(context).colorScheme.onError,
                                ),
                              ),
                              onDismissed: (direction) {
                                taskProvider.deleteTask(task.id);
                                ScaffoldMessenger.of(context).clearSnackBars();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('Task deleted'),
                                    duration: const Duration(seconds: 5),
                                    showCloseIcon: true,
                                    action: SnackBarAction(
                                      label: 'Undo',
                                      onPressed: () {
                                        taskProvider.addTask(task);
                                      },
                                    ),
                                  ),
                                );
                              },
                              child: card,
                            );
                          }

                          return card;
                        },
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Tooltip(
                message: 'Press Enter to add task',
                child: FilledButton.icon(
                  onPressed: _createNewTask,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Task'),
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
