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
import 'package:q_task/data/services/backup_service.dart';
import 'package:q_task/presentation/providers/settings_provider.dart';
import 'package:q_task/presentation/providers/task_provider.dart';
import 'package:q_task/presentation/providers/task_list_provider.dart';
import 'package:q_task/presentation/screens/home_screen.dart';
import 'package:q_task/presentation/theme/app_theme.dart';
import 'package:window_manager/window_manager.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:q_task/presentation/providers/auth_provider.dart';
import 'firebase_options.dart';

import 'dart:io';

import 'package:q_task/data/services/firestore_service.dart';
import 'package:q_task/data/repositories/sync_task_repository.dart';
import 'package:q_task/data/repositories/sync_task_list_repository.dart';
import 'package:q_task/data/services/settings_sync_service.dart';
import 'package:q_task/data/services/storage_sync_service.dart';
import 'package:q_task/data/services/history_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();
  }

  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
    // Continue running the app even if Firebase fails (e.g. offline or no config)
  }

  // Activate App Check (only on supported platforms: mobile and web)
  if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) {
    try {
      await FirebaseAppCheck.instance.activate(
        // Default provider for Android is Play Integrity. For debug builds, we use debug provider.
        androidProvider: AndroidProvider.debug,
        // Default provider for iOS is DeviceCheck or AppAttest.
        appleProvider: AppleProvider.appAttest,
        // For web, we need a reCAPTCHA key.
        webProvider: ReCaptchaV3Provider('recaptcha-v3-site-key'),
      );
      debugPrint('App Check activated successfully');
    } catch (e) {
      debugPrint('App Check activation failed: $e');
      // App Check is not critical for development, continue without it
    }
  } else {
    debugPrint('App Check skipped (not supported on desktop platforms)');
  }

  final packageInfo = await PackageInfo.fromPlatform();
  final versionString = 'QTask v${packageInfo.version}';

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.setTitle(versionString);
  }

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
        ChangeNotifierProvider(
          create: (_) => AuthProvider(),
        ),
        ProxyProvider<SettingsProvider, StorageService>(
          update: (_, settingsProvider, __) => StorageService(settingsProvider),
        ),
        Provider<FirestoreService>(
          create: (_) => FirestoreService(),
        ),
        ProxyProvider<StorageService, MarkdownTaskRepository>(
          update: (_, storageService, __) =>
              MarkdownTaskRepository(storageService),
        ),
        Provider<StorageSyncService>(
          create: (_) => StorageSyncService(),
        ),
        Provider<HistoryService>(
          create: (_) => HistoryService(),
        ),
        ProxyProvider6<
            MarkdownTaskRepository,
            FirestoreService,
            SettingsProvider,
            StorageSyncService,
            StorageService,
            HistoryService,
            SyncTaskRepository>(
          update: (_,
                  localRepo,
                  firestoreService,
                  settingsProvider,
                  storageSyncService,
                  storageService,
                  historyService,
                  previous) =>
              previous ??
              SyncTaskRepository(
                localRepo,
                firestoreService,
                settingsProvider,
                storageSyncService,
                storageService,
                historyService,
              ),
          dispose: (_, repo) => repo.dispose(),
        ),
        ProxyProvider<StorageService, MarkdownTaskListRepository>(
          update: (_, storageService, __) =>
              MarkdownTaskListRepository(storageService),
        ),
        ProxyProvider3<MarkdownTaskListRepository, FirestoreService,
            SettingsProvider, SyncTaskListRepository>(
          update:
              (_, localRepo, firestoreService, settingsProvider, previous) =>
                  previous ??
                  SyncTaskListRepository(
                      localRepo, firestoreService, settingsProvider),
          dispose: (_, repo) => repo.dispose(),
        ),
        ProxyProvider2<SettingsProvider, FirestoreService, SettingsSyncService>(
          update: (_, settingsProvider, firestoreService, previous) =>
              previous ??
              SettingsSyncService(settingsProvider, firestoreService),
          dispose: (_, service) => service.dispose(),
        ),
        ProxyProvider<StorageService, AttachmentService>(
          update: (_, storageService, __) => AttachmentService(storageService),
        ),
        ProxyProvider<StorageService, BackupService>(
          update: (_, storageService, __) => BackupService(storageService),
        ),
        ChangeNotifierProxyProvider3<SyncTaskRepository, AttachmentService,
            SettingsProvider, TaskProvider>(
          create: (context) {
            final syncRepo =
                Provider.of<SyncTaskRepository>(context, listen: false);
            final settingsProvider =
                Provider.of<SettingsProvider>(context, listen: false);
            return TaskProvider(
              taskRepository: syncRepo,
              taskService: TaskService(),
              settingsProvider: settingsProvider,
            );
          },
          update: (_, taskRepo, attachmentService, settingsProvider, previous) {
            final provider = previous ??
                TaskProvider(
                  taskRepository: taskRepo,
                  taskService: TaskService(),
                  settingsProvider: settingsProvider,
                );
            provider.updateDependencies(
              taskRepository: taskRepo,
              taskService: TaskService(),
              settingsProvider: settingsProvider,
            );
            return provider;
          },
        ),
        ChangeNotifierProxyProvider<SyncTaskListRepository, TaskListProvider>(
          create: (context) {
            final syncRepo =
                Provider.of<SyncTaskListRepository>(context, listen: false);
            return TaskListProvider(
              taskListRepository: syncRepo,
            );
          },
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
