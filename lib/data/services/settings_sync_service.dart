import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:q_task/data/services/firestore_service.dart';
import 'package:q_task/presentation/providers/settings_provider.dart';

class SettingsSyncService {
  final SettingsProvider _settingsProvider;
  final FirestoreService _firestoreService;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  StreamSubscription<SettingsModel?>? _firestoreSubscription;
  StreamSubscription<User?>? _authSubscription;
  bool _isSyncingLocal = false;

  SettingsSyncService(this._settingsProvider, this._firestoreService) {
    _init();
  }

  void _init() {
    // Listen to local settings changes
    _settingsProvider.addListener(_onLocalSettingsChanged);

    // Listen to auth state changes
    _authSubscription = _auth.authStateChanges().listen((_) {
      _checkSyncState();
    });

    _checkSyncState();
  }

  void dispose() {
    _settingsProvider.removeListener(_onLocalSettingsChanged);
    _firestoreSubscription?.cancel();
    _authSubscription?.cancel();
  }

  void _checkSyncState() {
    final shouldSync =
        _settingsProvider.settings.isSyncEnabled && _auth.currentUser != null;

    if (shouldSync) {
      _startSync();
    } else {
      _stopSync();
    }
  }

  void _startSync() {
    if (_firestoreSubscription != null) return;

    debugPrint('Starting Settings Sync...');
    _firestoreSubscription = _firestoreService.getSettingsStream().listen(
      (remoteSettings) {
        if (remoteSettings != null) {
          _applyRemoteSettings(remoteSettings);
        }
      },
      onError: (e) {
        debugPrint('Settings Sync Error: $e');
      },
    );
  }

  void _stopSync() {
    debugPrint('Stopping Settings Sync...');
    _firestoreSubscription?.cancel();
    _firestoreSubscription = null;
  }

  void _onLocalSettingsChanged() {
    if (_isSyncingLocal) return; // Avoid loops

    final shouldSync =
        _settingsProvider.settings.isSyncEnabled && _auth.currentUser != null;

    if (shouldSync) {
      // Check if sync was just enabled
      if (_firestoreSubscription == null) {
        _startSync();
      }

      // Upload settings
      // We throttle this slightly to avoid spamming on slider drags
      // But for now, direct upload is fine as settings change rarely
      _firestoreService.uploadSettings(_settingsProvider.settings);
    } else {
      if (_firestoreSubscription != null) {
        _stopSync();
      }
    }
  }

  void _applyRemoteSettings(SettingsModel remoteSettings) {
    _isSyncingLocal = true;
    try {
      // We only update if things actually changed to avoid unnecessary notifies
      final current = _settingsProvider.settings;

      // Merge logic: Remote overrides local for synced fields
      // We keep local-only fields (like customDataPath) if they were null in remote
      // But SettingsModel.fromJson handles nulls by using defaults, so we need to be careful.
      // For Phase 2, we just overwrite with what we got, assuming the model handles it.

      if (current.primaryColor != remoteSettings.primaryColor ||
          current.isDarkMode != remoteSettings.isDarkMode ||
          current.baseFontSize != remoteSettings.baseFontSize) {
        debugPrint('Applying remote settings...');
        _settingsProvider.updateSettings(remoteSettings);
      }
    } finally {
      _isSyncingLocal = false;
    }
  }
}
