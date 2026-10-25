import 'package:flutter_test/flutter_test.dart';
import 'package:bnb_wallet_gui/app_state.dart';
import 'package:bnb_wallet_gui/models.dart';
import 'package:bnb_wallet_gui/rpc_service.dart';
import 'package:bnb_wallet_gui/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppStorage.init();
  });

  group('node URL policy (spec §10d: https everywhere; http only for ' //
      'localhost/LAN/.onion)', () {
    test('accepts https and wss always', () {
      expect(nodeUrlAllowed('https://rpc.example.org'), isTrue);
      expect(nodeUrlAllowed('wss://ws.example.org'), isTrue);
    });

    test('accepts http for loopback and LAN and onion only', () {
      expect(nodeUrlAllowed('http://localhost:8545'), isTrue);
      expect(nodeUrlAllowed('http://127.0.0.1:8545'), isTrue);
      expect(nodeUrlAllowed('http://[::1]:8545'), isTrue);
      expect(nodeUrlAllowed('http://192.168.1.10:8545'), isTrue);
      expect(nodeUrlAllowed('http://10.0.0.2:8545'), isTrue);
      expect(nodeUrlAllowed('http://172.16.0.9:8545'), isTrue);
      expect(nodeUrlAllowed('http://my-node.example.onion'), isTrue);
      expect(nodeUrlAllowed('http://172.32.0.1'), isFalse,
          reason: '172.32.0.1 is public address space');
      expect(nodeUrlAllowed('http://8.8.8.8'), isFalse);
      expect(nodeUrlAllowed('http://rpc.example.org'), isFalse,
          reason: 'plain http over the open internet would be cleartext');
      expect(nodeUrlAllowed('ftp://rpc.example.org'), isFalse);
      expect(nodeUrlAllowed('not a url'), isFalse);
      expect(nodeUrlAllowed(''), isFalse);
    });
  });

  // Helper to create minimal RpcNode for pure tests
  RpcNode n(String url, {String label = 'n', String network = 'mainnet', bool enabled = true}) =>
      RpcNode(label: label, url: url, network: network, enabled: enabled);

  group('fee candidate pool (pure — no service construction)', () {
    final builtIn = [n('https://built-in-a'), n('https://built-in-b')];

    test('normal mode: active → configured → user book → built-ins, capped 3',
        () {
      final pool = RpcService.feeCandidatePool(
      selectionMode: NodeSelectionMode.manual,
        active: n('https://active'),
        configured: n('https://configured'),
        userPool: [n('https://book-1'), n('https://book-2')],
        builtInFallbacks: builtIn.map((n) => n.url).toList(),
        strict: false,
      );
      expect(pool.map((n) => n.url),
          ['https://active', 'https://configured', 'https://book-1']);
    });

    test('strict mode: EXACTLY the chosen door, nothing else', () {
      final pool = RpcService.feeCandidatePool(
      selectionMode: NodeSelectionMode.manual,
        active: n('https://active'),
        configured: n('https://configured'),
        userPool: [n('https://book-1')],
        builtInFallbacks: builtIn.map((n) => n.url).toList(),
        strict: true,
      );
      expect(pool.map((n) => n.url), ['https://active']);
    });

    test('strict mode with no active door = nothing to ask', () {
      final pool = RpcService.feeCandidatePool(
      selectionMode: NodeSelectionMode.manual,
        active: null,
        configured: n('https://configured'),
        userPool: [n('https://book-1')],
        builtInFallbacks: builtIn.map((n) => n.url).toList(),
        strict: true,
      );
      expect(pool, isEmpty);
    });

    test('strict mode never degrades to plain http', () {
      final pool = RpcService.feeCandidatePool(
      selectionMode: NodeSelectionMode.manual,
        active: null,
        configured: n('http://localhost'),
        userPool: const [],
        builtInFallbacks: builtIn.map((n) => n.url).toList(),
        strict: true,
      );
      expect(pool, isEmpty);
    });

    test('deduplicates and ignores unsafe urls in the book pool', () {
      final pool = RpcService.feeCandidatePool(
      selectionMode: NodeSelectionMode.manual,
        active: n('https://active'),
        configured: n('https://active'),
        userPool: [n('http://evil.example'), n('https://book-1')],
        builtInFallbacks: ['https://book-1'],
        strict: false,
      );
      expect(pool.map((n) => n.url),
          ['https://active', 'https://book-1']);
    });
  });

  group('independent node list (pure)', () {
    final builtIn = [n('https://b1'), n('https://b2')];

    test('user book doors first, minus the active one', () {
      final list = RpcService.independentNodeList(
        active: n('https://a'),
        userPool: [n('https://a'), n('https://u1'), n('https://u2')],
        builtInFallbacks: builtIn.map((n) => n.url).toList(),
        strict: false,
      );
      expect(list.map((n) => n.url), ['https://u1', 'https://u2']);
    });

    test('falls back to built-ins when the book is empty', () {
      final list = RpcService.independentNodeList(
        active: n('https://a'),
        userPool: const [],
        builtInFallbacks: builtIn.map((n) => n.url).toList(),
        strict: false,
      );
      expect(list.map((n) => n.url), ['https://b1', 'https://b2']);
    });

    test('strict mode = zero independent doors (receipt says exactly that)',
        () {
      final list = RpcService.independentNodeList(
        active: n('https://a'),
        userPool: [n('https://u1')],
        builtInFallbacks: builtIn.map((n) => n.url).toList(),
        strict: true,
      );
      expect(list, isEmpty);
    });
  });

  group('phone-book reorder (pure)', () {
    test('moves within the same network side only', () {
      final nodes = <RpcNode>[
        n('https://m1', label: 'main-1'),
        n('https://t1', label: 'test-1', network: 'testnet'),
        n('https://m2', label: 'main-2'),
        n('https://t2', label: 'test-2', network: 'testnet'),
      ];
      // index 2 (main-2) up → swaps with main-1 (index 0), skipping test-1.
      expect(moveNodeIndex(nodes, 2, -1), 0);
      // index 3 (test-2) up → lands on test-1 (index 1).
      expect(moveNodeIndex(nodes, 3, -1), 1);
      // already at the top book edge → stays.
      expect(moveNodeIndex(nodes, 2, -1), 0);
      expect(moveNodeIndex(nodes, 0, -1), 0);
      expect(moveNodeIndex(nodes, 3, 1), 3);
    });
  });
}

void mainAppState() {
  test('strict mode persists and gates the service flag', () async {
    SharedPreferences.setMockInitialValues({});
    await AppStorage.init();
    final state = AppState();
    expect(state.strictNodeMode, isFalse);
    await state.setStrictNodeMode(true);
    expect(state.strictNodeMode, isTrue);
    expect(AppStorage.strictNode, isTrue);
    expect(state.rpc.strictModeOn, isTrue);
  });

  test('enable/disable round-trips through storage', () async {
    SharedPreferences.setMockInitialValues({});
    await AppStorage.init();
    final state = AppState();
    await state.addNode('My door', 'https://door.example');
    expect(AppStorage.nodes.first.enabled, isTrue);
    await state.setNodeEnabled(0, false);
    expect(AppStorage.nodes.first.enabled, isFalse);
    await state.setNodeEnabled(0, true);
    expect(AppStorage.nodes.first.enabled, isTrue);
  });

  test('disabling the ACTIVE door falls back to the official door', () async {
    SharedPreferences.setMockInitialValues({});
    await AppStorage.init();
    final state = AppState();
    await state.addNode('Active door', 'https://active-door.example');
    await state.activateNode(state.nodes.last);
    expect(state.rpc.configuredRpc, 'https://active-door.example');
    await state.setNodeEnabled(0, false);
    expect(state.rpc.configuredRpc,
        'https://bsc-dataseed.bnbchain.org'); // official mainnet door
  });

  test('import dedupes, validates and fails closed', () async {
    SharedPreferences.setMockInitialValues({});
    await AppStorage.init();
    final state = AppState();
    await state.addNode('Book', 'https://already.example');

    final added = await state.importNodes(
        '[{"label":"New door","url":"https://new.example","network":"testnet"},'
        '{"label":"Book","url":"https://already.example","network":"testnet"}]');
    expect(added, 1);
    expect(AppStorage.nodes.map((n) => n.url),
        containsAll(['https://already.example', 'https://new.example']));

    // Unusable row → the WHOLE import fails, and nothing partial is kept
    // (fail closed).
    await expectLater(
      state.importNodes(
          '[{"label":"x","url":"https://fine.example"},'
          '{"label":"bad","url":"http://hot.example"}]'),
      throwsStateError,
    );
    expect(AppStorage.nodes.map((n) => n.url),
        isNot(contains('https://fine.example')));

    // Not JSON → refuses.
    await expectLater(
      state.importNodes('hello'),
      throwsStateError,
    );
  });

  test('export is plain JSON that round-trips through import', () async {
    SharedPreferences.setMockInitialValues({});
    await AppStorage.init();
    final state = AppState();
    await state.addNode('Only door', 'https://only.example');
    final exported = state.exportNodesJson();
    expect(exported, contains('only.example'));
    SharedPreferences.setMockInitialValues({});
    await AppStorage.init();
    final fresh = AppState();
    await fresh.importNodes(exported);
    expect(fresh.nodes.single.url, 'https://only.example');
  });

  test('one-time node warning remembered per URL (case-insensitive)',
      () async {
    SharedPreferences.setMockInitialValues({});
    await AppStorage.init();
    final state = AppState();
    expect(state.isNodeWarned('https://node.example'), isFalse);
    await state.markNodeWarned('https://node.example');
    expect(state.isNodeWarned('HTTPS://NODE.EXAMPLE'), isTrue);
    expect(state.isNodeWarned('https://other.example'), isFalse);
  });
}
