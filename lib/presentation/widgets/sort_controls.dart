import 'package:flutter/material.dart';
import 'package:q_task/domain/models/task_sort.dart';

class SortDirectionButton extends StatelessWidget {
  final bool isAscending;
  final VoidCallback onToggle;

  const SortDirectionButton({
    required this.isAscending,
    required this.onToggle,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: isAscending ? 'Ascending order' : 'Descending order',
      icon: Icon(isAscending ? Icons.arrow_upward : Icons.arrow_downward),
      onPressed: onToggle,
    );
  }
}

class SortButton extends StatelessWidget {
  final TaskSortMode currentMode;
  final ValueChanged<TaskSortMode> onSortSelected;

  const SortButton({
    required this.currentMode,
    required this.onSortSelected,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<TaskSortMode>(
      icon: const Icon(Icons.sort),
      tooltip: 'Sort tasks',
      initialValue: currentMode,
      onSelected: onSortSelected,
      itemBuilder: (context) {
        return TaskSortMode.values.map((mode) {
          return PopupMenuItem<TaskSortMode>(
            value: mode,
            child: Row(
              children: [
                if (mode == currentMode)
                  const Icon(Icons.check, size: 18)
                else
                  const SizedBox(width: 18),
                const SizedBox(width: 8),
                Text(mode.label),
              ],
            ),
          );
        }).toList();
      },
    );
  }
}
