import '../../../domain/models/load.dart';

/// Why a pending load can't be accepted right now: the server allows one
/// active load per driver.
enum AcceptBlock {
  /// The current load is still on the road.
  activeLoad,

  /// The current load is dropped off and waits for the shipper; the
  /// driver can't do anything about it but wait.
  awaitingConfirmation;

  static AcceptBlock? of(Load? active, Load load) {
    if (active == null || active.id == load.id) return null;
    return active.status == LoadStatus.droppedOff
        ? awaitingConfirmation
        : activeLoad;
  }
}
