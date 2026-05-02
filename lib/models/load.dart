import '../l10n/app_localizations.dart';

/// All backend load statuses.
enum LoadStatus {
  created,
  assigned,
  accepted,
  pickingUp,
  pickedUp,
  inTransit,
  droppingOff,
  droppedOff,
  completed,
  confirmed,
  cancelled;

  static LoadStatus fromString(String raw) {
    switch (raw.toLowerCase()) {
      case 'created':
        return LoadStatus.created;
      case 'assigned':
        return LoadStatus.assigned;
      case 'accepted':
        return LoadStatus.accepted;
      case 'picking_up':
      case 'pickingup':
        return LoadStatus.pickingUp;
      case 'picked_up':
      case 'pickedup':
        return LoadStatus.pickedUp;
      case 'in_transit':
      case 'intransit':
        return LoadStatus.inTransit;
      case 'dropping_off':
      case 'droppingoff':
        return LoadStatus.droppingOff;
      case 'dropped_off':
      case 'droppedoff':
        return LoadStatus.droppedOff;
      case 'completed':
        return LoadStatus.completed;
      case 'confirmed':
        return LoadStatus.confirmed;
      case 'cancelled':
        return LoadStatus.cancelled;
      default:
        return LoadStatus.created;
    }
  }

  String get label {
    switch (this) {
      case LoadStatus.created:
        return 'Created';
      case LoadStatus.assigned:
        return 'Assigned';
      case LoadStatus.accepted:
        return 'Accepted';
      case LoadStatus.pickingUp:
        return 'Picking Up';
      case LoadStatus.pickedUp:
        return 'Picked Up';
      case LoadStatus.inTransit:
        return 'In Transit';
      case LoadStatus.droppingOff:
        return 'Dropping Off';
      case LoadStatus.droppedOff:
        return 'Dropped Off';
      case LoadStatus.completed:
        return 'Completed';
      case LoadStatus.confirmed:
        return 'Confirmed';
      case LoadStatus.cancelled:
        return 'Cancelled';
    }
  }

  String localizedLabel(AppLocalizations t) {
    switch (this) {
      case LoadStatus.created:
        return t.tr('statusCreated');
      case LoadStatus.assigned:
        return t.tr('statusAssigned');
      case LoadStatus.accepted:
        return t.tr('statusAccepted');
      case LoadStatus.pickingUp:
        return t.tr('statusPickingUp');
      case LoadStatus.pickedUp:
        return t.tr('statusPickedUp');
      case LoadStatus.inTransit:
        return t.tr('statusInTransit');
      case LoadStatus.droppingOff:
        return t.tr('statusDroppingOff');
      case LoadStatus.droppedOff:
        return t.tr('statusDroppedOff');
      case LoadStatus.completed:
        return t.tr('statusCompleted');
      case LoadStatus.confirmed:
        return t.tr('statusConfirmed');
      case LoadStatus.cancelled:
        return t.tr('statusCancelled');
    }
  }

  /// Whether the load is actively being tracked (GPS runs for all these).
  bool get isActive =>
      this == LoadStatus.accepted ||
      this == LoadStatus.pickingUp ||
      this == LoadStatus.pickedUp ||
      this == LoadStatus.inTransit ||
      this == LoadStatus.droppingOff ||
      this == LoadStatus.droppedOff;

  /// Terminal statuses — no further actions possible.
  bool get isFinal =>
      this == LoadStatus.completed ||
      this == LoadStatus.confirmed ||
      this == LoadStatus.cancelled;

  /// Step index 0–5 for the 6 active statuses, -1 for non-active.
  int get stepIndex {
    switch (this) {
      case LoadStatus.accepted:
        return 0;
      case LoadStatus.pickingUp:
        return 1;
      case LoadStatus.pickedUp:
        return 2;
      case LoadStatus.inTransit:
        return 3;
      case LoadStatus.droppingOff:
        return 4;
      case LoadStatus.droppedOff:
        return 5;
      default:
        return -1;
    }
  }

  /// i18n key for the next action button; null when no action is available.
  String? get nextActionKey {
    switch (this) {
      case LoadStatus.assigned:
        return 'acceptLoad';
      case LoadStatus.accepted:
        return 'actionBeginPickup';
      case LoadStatus.pickingUp:
        return 'actionConfirmPickup';
      case LoadStatus.pickedUp:
        return 'actionStartTransit';
      case LoadStatus.inTransit:
        return 'actionBeginDropoff';
      case LoadStatus.droppingOff:
        return 'actionConfirmDropoff';
      default:
        return null;
    }
  }
}

/// A single entry from the load's status history (from `LoadDetailResponse.history`).
class LoadHistoryItem {
  const LoadHistoryItem({
    required this.fromStatus,
    required this.toStatus,
    required this.changedAt,
  });

  final String fromStatus;
  final String toStatus;
  final DateTime changedAt;

  factory LoadHistoryItem.fromJson(Map<String, dynamic> json) {
    return LoadHistoryItem(
      fromStatus: json['from_status'] as String? ?? '',
      toStatus: json['to_status'] as String? ?? '',
      changedAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now().toUtc(),
    );
  }
}

/// Represents a load from the backend `query.LoadResponse`.
class LoadItem {
  LoadItem({
    required this.id,
    required this.title,
    required this.description,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.pickupLat,
    required this.pickupLng,
    required this.dropoffLat,
    required this.dropoffLng,
    required this.status,
    required this.createdAt,
    this.carrierId,
    this.companyId,
    this.memberId,
    this.referenceId,
    this.pickupAt,
    this.dropoffAt,
    this.updatedAt,
    this.history = const [],
  });

  final String id;
  final String title;
  final String description;
  final String pickupAddress;
  final String dropoffAddress;
  final double pickupLat;
  final double pickupLng;
  final double dropoffLat;
  final double dropoffLng;
  final String? carrierId;
  final String? companyId;
  final String? memberId;
  final String? referenceId;
  final DateTime createdAt;
  final DateTime? pickupAt;
  final DateTime? dropoffAt;
  final DateTime? updatedAt;
  final List<LoadHistoryItem> history;

  LoadStatus status;

  factory LoadItem.fromJson(Map<String, dynamic> json) {
    final rawHistory = json['history'] as List<dynamic>? ?? [];
    return LoadItem(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      pickupAddress: json['pickup_address'] as String? ?? '',
      dropoffAddress: json['dropoff_address'] as String? ?? '',
      pickupLat: (json['pickup_lat'] as num?)?.toDouble() ?? 0,
      pickupLng: (json['pickup_lng'] as num?)?.toDouble() ?? 0,
      dropoffLat: (json['dropoff_lat'] as num?)?.toDouble() ?? 0,
      dropoffLng: (json['dropoff_lng'] as num?)?.toDouble() ?? 0,
      status: LoadStatus.fromString(json['status'] as String? ?? ''),
      carrierId: json['carrier_id'] as String?,
      companyId: json['company_id'] as String?,
      memberId: json['member_id'] as String?,
      referenceId: json['reference_id'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now().toUtc(),
      pickupAt: json['pickup_at'] != null
          ? DateTime.tryParse(json['pickup_at'] as String)
          : null,
      dropoffAt: json['dropoff_at'] != null
          ? DateTime.tryParse(json['dropoff_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
      history: rawHistory
          .map((e) => LoadHistoryItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
