import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:q_task/domain/models/task_list.dart';
import 'package:q_task/presentation/providers/task_list_provider.dart';
import 'package:q_task/presentation/providers/task_provider.dart';
import 'package:q_task/presentation/screens/list_detail_screen.dart';
import 'package:q_task/presentation/screens/settings_screen.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  void _createNewList(BuildContext context) async {
    final result = await Navigator.of(context).push<TaskList>(
      MaterialPageRoute(
        builder: (context) => const ListDetailScreen(),
      ),
    );

    if (result != null && context.mounted) {
      context.read<TaskListProvider>().addList(result);
    }
  }

  void _editList(BuildContext context, TaskList list) async {
    final result = await Navigator.of(context).push<TaskList>(
      MaterialPageRoute(
        builder: (context) => ListDetailScreen(list: list),
      ),
    );

    if (result != null && context.mounted) {
      context.read<TaskListProvider>().updateList(result);
    }
  }

  Widget _buildCountBadge(BuildContext context, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        count.toString(),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
            ),
            margin: EdgeInsets.zero,
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  SvgPicture.asset(
                    'assets/logo.svg',
                    height: 48,
                    colorFilter: ColorFilter.mode(
                      Theme.of(context).colorScheme.onPrimary,
                      BlendMode.srcIn,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'My QTasks',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: const Color.fromARGB(255, 0, 0, 0),
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Consumer2<TaskListProvider, TaskProvider>(
              builder: (context, listProvider, taskProvider, _) {
                final lists = listProvider.lists;
                return ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.inbox),
                      title: const Text('All Tasks'),
                      trailing: _buildCountBadge(
                          context, taskProvider.getAllTasksCount()),
                      selected: taskProvider.selectedListId == null,
                      onTap: () {
                        taskProvider.clearListSelection();
                        Navigator.pop(context);
                      },
                    ),
                    const Divider(),
                    // Unlisted Tasks (only show if there are tasks without lists)
                    if (taskProvider.hasUnlistedTasks)
                      ListTile(
                        leading: const Icon(Icons.label_off_outlined),
                        title: const Text('Unlisted Tasks'),
                        trailing: _buildCountBadge(
                            context,
                            taskProvider.getTaskCountForList(
                                TaskProvider.unlistedTasksId)),
                        selected: taskProvider.selectedListId ==
                            TaskProvider.unlistedTasksId,
                        onTap: () {
                          taskProvider.selectList(TaskProvider.unlistedTasksId);
                          Navigator.pop(context);
                        },
                      ),
                    ...lists.map((list) => _buildListTile(
                        context, list, taskProvider, listProvider)),
                  ],
                );
              },
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Settings'),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              );
            },
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _createNewList(context),
                  icon: const Icon(Icons.add),
                  label: const Text('New List'),
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListTile(
    BuildContext context,
    TaskList list,
    TaskProvider taskProvider,
    TaskListProvider listProvider,
  ) {
    final isSelected = taskProvider.selectedListId == list.id;
    final isHidden = list.isHidden;
    final textTheme = Theme.of(context).textTheme;
    final secondaryColor = textTheme.bodyMedium?.color?.withValues(alpha: 0.65);
    final taskCount = taskProvider.getTaskCountForList(list.id);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Color(
          int.parse('0xFF${list.color.replaceFirst('#', '')}'),
        ),
        radius: 12,
        child: Text(
          taskCount > 0 ? taskCount.toString() : '',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color:
                    Color(int.parse('0xFF${list.color.replaceFirst('#', '')}'))
                                .computeLuminance() >
                            0.5
                        ? Colors.black
                        : Colors.white,
              ),
        ),
      ),
      title: Row(
        children: [
          Text(
            list.name,
            style: isHidden
                ? textTheme.bodyLarge?.copyWith(color: secondaryColor)
                : null,
          ),
        ],
      ),
      selected: isSelected,
      onTap: () {
        taskProvider.selectList(list.id);
        Navigator.pop(context);
      },
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(isHidden ? Icons.visibility_off : Icons.visibility),
            tooltip: isHidden ? 'Show list' : 'Hide list',
            onPressed: () async {
              await listProvider.setListHidden(list.id, !isHidden);
            },
          ),
          PopupMenuButton(
            itemBuilder: (context) => [
              PopupMenuItem(
                child: const Text('Edit'),
                onTap: () {
                  _editList(context, list);
                },
              ),
              PopupMenuItem(
                child: const Text('Delete'),
                onTap: () {
                  listProvider.deleteList(list.id);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
