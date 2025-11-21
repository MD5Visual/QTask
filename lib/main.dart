import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:q_task/data/repositories/markdown_task_list_repository.dart';
import 'package:q_task/data/repositories/markdown_task_repository.dart';
import 'package:q_task/data/services/attachment_service.dart';
import 'package:q_task/data/services/storage_service.dart';
import 'package:q_task/data/services/task_service.dart';
import 'package:q_task/presentation/providers/settings_provider.dart';
import 'package:q_task/presentation/providers/task_provider.dart';
import 'package:q_task/presentation/providers/task_list_provider.dart';
import 'package:q_task/presentation/screens/home_screen.dart';
import 'package:q_task/presentation/theme/app_theme.dart';
import 'package:window_manager/window_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  final packageInfo = await PackageInfo.fromPlatform();
  final versionString = 'QTask v${packageInfo.version}';

  await windowManager.setTitle(versionString);

  runApp(TaskApp(versionString: versionString));
}

class TaskApp extends StatelessWidget {
  final String versionString;

  const TaskApp({
    super.key,
    required this.versionString,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => SettingsProvider(),
        ),
        ProxyProvider<SettingsProvider, StorageService>(
          update: (_, settingsProvider, __) => StorageService(settingsProvider),
        ),
        ProxyProvider<StorageService, MarkdownTaskRepository>(
          update: (_, storageService, __) =>
              MarkdownTaskRepository(storageService),
        ),
        ProxyProvider<StorageService, MarkdownTaskListRepository>(
          update: (_, storageService, __) =>
              MarkdownTaskListRepository(storageService),
        ),
        ProxyProvider<StorageService, AttachmentService>(
          update: (_, storageService, __) => AttachmentService(storageService),
        ),
        ChangeNotifierProxyProvider2<MarkdownTaskRepository, AttachmentService,
            TaskProvider>(
          create: (_) => TaskProvider(
            taskRepository:
                MarkdownTaskRepository(StorageService(SettingsProvider())),
            taskService: TaskService(),
          ),
          update: (_, taskRepo, attachmentService, previous) {
            final provider = previous ??
                TaskProvider(
                  taskRepository: taskRepo,
                  taskService: TaskService(),
                );
            provider.updateDependencies(
              taskRepository: taskRepo,
              taskService: TaskService(),
            );
            return provider;
          },
        ),
        ChangeNotifierProxyProvider<MarkdownTaskListRepository,
            TaskListProvider>(
          create: (_) => TaskListProvider(
            taskListRepository:
                MarkdownTaskListRepository(StorageService(SettingsProvider())),
          ),
          update: (_, taskListRepo, previous) {
            final provider = previous ??
                TaskListProvider(
                  taskListRepository: taskListRepo,
                );
            provider.updateDependencies(taskListRepo);
            return provider;
          },
        ),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settingsProvider, _) {
          final settings = settingsProvider.settings;
          // Initialize storage service directory structure
          // We can't easily await here. Ideally StorageService.ensureDirectoryExists()
          // should be called when settings change or on app start.
          // For now, repositories call _ensureDirectoryExists internally.

          return MaterialApp(
            title: versionString,
            theme: AppTheme.lightTheme(settings),
            darkTheme: AppTheme.darkTheme(settings),
            themeMode: settings.isDarkMode == null
                ? ThemeMode.system
                : (settings.isDarkMode! ? ThemeMode.dark : ThemeMode.light),
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              quill.FlutterQuillLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('en', 'US'),
            ],
            home: const HomeScreen(),
          );
        },
      ),
    );
  }
}
