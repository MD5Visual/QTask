import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:q_task/data/repositories/sync_task_repository.dart';

class SyncStatusIndicator extends StatelessWidget {
  const SyncStatusIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final syncRepo = context.watch<SyncTaskRepository>();

    return ValueListenableBuilder<SyncStatus>(
      valueListenable: syncRepo.syncStatus,
      builder: (context, status, child) {
        switch (status) {
          case SyncStatus.syncing:
            return const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
                ),
              ),
            );
          case SyncStatus.error:
            return IconButton(
              icon: const Icon(Icons.warning_amber_rounded, color: Colors.red),
              tooltip: 'Sync Error',
              onPressed: () {
                _showErrorDialog(context, syncRepo.lastSyncError);
              },
            );
          case SyncStatus.offline:
            return const IconButton(
              icon: Icon(Icons.cloud_off, color: Colors.grey),
              tooltip: 'Offline',
              onPressed: null,
            );
          case SyncStatus.idle:
            return const IconButton(
              icon: Icon(Icons.cloud_done, color: Colors.green),
              tooltip: 'Synced',
              onPressed: null,
            );
        }
      },
    );
  }

  void _showErrorDialog(BuildContext context, String? error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sync Error'),
        content: SingleChildScrollView(
          child: Text(error ?? 'Unknown error occurred'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
