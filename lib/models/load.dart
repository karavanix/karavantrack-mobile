/// All backend load statuses.
enum LoadStatus {
  created,
  assigned,
  accepted,
  inTransit,
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
      case 'in_transit':
      case 'intransit':
        return LoadStatus.inTransit;
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
      case LoadStatus.inTransit:
        return 'In Transit';
      case LoadStatus.completed:
        return 'Completed';
      case LoadStatus.confirmed:
        return 'Confirmed';
      case LoadStatus.cancelled:
        return 'Cancelled';
    }
  }

  /// Whether the load is actively being tracked.
  bool get isActive =>
      this == LoadStatus.accepted || this == LoadStatus.inTransit;

  /// Terminal statuses.
  bool get isFinal =>
      this == LoadStatus.completed ||
      this == LoadStatus.confirmed ||
      this == LoadStatus.cancelled;
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

  LoadStatus status;

  factory LoadItem.fromJson(Map<String, dynamic> json) {
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
    );
  }
}
