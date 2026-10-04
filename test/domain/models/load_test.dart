import 'dart:convert';

import 'package:driver_tracking_app/domain/models/load.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads a load as the API sends it', () {
    final load = Load.fromJson(
      jsonDecode('''{
        "id": "0f3c2a1b-9d8e-4c7b-a6f5-e4d3c2b1a090",
        "title": "",
        "status": "in_transit",
        "reference_id": "",
        "pickup_address": "Tashkent",
        "dropoff_address": "Samarkand",
        "pickup_lat": 41.3, "pickup_lng": 69.2,
        "dropoff_lat": 39.6, "dropoff_lng": 66.9,
        "pickup_at": "2026-10-02T06:00:00Z",
        "created_at": "2026-10-01T08:00:00Z",
        "updated_at": "2026-10-01T09:00:00Z",
        "history": [
          {"id": 1, "from_status": "assigned", "to_status": "accepted",
           "created_at": "2026-10-01T08:30:00Z", "attachments": []}
        ]
      }'''),
    );

    expect(load.status, LoadStatus.inTransit);
    expect(load.shortId, '#0f3c2a1b');
    expect(load.referenceId, isNull);
    expect(load.pickupAt, DateTime.utc(2026, 10, 2, 6));
    expect(load.dropoffAt, isNull);
    expect(load.history.single.to, LoadStatus.accepted);
  });

  test('survives a round trip through the device cache', () {
    final load = Load.fromJson({
      'id': 'L1',
      'title': 'Cotton',
      'status': 'dropped_off',
      'reference_id': 'REF-7',
      'pickup_address': 'A',
      'dropoff_address': 'B',
      'dropoff_at': '2026-10-03T12:00:00Z',
      'created_at': '2026-10-01T08:00:00Z',
      'history': [
        {
          'from_status': 'dropping_off',
          'to_status': 'dropped_off',
          'created_at': '2026-10-03T12:00:00Z',
        },
      ],
    });

    final copy = Load.fromJson(jsonDecode(jsonEncode(load.toJson())));

    expect(copy.toJson(), load.toJson());
  });

  test('a status this build does not know is shown, not guessed', () {
    expect(LoadStatus.fromWire('on_hold'), LoadStatus.unknown);
    expect(LoadStatus.fromWire(''), LoadStatus.unknown);
    expect(LoadStatus.fromWire(null), LoadStatus.unknown);
    expect(LoadStatus.unknown.nextAction, isNull);
  });

  test('the driver moves a load one step at a time', () {
    expect(
      {for (final s in LoadStatus.values) s: s.nextAction},
      {
        LoadStatus.created: null,
        LoadStatus.assigned: LoadAction.accept,
        LoadStatus.accepted: LoadAction.beginPickup,
        LoadStatus.pickingUp: LoadAction.confirmPickup,
        LoadStatus.pickedUp: LoadAction.start,
        LoadStatus.inTransit: LoadAction.beginDropoff,
        LoadStatus.droppingOff: LoadAction.confirmDropoff,
        LoadStatus.droppedOff: null,
        LoadStatus.confirmed: null,
        LoadStatus.cancelled: null,
        LoadStatus.unknown: null,
      },
    );
  });

  test('active from accepted until the shipper confirms', () {
    expect(
      [
        for (final s in LoadStatus.values)
          if (s.isActive) s,
      ],
      [
        LoadStatus.accepted,
        LoadStatus.pickingUp,
        LoadStatus.pickedUp,
        LoadStatus.inTransit,
        LoadStatus.droppingOff,
        LoadStatus.droppedOff,
      ],
    );
  });
}
