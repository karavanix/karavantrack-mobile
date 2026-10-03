import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../domain/models/user.dart';
import '../../utils/logger.dart';
import '../../utils/result.dart';
import '../services/api/account_api.dart';
import '../services/local_store.dart';

enum ProfileStatus {
  /// Not loaded and no copy on the device.
  unknown,
  loading,
  ready,

  /// Couldn't load and there's no copy on the device to fall back on.
  unavailable,
}

/// The signed-in user's profile. A copy is kept on the device so a driver
/// with no signal still gets into the app; the server copy replaces it
/// whenever it can be fetched.
class ProfileRepository extends ChangeNotifier {
  ProfileRepository({required this._api, required this._store});

  final AccountApi _api;
  final LocalStore _store;

  User? _user;
  ProfileStatus _status = ProfileStatus.unknown;

  User? get user => _user;

  ProfileStatus get status => _status;

  /// Takes the copy saved on the device, if any. Part of startup, before
  /// anyone listens (it runs while the widget tree is being built), so it
  /// doesn't notify.
  void restore() {
    final cached = _store.getString(StoreKeys.cachedProfile);
    if (cached == null) return;
    try {
      _user = User.fromJson(jsonDecode(cached));
      _status = ProfileStatus.ready;
    } catch (e, st) {
      log.error('Corrupt cached profile, ignoring', e, st);
    }
  }

  Future<Result<User>> refresh() async {
    // Not announced: for the app "unknown" and "loading" look the same, and
    // this may run while the widget tree is being built.
    if (_user == null) _status = ProfileStatus.loading;
    final result = await _api.me();
    switch (result) {
      case Ok(:final value):
        _user = value;
        _status = ProfileStatus.ready;
        await _store.setString(
          StoreKeys.cachedProfile,
          jsonEncode(value.toJson()),
        );
      case Error(:final error):
        log.warning('Profile not refreshed: $error');
        if (_user == null) _status = ProfileStatus.unavailable;
    }
    notifyListeners();
    return result;
  }

  Future<Result<void>> updateName({
    required String firstName,
    required String lastName,
  }) async {
    final result = await _api.updateName(
      firstName: firstName,
      lastName: lastName,
    );
    if (result case Error(:final error)) return Result.error(error);
    return switch (await refresh()) {
      Ok() => const Result.ok(null),
      Error(:final error) => Result.error(error),
    };
  }

  Future<void> clear() async {
    _user = null;
    _status = ProfileStatus.unknown;
    await _store.remove(StoreKeys.cachedProfile);
    notifyListeners();
  }
}
