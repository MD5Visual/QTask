import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:provider/provider.dart';
import 'package:q_task/data/repositories/markdown_task_repository.dart';
import 'package:q_task/data/repositories/markdown_task_list_repository.dart';
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

  await windowManager.setTitle('QTask v0.7.1');

  runApp(const TaskApp());
}

class TaskApp extends StatelessWidget {
  const TaskApp({super.key});

  @override
  Widget build(BuildContext context) {
    final taskRepository = MarkdownTaskRepository();
    final taskListRepository = MarkdownTaskListRepository();
    final taskService = TaskService();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => TaskProvider(
            taskRepository: taskRepository,
            taskService: taskService,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => TaskListProvider(
            taskListRepository: taskListRepository,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => SettingsProvider(),
        ),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settingsProvider, _) {
          final settings = settingsProvider.settings;
          return MaterialApp(
            title: 'QTask v0.7.1',
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
