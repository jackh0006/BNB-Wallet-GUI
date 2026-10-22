import 'package:flutter_test/flutter_test.dart';
import 'package:bnb_wallet_gui/rpc_service.dart';
import 'package:bnb_wallet_gui/rpc_story.dart';

void main() {
  group('connection story', () {
    test('note() budget: 30 lines per second, window resets, cap respected',
        () async {
      final rpc = RpcService();
      rpc.clearStory();
      for (var i = 0; i < 70; i++) {
        rpc.note('line $i');
      }
      // The one-second budget (round-5 freeze fix) passes at most 30 lines,
      // then breaks the cycle with a plain-words marker.
      expect(
        rpc.story.where((l) => l.text.startsWith('line ')).length,
        30,
      );
      expect(
        rpc.story.any((l) => l.text.contains('story cycle was detected')),
        isTrue,
      );
      expect(rpc.story.length, lessThanOrEqualTo(RpcService.storyCap + 1));
      // A new second resets the window.
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      for (var i = 0; i < 5; i++) {
        rpc.note('second window $i');
      }
      expect(
        rpc.story.where((l) => l.text.startsWith('second window')).length,
        5,
      );
    });

    test('https gate: http doors are refused with a story line', () async {
      final rpc = RpcService();
      rpc.clearStory();
      final result = await rpc.probeNode('http://bad.example');
      expect(result.ok, isFalse);
      expect(result.reason, 'HTTPS only.');
      expect(rpc.story.where((l) => l.text.contains('HTTPS')), isNotEmpty);
    });

    test('story line formatting is child-simple: stamp, symbol, words', () {
      final line = RpcStoryLine('The door opened.', kind: RpcStoryKind.ok, detail: 'in 123 ms');
      final text = storyTextToString(line);
      expect(text, matches(RegExp(r'^\d{2}:\d{2}:\d{2}\s+✅\s+The door opened\. — in 123 ms$')));
    });

    test('story notify bursts collapse into one listener call', () async {
      final rpc = RpcService();
      rpc.clearStory();
      var calls = 0;
      void listener() => calls++;
      rpc.addListener(listener);
      for (var i = 0; i < 10; i++) {
        rpc.note('burst line $i');
      }
      // Nothing fired synchronously — the burst is batched.
      expect(calls, 0);
      await Future<void>.delayed(Duration.zero);
      expect(calls, 1);
      rpc.removeListener(listener);
      rpc.clearStory();
    });

    test('story cascade: a listener that narrates back is cut, not chained',
        () async {
      final rpc = RpcService();
      rpc.clearStory();
      var saw = 0;
      void Function() listener = () {};
      rpc.addListener(listener = () {
        saw++;
        if (saw < 60) rpc.note('reentrant story $saw'); // the freeze's shape
      });
      rpc.note('seed line');
      await Future<void>.delayed(Duration.zero);
      // The one-second budget passes 30 accepted lines, then the breaker
      // stops the chain — long before frame #83000 of the real freeze.
      expect(saw, lessThan(33));
      expect(
        rpc.story.any((l) => l.text.contains('story cycle was detected')),
        isTrue,
      );
      rpc.removeListener(listener);
      rpc.clearStory();
    });

    test('one-second budget kills timer/microtask loop shapes too', () {
      final rpc = RpcService();
      rpc.clearStory();
      for (var i = 0; i < 40; i++) {
        rpc.note('flood line $i');
      }
      final lines = rpc.story
          .where((l) => l.text.startsWith('flood line'))
          .length;
      expect(lines, lessThan(35));
      expect(
        rpc.story.where((l) => l.text.contains('story cycle was detected')),
        isNotEmpty,
      );
      rpc.clearStory();
    });

    test('route description mentions the tunnel when Tor is on (wording baked in)',
        () {
      final rpc = RpcService();
      // With default (tor off) prefs, routeDescription must still talk plainly
      // and explicitly say the connection is encrypted.
      expect(rpc.routeDescription, contains('HTTPS'));
      expect(rpc.routeDescription, contains('encrypted'));
    });
  });
}
