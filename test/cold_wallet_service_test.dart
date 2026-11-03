import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bnb_wallet_gui/cold_wallet.dart';
import 'package:bnb_wallet_gui/cold_wallet_protocol.dart';
import 'package:bnb_wallet_gui/cold_wallet_service.dart';
import 'package:bnb_wallet_gui/rpc_service.dart';
import 'package:bnb_wallet_gui/storage.dart';

/// A broadcast-only fake. It never opens a socket: the service test proves the
/// verify-before-broadcast gate, not node connectivity.
class _FakeRpc extends RpcService {
  _FakeRpc(this.answer);

  final String Function(String raw) answer;
  final List<String> broadcast = [];

  @override
  Future<String> sendRawHex(String rawHex) async {
    broadcast.add(rawHex);
    return answer(rawHex);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const phrase = 'test test test test test test test test test test test junk';
  const from = '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266';
  const to = '0x70997970C51812dc3A010C7d01b50e0d17dc79C8';

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await AppStorage.init();
  });

  setUp(() async {
    await ColdWalletService.resetForTests();
  });

  ColdTxRequest newRequest({
    Duration lifetime = const Duration(minutes: 10),
    BigInt? value,
  }) {
    return ColdWalletService.instance.createRequest(
      chainId: 56,
      from: from,
      to: to,
      value: value ?? BigInt.from(10).pow(18),
      gasLimit: BigInt.from(21000),
      maxFeePerGas: BigInt.from(1000000000),
      maxPriorityFeePerGas: BigInt.from(1000000000),
      nonce: 0,
      data: '0x',
      assetInfo: const ColdTxAssetInfo(isNative: true, symbol: 'BNB'),
      lifetime: lifetime,
    );
  }

  ColdTxRequest copyWith(
    ColdTxRequest original, {
    String? value,
    String? recipient,
    int? nonce,
    int? chainId,
  }) {
    return ColdTxRequest(
      version: original.version,
      chainId: chainId ?? original.chainId,
      from: original.from,
      to: recipient ?? original.to,
      value: value ?? original.value,
      gasLimit: original.gasLimit,
      maxFeePerGas: original.maxFeePerGas,
      maxPriorityFeePerGas: original.maxPriorityFeePerGas,
      nonce: nonce ?? original.nonce,
      data: original.data,
      assetInfo: original.assetInfo,
      expiresAt: original.expiresAt,
      createdAt: original.createdAt,
      id: original.id,
    );
  }

  group('pairing persistence', () {
    test('saves and reloads only public pairing data', () async {
      final pairing = ColdWalletProtocol.exportPairing(
        walletName: 'cold test',
        chainId: 56,
        addresses: const [from, to],
      );
      await ColdWalletService.instance.savePairing(pairing);
      final loaded = await ColdWalletService.instance.loadPairing();
      expect(loaded, isNotNull);
      expect(loaded!.fingerprint, pairing.fingerprint);
      expect(loaded.addresses, [from, to]);
      await ColdWalletService.instance.clearPairing();
      expect(await ColdWalletService.instance.loadPairing(), isNull);
    });
  });

  group('pending requests', () {
    test('stores and lists a valid request', () async {
      final request = newRequest();
      await ColdWalletService.instance.storePendingRequest(request);
      final pending = await ColdWalletService.instance.pendingRequests();
      expect(pending, hasLength(1));
      expect(pending.single.id, request.id);
      expect(pending.single.value, request.value);
    });

    test('refuses an identical request ID twice', () async {
      final request = newRequest();
      await ColdWalletService.instance.storePendingRequest(request);
      expect(
        () => ColdWalletService.instance.storePendingRequest(request),
        throwsA(isA<ColdProtocolException>()),
      );
    });

    test('expired requests disappear from storage', () async {
      final request = newRequest(lifetime: const Duration(milliseconds: 120));
      await ColdWalletService.instance.storePendingRequest(request);
      expect(
        await ColdWalletService.instance.latestPendingRequest(),
        isNotNull,
      );
      await Future<void>.delayed(const Duration(milliseconds: 250));
      expect(await ColdWalletService.instance.latestPendingRequest(), isNull);
      expect(
        await ColdWalletService.instance.pendingRequestById(request.id!),
        isNull,
      );
    });

    test('storage is bounded and drops the oldest entries', () async {
      for (var i = 0; i < 25; i++) {
        await ColdWalletService.instance.storePendingRequest(
          newRequest(value: BigInt.from(i + 1)),
        );
      }
      final pending = await ColdWalletService.instance.pendingRequests();
      expect(pending.length, lessThanOrEqualTo(20));
    });
  });

  group('offline signing', () {
    test('signs once and returns the same response on repeat', () async {
      final request = newRequest();
      await ColdWalletService.instance.storePendingRequest(request);
      final first = await ColdWalletService.instance.signRequest(
        request: request,
        phrase: phrase,
      );
      final second = await ColdWalletService.instance.signRequest(
        request: request,
        phrase: phrase,
      );
      expect(second.signedTxHash, first.signedTxHash);
      expect(second.rawSignedTx, first.rawSignedTx);
      expect(
        await ColdWalletService.instance.isRequestSigned(request.id!),
        isTrue,
      );

      final verified = await ColdWalletService.instance.verifyResponse(
        request: request,
        signature: first,
        expectedFrom: from,
      );
      expect(verified.ok, isTrue, reason: verified.reason);
      expect(verified.txHash, first.signedTxHash);
    });

    test('a replayed request ID with different bytes is refused', () async {
      final request = newRequest();
      await ColdWalletService.instance.storePendingRequest(request);
      await ColdWalletService.instance.signRequest(
        request: request,
        phrase: phrase,
      );
      final altered = copyWith(request, value: '0x01');
      expect(
        () => ColdWalletService.instance.signRequest(
          request: altered,
          phrase: phrase,
        ),
        throwsA(
          isA<ColdProtocolException>().having(
            (e) => e.message,
            'message',
            contains('different bytes'),
          ),
        ),
      );
    });

    test('a request from another wallet is refused', () async {
      final request = newRequest();
      final foreign = ColdTxRequest(
        version: request.version,
        chainId: request.chainId,
        // Not derived from the public test mnemonic at any default index.
        from: '0x1111111111111111111111111111111111111111',
        to: to,
        value: request.value,
        gasLimit: request.gasLimit,
        maxFeePerGas: request.maxFeePerGas,
        maxPriorityFeePerGas: request.maxPriorityFeePerGas,
        nonce: request.nonce,
        data: request.data,
        assetInfo: request.assetInfo,
        expiresAt: request.expiresAt,
        createdAt: request.createdAt,
        id: request.id,
      );
      expect(
        () => ColdWalletService.instance.signRequest(
          request: foreign,
          phrase: phrase,
        ),
        throwsA(isA<ColdProtocolException>()),
      );
    });
  });

  group('strict response verification', () {
    late ColdTxRequest request;
    late ColdTxSignature signature;

    setUp(() async {
      request = newRequest();
      await ColdWalletService.instance.storePendingRequest(request);
      signature = await ColdWalletService.instance.signRequest(
        request: request,
        phrase: phrase,
      );
    });

    test('rejects a different signer address', () async {
      final result = await ColdWalletService.instance.verifyResponse(
        request: request,
        signature: signature,
        expectedFrom: to,
      );
      expect(result.ok, isFalse);
      expect(result.reason, contains('Signer'));
    });

    test('rejects a request whose bytes changed after signing', () async {
      final altered = copyWith(request, value: '0x01');
      final result = await ColdWalletService.instance.verifyResponse(
        request: altered,
        signature: signature,
        expectedFrom: from,
      );
      expect(result.ok, isFalse);
    });

    test('rejects a response for a request that is not pending', () async {
      final other = newRequest(value: BigInt.one);
      final result = await ColdWalletService.instance.verifyResponse(
        request: other,
        signature: signature,
        expectedFrom: from,
      );
      expect(result.ok, isFalse);
      expect(result.reason, contains('pending'));
    });

    test('rejects a signature that claims a future timestamp', () async {
      final future = ColdTxSignature(
        version: signature.version,
        requestId: signature.requestId,
        requestHash: signature.requestHash,
        chainId: signature.chainId,
        from: signature.from,
        r: signature.r,
        s: signature.s,
        v: signature.v,
        yParity: signature.yParity,
        signedTxHash: signature.signedTxHash,
        signedAt: DateTime.now()
            .toUtc()
            .add(const Duration(minutes: 30))
            .toIso8601String(),
        rawSignedTx: signature.rawSignedTx,
      );
      final result = await ColdWalletService.instance.verifyResponse(
        request: request,
        signature: future,
        expectedFrom: from,
      );
      expect(result.ok, isFalse);
      expect(result.reason, contains('future'));
    });
  });

  group('verified broadcast', () {
    test('accepts the exact hash and clears the pending request', () async {
      final request = newRequest();
      await ColdWalletService.instance.storePendingRequest(request);
      final signature = await ColdWalletService.instance.signRequest(
        request: request,
        phrase: phrase,
      );
      final fake = _FakeRpc((_) => signature.signedTxHash);
      final hash = await ColdWalletService.instance.broadcastResponse(
        rpc: fake,
        request: request,
        signature: signature,
        expectedFrom: from,
      );
      expect(hash, signature.signedTxHash);
      expect(fake.broadcast, hasLength(1));
      expect(fake.broadcast.single, signature.rawSignedTx);
      expect(
        await ColdWalletService.instance.pendingRequestById(request.id!),
        isNull,
      );
      expect(await ColdWalletService.instance.isBroadcast(hash), isTrue);
    });

    test('a mismatched node hash is fatal and the bytes stay burned', () async {
      final request = newRequest();
      await ColdWalletService.instance.storePendingRequest(request);
      final signature = await ColdWalletService.instance.signRequest(
        request: request,
        phrase: phrase,
      );
      final fake = _FakeRpc((_) => '0x${'11' * 32}');
      await expectLater(
        ColdWalletService.instance.broadcastResponse(
          rpc: fake,
          request: request,
          signature: signature,
          expectedFrom: from,
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('different transaction hash'),
          ),
        ),
      );
      expect(fake.broadcast, hasLength(1));
      expect(
        await ColdWalletService.instance.isBroadcast(signature.signedTxHash),
        isTrue,
      );
      // The pending request remains for inspection, but a second attempt is
      // refused by the burned-hash guard before it reaches the node.
      await expectLater(
        ColdWalletService.instance.broadcastResponse(
          rpc: fake,
          request: request,
          signature: signature,
          expectedFrom: from,
        ),
        throwsA(isA<StateError>()),
      );
      expect(fake.broadcast, hasLength(1));
    });

    test('refuses to broadcast a tampered signature', () async {
      final request = newRequest();
      await ColdWalletService.instance.storePendingRequest(request);
      final signature = await ColdWalletService.instance.signRequest(
        request: request,
        phrase: phrase,
      );
      final tampered = ColdTxSignature(
        version: signature.version,
        requestId: signature.requestId,
        requestHash: signature.requestHash,
        chainId: signature.chainId,
        from: signature.from,
        r: signature.r,
        s: signature.s,
        v: signature.v,
        yParity: signature.yParity,
        signedTxHash: signature.signedTxHash,
        signedAt: signature.signedAt,
        rawSignedTx: '0x02f8723880843b9aca00843b9aca008252089470997970c51812dc3a010c7d01b50e0d17dc79c8880de0b6b3a764000180c001a09e14c0496472a3ea4af35ece19224ff815dfd656a568524a84130c722b959afda0393349471326e2196f8d11c49649f17df740476d4f5d6447f8dfa20bd0d66a4b',
      );
      final fake = _FakeRpc((_) => tampered.signedTxHash);
      await expectLater(
        ColdWalletService.instance.broadcastResponse(
          rpc: fake,
          request: request,
          signature: tampered,
          expectedFrom: from,
        ),
        throwsA(isA<StateError>()),
      );
      expect(fake.broadcast, isEmpty);
    });
  });
}
