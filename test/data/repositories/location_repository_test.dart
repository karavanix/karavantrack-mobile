import 'dart:async';

import 'package:driver_tracking_app/data/repositories/location_repository.dart';
import 'package:driver_tracking_app/domain/models/location_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../testing/fake_services.dart';

void main() {
  late FakeLocationStatusService phone;
  late LocationRepository location;
  late int disclosures;

  Future<bool> allow() async {
    disclosures++;
    return true;
  }

  Future<bool> notNow() async {
    disclosures++;
    return false;
  }

  setUp(() {
    phone = FakeLocationStatusService(access: LocationAccess.denied);
    location = LocationRepository(service: phone);
    disclosures = 0;
  });

  tearDown(() => location.dispose());

  test('nothing is reported wrong before the first check', () {
    expect(location.state.problem, isNull);
  });

  test('"Allow": while-in-use first, then "all the time" on its own', () async {
    await location.requestAccess(allow);

    expect(disclosures, 1);
    expect(phone.requests, ['whileInUse', 'always']);
    expect(location.state.access, LocationAccess.always);
    expect(location.state.problem, isNull);
    expect(location.promptsDone, isTrue);
  });

  test('"Not now": no system prompt, the overlay explains', () async {
    await location.requestAccess(notNow);

    expect(phone.requests, isEmpty);
    expect(location.state.problem, LocationProblem.noAlwaysAccess);
    expect(location.promptsDone, isTrue);
  });

  test('while-in-use already given: only the upgrade is asked', () async {
    phone.access = LocationAccess.whileInUse;

    await location.requestAccess(allow);

    expect(phone.requests, ['always']);
  });

  test('"all the time" already given: no disclosure at all', () async {
    phone.access = LocationAccess.always;

    await location.requestAccess(allow);

    expect(disclosures, 0);
    expect(location.promptsDone, isTrue);
  });

  test('declined at the system prompt: the overlay explains', () async {
    phone.grantAtAlways = LocationAccess.whileInUse;

    await location.requestAccess(allow);

    expect(location.state.problem, LocationProblem.noAlwaysAccess);
  });

  test('the disclosure is shown once per sign-in', () async {
    await location.requestAccess(notNow);
    await location.requestAccess(notNow);
    expect(disclosures, 1);

    location.reset();
    await location.requestAccess(notNow);
    expect(disclosures, 2);
  });

  test('a call while the flow runs does nothing', () async {
    // Every system prompt pauses and resumes the app; each resume calls in.
    final answer = Completer<bool>();
    final first = location.requestAccess(() {
      disclosures++;
      return answer.future;
    });
    await Future<void>.delayed(Duration.zero);

    await location.requestAccess(allow);
    answer.complete(true);
    await first;

    expect(disclosures, 1);
    expect(phone.requests, ['whileInUse', 'always']);
  });

  test('GPS off comes first among the problems', () async {
    phone
      ..serviceEnabled = false
      ..precise = false;

    await location.check();

    expect(location.state.problem, LocationProblem.gpsOff);

    phone.serviceEnabled = true;
    phone.access = LocationAccess.always;
    await location.check();
    expect(location.state.problem, LocationProblem.notPrecise);
  });

  test('watching notices GPS being switched off', () async {
    phone.access = LocationAccess.always;
    final watched = LocationRepository(
      service: phone,
      pollInterval: const Duration(milliseconds: 10),
    );
    addTearDown(watched.dispose);
    watched.watch(true);

    phone.serviceEnabled = false;
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(watched.state.problem, LocationProblem.gpsOff);
    watched.watch(false);
  });
}
