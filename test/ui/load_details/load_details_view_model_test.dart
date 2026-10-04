import 'dart:io';

import 'package:driver_tracking_app/domain/models/load.dart';
import 'package:driver_tracking_app/domain/use_cases/advance_load.dart';
import 'package:driver_tracking_app/ui/load_details/view_models/load_details_view_model.dart';
import 'package:driver_tracking_app/ui/loads/view_models/accept_block.dart';
import 'package:driver_tracking_app/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../testing/fake_services.dart';
import '../../testing/test_graph.dart';

void main() {
  late Directory dir;
  late String photo;
  late TestGraph g;
  late FakeCameraService camera;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('pod');
    photo = '${dir.path}/pod.jpg';
    File(photo).writeAsBytesSync([0xFF, 0xD8, 0xFF]);
    g = TestGraph.signedIn();
    g.backend.activeLoadId = 'A';
    await g.loads.refresh();
    camera = FakeCameraService();
  });

  tearDown(() => dir.deleteSync(recursive: true));

  LoadDetailsViewModel open(String id) {
    final vm = LoadDetailsViewModel(
      loadId: id,
      loads: g.loads,
      advance: g.advance,
      camera: camera,
    );
    addTearDown(vm.dispose);
    return vm;
  }

  test('fetches the load with its history on open', () async {
    g.backend.loads['A']!.history.add((from: 'assigned', to: 'accepted'));
    final vm = open('A');

    await pumpUntil(() => !vm.fetch.running);

    expect(vm.load?.history.single.to, LoadStatus.accepted);
    expect(vm.nextAction, LoadAction.beginPickup);
    expect(vm.photoAllowed, isTrue);
  });

  test('the photo goes with the step, then is cleared', () async {
    final vm = open('A');
    camera.next = photo;

    await vm.takePhoto();
    expect(vm.photoPath, photo);
    await vm.advance.execute();

    expect(vm.advance.completed, isTrue);
    expect(vm.photoPath, isNull);
    expect(g.backend.loads['A']!.attachments['picking_up'], ['att-1']);
    expect(vm.load?.status, LoadStatus.pickingUp);
  });

  test('a failed upload keeps the photo for another try', () async {
    final vm = open('A');
    camera.next = photo;
    g.backend.failUploads = true;

    await vm.takePhoto();
    await vm.advance.execute();

    expect(
      vm.advance.result,
      isA<Error<void>>().having(
        (e) => e.error,
        'error',
        isA<PhotoUploadException>(),
      ),
    );
    expect(vm.photoPath, photo);
    expect(vm.load?.status, LoadStatus.accepted);
  });

  test('backing out of the camera attaches nothing', () async {
    final vm = open('A');

    await vm.takePhoto();

    expect(vm.photoPath, isNull);
  });

  test('a pending load can\'t be accepted while another is active', () async {
    g.backend.addPending(1);
    await g.loads.refresh();
    final vm = open('P1');
    await pumpUntil(() => !vm.fetch.running);

    expect(vm.nextAction, LoadAction.accept);
    expect(vm.photoAllowed, isFalse);
    expect(vm.acceptBlock, AcceptBlock.activeLoad);

    g.backend.loads['A']!.status = 'dropped_off';
    await g.loads.refresh();
    expect(vm.acceptBlock, AcceptBlock.awaitingConfirmation);
  });

  test('a status moved on elsewhere brings the fresh history', () async {
    final vm = open('A');
    await pumpUntil(() => !vm.fetch.running);
    final fetches = g.backend.requestsTo('/loads/A').length;

    // The shipper cancelled; a push refreshed the lists.
    g.backend.loads['A']!
      ..history.add((from: 'accepted', to: 'cancelled'))
      ..status = 'cancelled';
    await g.loads.refreshHistory();

    await pumpUntil(
      () => g.backend.requestsTo('/loads/A').length == fetches + 1,
    );
    await pumpUntil(() => vm.load?.history.isNotEmpty ?? false);
    expect(vm.load?.status, LoadStatus.cancelled);
  });
}
