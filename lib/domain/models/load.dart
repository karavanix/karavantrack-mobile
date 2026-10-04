/// The load statuses the server knows, in lifecycle order. The driver moves
/// a load from [assigned] to [droppedOff]; the shipper assigns, confirms and
/// cancels.
enum LoadStatus {
  created('created'),
  assigned('assigned'),
  accepted('accepted'),
  pickingUp('picking_up'),
  pickedUp('picked_up'),
  inTransit('in_transit'),
  droppingOff('dropping_off'),
  droppedOff('dropped_off'),
  confirmed('confirmed'),
  cancelled('cancelled'),

  /// A status this build doesn't know (added on the server later). Shown
  /// as is, with no action.
  unknown('');

  const LoadStatus(this.wire);

  /// The status as the API spells it.
  final String wire;

  static LoadStatus fromWire(String? value) => values.firstWhere(
    (s) => s.wire == value && s != unknown,
    orElse: () => unknown,
  );

  /// The driver has the load: from accepting it until the shipper confirms
  /// delivery. The server allows one such load per driver.
  bool get isActive => switch (this) {
    accepted ||
    pickingUp ||
    pickedUp ||
    inTransit ||
    droppingOff ||
    droppedOff => true,
    _ => false,
  };

  /// Position on the six-step stepper (accepted … dropped off): 0-5, 6 once
  /// confirmed (every step done), null where the stepper isn't shown.
  int? get step => switch (this) {
    accepted => 0,
    pickingUp => 1,
    pickedUp => 2,
    inTransit => 3,
    droppingOff => 4,
    droppedOff => 5,
    confirmed => 6,
    _ => null,
  };

  /// What the driver does next, or null when it's not their move.
  LoadAction? get nextAction => switch (this) {
    assigned => LoadAction.accept,
    accepted => LoadAction.beginPickup,
    pickingUp => LoadAction.confirmPickup,
    pickedUp => LoadAction.start,
    inTransit => LoadAction.beginDropoff,
    droppingOff => LoadAction.confirmDropoff,
    _ => null,
  };
}

/// The driver's steps through a load, each a `POST /loads/{id}/<path>`.
enum LoadAction {
  accept('accept'),
  beginPickup('pickup/begin'),
  confirmPickup('pickup/confirm'),
  start('start'),
  beginDropoff('dropoff/begin'),
  confirmDropoff('dropoff/confirm');

  const LoadAction(this.path);

  final String path;

  /// A photo of the cargo or its papers may go with the step. Accepting
  /// is only a yes to the offer, there's nothing to show yet.
  bool get takesPhoto => this != accept;
}

/// One entry of a load's status history.
class LoadStatusChange {
  const LoadStatusChange({
    required this.from,
    required this.to,
    required this.at,
  });

  factory LoadStatusChange.fromJson(Object? json) {
    final map = json as Map<String, Object?>;
    return LoadStatusChange(
      from: LoadStatus.fromWire(map['from_status'] as String?),
      to: LoadStatus.fromWire(map['to_status'] as String?),
      at: DateTime.parse(map['created_at'] as String),
    );
  }

  final LoadStatus from;
  final LoadStatus to;
  final DateTime at;

  Map<String, Object?> toJson() => {
    'from_status': from.wire,
    'to_status': to.wire,
    'created_at': at.toUtc().toIso8601String(),
  };
}

/// A load as the driver sees it: `GET /loads/{id}`, `/loads/active` (both
/// with [history]) and the lists (without).
class Load {
  const Load({
    required this.id,
    required this.title,
    required this.status,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.createdAt,
    this.description = '',
    this.referenceId,
    this.pickupAt,
    this.dropoffAt,
    this.updatedAt,
    this.history = const [],
  });

  factory Load.fromJson(Object? json) {
    final map = json as Map<String, Object?>;
    DateTime? date(String key) => DateTime.tryParse(map[key] as String? ?? '');
    final reference = map['reference_id'] as String?;
    return Load(
      id: map['id'] as String,
      title: map['title'] as String? ?? '',
      status: LoadStatus.fromWire(map['status'] as String?),
      description: map['description'] as String? ?? '',
      referenceId: reference == null || reference.isEmpty ? null : reference,
      pickupAddress: map['pickup_address'] as String? ?? '',
      dropoffAddress: map['dropoff_address'] as String? ?? '',
      pickupAt: date('pickup_at'),
      dropoffAt: date('dropoff_at'),
      createdAt: date('created_at') ?? DateTime.now(),
      updatedAt: date('updated_at'),
      history: [
        for (final entry in map['history'] as List? ?? const [])
          LoadStatusChange.fromJson(entry),
      ],
    );
  }

  final String id;
  final String title;
  final LoadStatus status;
  final String description;
  final String? referenceId;
  final String pickupAddress;
  final String dropoffAddress;
  final DateTime? pickupAt;
  final DateTime? dropoffAt;
  final DateTime createdAt;
  final DateTime? updatedAt;

  /// Oldest first. Empty for a load that came from a list.
  final List<LoadStatusChange> history;

  /// Stands in for an empty title: `#1a2b3c4d`.
  String get shortId => '#${id.length > 8 ? id.substring(0, 8) : id}';

  Load withHistory(List<LoadStatusChange> history) => Load(
    id: id,
    title: title,
    status: status,
    description: description,
    referenceId: referenceId,
    pickupAddress: pickupAddress,
    dropoffAddress: dropoffAddress,
    pickupAt: pickupAt,
    dropoffAt: dropoffAt,
    createdAt: createdAt,
    updatedAt: updatedAt,
    history: history,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'status': status.wire,
    'description': description,
    'reference_id': ?referenceId,
    'pickup_address': pickupAddress,
    'dropoff_address': dropoffAddress,
    'pickup_at': ?pickupAt?.toUtc().toIso8601String(),
    'dropoff_at': ?dropoffAt?.toUtc().toIso8601String(),
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': ?updatedAt?.toUtc().toIso8601String(),
    'history': [for (final entry in history) entry.toJson()],
  };
}

/// One page of `GET /loads/pending` or `/loads/history`.
class LoadPage {
  const LoadPage({required this.items, required this.total});

  factory LoadPage.fromJson(Object? json) {
    final map = json as Map<String, Object?>;
    final items = [
      for (final item in map['result'] as List? ?? const [])
        Load.fromJson(item),
    ];
    return LoadPage(items: items, total: map['count'] as int? ?? items.length);
  }

  final List<Load> items;

  /// All matching loads on the server, across pages.
  final int total;
}
