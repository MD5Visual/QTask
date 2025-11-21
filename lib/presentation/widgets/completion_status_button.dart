import 'package:flutter/material.dart';

enum CompletionStatus {
  all,
  incomplete,
  completed,
}

extension CompletionStatusLabel on CompletionStatus {
  String get label {
    switch (this) {
      case CompletionStatus.all:
        return 'All Tasks';
      case CompletionStatus.incomplete:
        return 'Incomplete';
      case CompletionStatus.completed:
        return 'Completed';
    }
  }

  bool? get filterValue {
    switch (this) {
      case CompletionStatus.all:
        return null;
      case CompletionStatus.incomplete:
        return false;
      case CompletionStatus.completed:
        return true;
    }
  }
}

class CompletionStatusButton extends StatelessWidget {
  final bool? currentStatus;
  final ValueChanged<bool?> onStatusSelected;

  const CompletionStatusButton({
    required this.currentStatus,
    required this.onStatusSelected,
    super.key,
  });

  CompletionStatus get _currentMode {
    if (currentStatus == null) return CompletionStatus.all;
    if (currentStatus == false) return CompletionStatus.incomplete;
    return CompletionStatus.completed;
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<CompletionStatus>(
      icon: const Icon(Icons.fact_check_outlined),
      tooltip: 'Filter by completion status',
      initialValue: _currentMode,
      onSelected: (status) => onStatusSelected(status.filterValue),
      itemBuilder: (context) {
        return CompletionStatus.values.map((status) {
          return PopupMenuItem<CompletionStatus>(
            value: status,
            child: Row(
              children: [
                if (status == _currentMode)
                  const Icon(Icons.check, size: 18)
                else
                  const SizedBox(width: 18),
                const SizedBox(width: 8),
                Text(status.label),
              ],
            ),
          );
        }).toList();
      },
    );
  }
}
