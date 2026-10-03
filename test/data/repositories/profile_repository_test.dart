import 'package:driver_tracking_app/data/repositories/profile_repository.dart';
import 'package:driver_tracking_app/data/services/local_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../testing/test_graph.dart';

void main() {
  test('the copy on the device is there before any request', () {
    final g = TestGraph.signedIn();

    g.profile.restore();

    expect(g.profile.status, ProfileStatus.ready);
    expect(g.profile.user?.firstName, 'Ali');
    expect(g.backend.requestsTo('/users/me'), isEmpty);
  });

  test('a refresh replaces the copy and saves it', () async {
    final g = TestGraph.signedIn(cachedProfile: false);
    g.backend.firstName = 'Bobur';

    await g.profile.refresh();

    expect(g.profile.user?.firstName, 'Bobur');
    expect(g.store.values[StoreKeys.cachedProfile], contains('Bobur'));
  });

  test('offline with a copy: keeps the copy', () async {
    final g = TestGraph.signedIn()..backend.online = false;
    g.profile.restore();

    await g.profile.refresh();

    expect(g.profile.status, ProfileStatus.ready);
    expect(g.profile.user?.firstName, 'Ali');
  });

  test('offline with no copy: unavailable, not "incomplete"', () async {
    final g = TestGraph.signedIn(cachedProfile: false)..backend.online = false;

    await g.profile.refresh();

    expect(g.profile.status, ProfileStatus.unavailable);
    expect(g.profile.user, isNull);
  });

  test('saving the name sends it and reloads', () async {
    final g = TestGraph.signedIn();

    await g.profile.updateName(firstName: 'Jasur', lastName: 'Karimov');

    expect(g.backend.firstName, 'Jasur');
    expect(g.profile.user?.fullName, 'Jasur Karimov');
  });

  test('clear forgets the copy', () async {
    final g = TestGraph.signedIn()..profile.restore();

    await g.profile.clear();

    expect(g.profile.user, isNull);
    expect(g.store.values.containsKey(StoreKeys.cachedProfile), isFalse);
  });
}
