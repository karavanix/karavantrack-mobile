enum InviteStatus { pending, accepted, expired, revoked, unknown }

/// A driver invite, from the public `GET /invites/{token}`.
class Invite {
  const Invite({
    required this.status,
    required this.acceptedByMe,
    required this.loadId,
    required this.load,
  });

  factory Invite.fromJson(Object? json) {
    final map = json as Map<String, Object?>;
    return Invite(
      status: switch (map['status']) {
        'pending' => InviteStatus.pending,
        'accepted' => InviteStatus.accepted,
        'expired' => InviteStatus.expired,
        'revoked' => InviteStatus.revoked,
        _ => InviteStatus.unknown,
      },
      acceptedByMe: map['accepted_by_me'] as bool? ?? false,
      loadId: map['load_id'] as String?,
      load: InviteLoad.fromJson(map['load'] ?? const <String, Object?>{}),
    );
  }

  final InviteStatus status;

  /// The invite was accepted by the user asking (the request carried their
  /// token). Reopening one's own accepted link continues to the load.
  final bool acceptedByMe;
  final String? loadId;
  final InviteLoad load;
}

/// What the invite shows about the load before it's accepted.
class InviteLoad {
  const InviteLoad({
    required this.title,
    required this.companyName,
    required this.pickupAddress,
    required this.dropoffAddress,
    this.referenceId,
    this.pickupAt,
    this.dropoffAt,
  });

  factory InviteLoad.fromJson(Object? json) {
    final map = json as Map<String, Object?>;
    return InviteLoad(
      title: map['title'] as String? ?? '',
      companyName: map['company_name'] as String? ?? '',
      pickupAddress: map['pickup_address'] as String? ?? '',
      dropoffAddress: map['dropoff_address'] as String? ?? '',
      referenceId: map['reference_id'] as String?,
      pickupAt: DateTime.tryParse(map['pickup_at'] as String? ?? ''),
      dropoffAt: DateTime.tryParse(map['dropoff_at'] as String? ?? ''),
    );
  }

  final String title;
  final String companyName;
  final String pickupAddress;
  final String dropoffAddress;
  final String? referenceId;
  final DateTime? pickupAt;
  final DateTime? dropoffAt;
}
