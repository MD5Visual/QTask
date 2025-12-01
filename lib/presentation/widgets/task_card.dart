import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:q_task/domain/models/task.dart';
import 'package:q_task/domain/models/task_list.dart';
import 'package:q_task/presentation/providers/settings_provider.dart';
import 'package:q_task/presentation/screens/rich_task_detail_screen.dart';

class TaskCard extends StatelessWidget {
  final Task task;
  final VoidCallback onDelete;
  final VoidCallback onToggleComplete;
  final Function(Task) onUpdate;
  final List<TaskList> availableLists;
  final int index;

  const TaskCard({
    required this.task,
    required this.onDelete,
    required this.onToggleComplete,
    required this.onUpdate,
    required this.availableLists,
    required this.index,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context).settings;
    final baseSpacing = settings.baseSpacing;
    final basePadding = settings.basePadding;

    final dateFormatter = DateFormat.yMMMd().add_jm();
    final matchingLists = task.listIds
        .map((listId) {
          try {
            return availableLists.firstWhere((list) => list.id == listId);
          } catch (_) {
            return null;
          }
        })
        .whereType<TaskList>()
        .toList();

    // Build gradient colors from all matching lists
    final List<Color> gradientColors = [];
    for (final list in matchingLists) {
      try {
        if (list.color.isNotEmpty) {
          gradientColors.add(
            Color(int.parse('0xFF${list.color.replaceFirst('#', '')}')),
          );
        } else {
          gradientColors.add(Colors.transparent);
        }
      } catch (_) {
        gradientColors.add(Colors.transparent);
      }
    }

    return Card(
      margin: EdgeInsets.all(baseSpacing * 0.5),
      child: ClipRect(
        child: Stack(
          children: [
            // Main content container
            Container(
              decoration: BoxDecoration(
                border: gradientColors.length <= 1
                    ? Border(
                        left: BorderSide(
                          color: gradientColors.isEmpty
                              ? Colors.transparent
                              : gradientColors.first,
                          width: basePadding * 0.2,
                        ),
                      )
                    : null,
              ),
              child: GestureDetector(
                onSecondaryTapDown: (details) {
                  _showContextMenu(context, details.globalPosition);
                },
                child: ListTile(
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: basePadding,
                    vertical: basePadding * 0.5,
                  ),
                  leading: Checkbox(
                    value: task.isCompleted,
                    onChanged: (_) => onToggleComplete(),
                  ),
                  title: Text(
                    task.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          decoration: task.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: baseSpacing * 0.5),
                      if (task.description.isNotEmpty)
                        Text(
                          task.description.length > 50
                              ? '${task.description.substring(0, 50)}...'
                              : task.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      if (matchingLists.isNotEmpty) ...[
                        SizedBox(height: baseSpacing * 0.5),
                        Wrap(
                          spacing: baseSpacing * 0.5,
                          runSpacing: baseSpacing * 0.5,
                          children: matchingLists.take(5).map((list) {
                            Color listColor;
                            try {
                              listColor = Color(
                                int.parse(
                                  '0xFF${list.color.replaceFirst('#', '')}',
                                ),
                              );
                            } catch (_) {
                              listColor = Theme.of(context)
                                  .colorScheme
                                  .primaryContainer;
                            }
                            return Tooltip(
                              message: list.name,
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: listColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                      if (task.isCompleted && task.completedAt != null) ...[
                        SizedBox(height: baseSpacing * 0.75),
                        Text(
                          'Checked off ${dateFormatter.format(task.completedAt!.toLocal())}',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(fontStyle: FontStyle.italic),
                        ),
                      ],
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (task.dueDate != null)
                        Builder(builder: (context) {
                          final now = DateTime.now();
                          final due = task.dueDate!;
                          final isOverdue =
                              !task.isCompleted && due.isBefore(now);
                          final dateStr = DateFormat.yMMMd().format(due);
                          return Padding(
                            padding: EdgeInsets.only(right: basePadding * 0.5),
                            child: Text(
                              dateStr,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: isOverdue
                                        ? Theme.of(context).colorScheme.error
                                        : Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.color,
                                  ),
                            ),
                          );
                        }),
                      // Drag handle area with grab cursor
                      MouseRegion(
                        cursor: defaultTargetPlatform == TargetPlatform.windows
                            ? SystemMouseCursors.resizeUpDown
                            : SystemMouseCursors.grab,
                        child: ReorderableDragStartListener(
                          index: index,
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: basePadding * 0.25),
                            child: Icon(
                              Icons.drag_indicator,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  onTap: () async {
                    final result = await Navigator.of(context).push<Task>(
                      MaterialPageRoute(
                        builder: (context) => RichTaskDetailScreen(
                          task: task,
                          availableLists: availableLists,
                        ),
                      ),
                    );
                    if (result != null) {
                      onUpdate(result);
                    }
                  },
                ),
              ),
            ), // Gradient overlay for left border when multiple colors exist
            if (gradientColors.length > 1)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: CustomPaint(
                  size: Size(basePadding * 0.2, double.infinity),
                  painter: _GradientBorderPainter(
                    gradient: LinearGradient(
                      colors: gradientColors,
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context, Offset position) {
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;

    showMenu(
      context: context,
      position: RelativeRect.fromRect(
        position & const Size(40, 40),
        Offset.zero & overlay.size,
      ),
      items: [
        PopupMenuItem(
          onTap: () async {
            // Delay to allow menu to close first
            await Future.delayed(const Duration(milliseconds: 100));
            if (!context.mounted) return;
            final result = await Navigator.of(context).push<Task>(
              MaterialPageRoute(
                builder: (context) => RichTaskDetailScreen(
                  task: task,
                  availableLists: availableLists,
                ),
              ),
            );
            if (result != null && context.mounted) {
              onUpdate(result);
            }
          },
          child: const Text('Edit'),
        ),
        PopupMenuItem(
          onTap: () {
            // Delay to allow menu to close first
            Future.delayed(const Duration(milliseconds: 100), onDelete);
          },
          child: const Text('Delete'),
        ),
      ],
    );
  }
}

/// Custom painter to draw a gradient border on the left side
class _GradientBorderPainter extends CustomPainter {
  final Gradient gradient;

  _GradientBorderPainter({required this.gradient});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final paint = Paint()..shader = gradient.createShader(rect);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(_GradientBorderPainter oldDelegate) {
    return oldDelegate.gradient != gradient;
  }
}
