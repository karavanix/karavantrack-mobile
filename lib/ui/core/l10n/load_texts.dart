import '../../../domain/models/load.dart';
import 'l10n.dart';

extension LoadTexts on AppLocalizations {
  String loadStatus(LoadStatus status) => switch (status) {
    LoadStatus.created => statusCreated,
    LoadStatus.assigned => statusAssigned,
    LoadStatus.accepted => statusAccepted,
    LoadStatus.pickingUp => statusPickingUp,
    LoadStatus.pickedUp => statusPickedUp,
    LoadStatus.inTransit => statusInTransit,
    LoadStatus.droppingOff => statusDroppingOff,
    LoadStatus.droppedOff => statusDroppedOff,
    LoadStatus.confirmed => statusConfirmed,
    LoadStatus.cancelled => statusCancelled,
    LoadStatus.unknown => statusUnknown,
  };

  String loadAction(LoadAction action) => switch (action) {
    LoadAction.accept => acceptLoad,
    LoadAction.beginPickup => actionBeginPickup,
    LoadAction.confirmPickup => actionConfirmPickup,
    LoadAction.start => actionStartTransit,
    LoadAction.beginDropoff => actionBeginDropoff,
    LoadAction.confirmDropoff => actionConfirmDropoff,
  };

  /// The six stepper labels, accepted … dropped off.
  List<String> get loadSteps => [
    stepAccepted,
    stepPickup,
    stepLoaded,
    stepTransit,
    stepDropoff,
    stepDelivered,
  ];

  /// The title, or `Load #1a2b3c4d` when the shipper left it empty.
  String loadTitle(Load item) =>
      item.title.isNotEmpty ? item.title : '$load ${item.shortId}';
}
