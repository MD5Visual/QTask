# How to Re-Enable Cloud Sync

This guide explains how to restore the cloud synchronization features (Firebase) that were removed for the local-only version (v0.11.21).

## Prerequisites

1.  **Firebase Project**: You need a Firebase project set up.
2.  **Configuration Files**: You need `firebase_options.dart` and `assets/oauth_config.json`.

## Steps to Re-Enable

### 1. Restore Dependencies

Add the following dependencies back to `pubspec.yaml`:

```yaml
dependencies:
  firebase_core: ^3.6.0
  firebase_auth: ^5.3.1
  cloud_firestore: ^5.4.4
  firebase_storage: ^12.3.2
  firebase_app_check: ^0.3.1+4
  google_sign_in: ^6.2.1
  connectivity_plus: ^7.0.0
  google_sign_in_all_platforms: ^1.2.1
  # crypto is already present if not removed
```

Run `flutter pub get`.

### 2. Restore Code Files

You need to restore the following files that were deleted. You can retrieve them from git history (e.g., from tag `v0.9.6` or the commit before the local-only refactor).

*   `lib/firebase_options.dart`
*   `lib/data/repositories/sync_task_repository.dart`
*   `lib/data/repositories/sync_task_list_repository.dart`
*   `lib/data/services/firestore_service.dart`
*   `lib/data/services/storage_sync_service.dart`
*   `lib/data/services/settings_sync_service.dart`
*   `lib/data/services/history_service.dart`
*   `lib/presentation/widgets/sync_status_indicator.dart` (if deleted)

### 3. Restore AuthProvider

Revert `lib/presentation/providers/auth_provider.dart` to its previous state containing Firebase Auth and Google Sign-In logic.

### 4. Restore SettingsScreen

Uncomment or restore the "Cloud Sync" section in `lib/presentation/screens/settings_screen.dart`.

### 5. Update main.dart

Refactor `lib/main.dart` to:
1.  Initialize Firebase (`Firebase.initializeApp`).
2.  Initialize App Check.
3.  Re-inject the Sync repositories and services into the `MultiProvider`.

Refer to the git history of `lib/main.dart` for the exact wiring.

## Git Workflow

If you want to do this on a separate branch:

1.  Create a new branch: `git checkout -b feature/restore-cloud-sync`
2.  Revert the "local-only" commit: `git revert <commit-hash>`
3.  Resolve any conflicts.
