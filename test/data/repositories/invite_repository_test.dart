import 'package:driver_tracking_app/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../testing/test_graph.dart';

void main() {
  group('links', () {
    final cases = {
      'https://app.yool.live/invite/abc': 'abc',
      'https://app.yool.live/invite/abc/': 'abc',
      'yoollive://invite/abc': 'abc',
      'https://app.yool.live/track/abc': null,
      'yoollive://tglogin?code=1&state=2': null,
      'https://app.yool.live/invite/': null,
    };
    cases.forEach((link, token) {
      test(link, () {
        final g = TestGraph();
        g.invites.handleLink(Uri.parse(link));
        expect(g.invites.token, token);
      });
    });
  });

  test('links arriving from the link service are picked up', () async {
    final g = TestGraph();
    g.invites; // created, listening

    g.links.controller.add(Uri.parse('yoollive://invite/xyz'));
    await settle();

    expect(g.invites.token, 'xyz');
  });

  test('a new link drops "Log in & accept" from the previous one', () {
    final g = TestGraph();
    g.invites
      ..handleLink(Uri.parse('yoollive://invite/a'))
      ..requestSignIn()
      ..handleLink(Uri.parse('yoollive://invite/b'));

    expect(g.invites.token, 'b');
    expect(g.invites.acceptAfterSignIn, isFalse);
  });

  test('accepting clears the invite and remembers the load', () async {
    final g = TestGraph.signedIn();
    g.backend.invites['tok'] = (
      status: 'pending',
      loadId: 'L1',
      acceptedByMe: false,
    );
    g.invites
      ..handleLink(Uri.parse('yoollive://invite/tok'))
      ..requestSignIn();

    final result = await g.invites.accept();

    expect((result as Ok<String>).value, 'L1');
    expect(g.invites.token, isNull);
    expect(g.invites.acceptAfterSignIn, isFalse);
    expect(g.invites.acceptedLoadId, 'L1');
  });
}
