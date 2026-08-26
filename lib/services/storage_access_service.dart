import 'package:flutter/services.dart';

/// Grants/checks broad storage access needed to list EPUBs in
/// user-chosen shared-storage folders (Android scoped storage).
///
/// On Android 11+ this drives the system "All files access" toggle;
/// on older versions it requests READ_EXTERNAL_STORAGE.
class StorageAccessService {
  static const _channel = MethodChannel('int_reader/storage');

  /// True when storage access is already granted.
  Future<bool> hasAccess() async {
    try {
      return await _channel.invokeMethod<bool>('hasStorageAccess') ?? false;
    } on MissingPluginException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Returns true once access is granted. If not currently granted, sends
  /// the user to the system settings/runtime prompt and resolves with the
  /// state after they return.
  Future<bool> ensureAccess() async {
    try {
      return await _channel.invokeMethod<bool>('ensureStorageAccess') ?? false;
    } on MissingPluginException {
      return false;
    } catch (_) {
      return false;
    }
  }
}

/// Global singleton instance.
final storageAccessService = StorageAccessService();
