import 'package:driver_tracking_app/data/services/local_store.dart';

class FakeLocalStore implements LocalStore {
  FakeLocalStore([Map<String, Object>? initial]) : values = {...?initial};

  final Map<String, Object> values;

  @override
  String? getString(String key) => values[key] as String?;

  @override
  bool? getBool(String key) => values[key] as bool?;

  @override
  Future<void> setString(String key, String value) async => values[key] = value;

  @override
  Future<void> setBool(String key, bool value) async => values[key] = value;

  @override
  Future<void> remove(String key) async => values.remove(key);
}
