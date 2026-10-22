import 'package:flutter_test/flutter_test.dart';
import 'package:bnb_wallet_gui/rpc_story.dart';
import 'package:bnb_wallet_gui/tx_lifecycle.dart';

void main() {
  group('send journey strip', () {
    test('every stage before failed sits on the strip in order', () {
      expect(journeyIndexOf(TxStage.prepared), 0);
      expect(journeyIndexOf(TxStage.signed), greaterThan(journeyIndexOf(TxStage.simulated)));
      expect(journeyIndexOf(TxStage.finalized), sendJourney.length - 1);
      expect(journeyIndexOf(TxStage.failed), -1);
    });

    test('every stage carries plain words for screen readers and sighted users', () {
      for (final stage in TxStage.values) {
        expect(stage.label.trim(), isNotEmpty, reason: '$stage needs a label');
        expect(stage.detail.trim(), isNotEmpty, reason: '$stage needs a detail');
      }
    });
  });

  group('send events map to story lines exhaustively', () {
    test('no event can exist without words', () {
      for (final event in SendEvent.values) {
        final note = sendEventNote(event);
        expect(note.text.trim(), isNotEmpty, reason: '$event needs a story line');
      }
    });

    test('failure-ish events are marked as such for the story colours', () {
      expect(sendEventNote(SendEvent.reverted).kind, RpcStoryKind.fail);
      expect(sendEventNote(SendEvent.unknownOutcome).kind, RpcStoryKind.fail);
      expect(sendEventNote(SendEvent.refused).kind, RpcStoryKind.fail);
      expect(sendEventNote(SendEvent.finalized).kind, RpcStoryKind.ok);
    });
  });

  group('replacement fee bump (≥ +12.5%, rounded up)', () {
    test('exact math', () {
      expect(bumpFee(BigInt.from(1000)), BigInt.from(1125));
      expect(bumpFee(BigInt.from(800)), BigInt.from(900));
      // 100 * 1125 / 1000 = 112.5 -> rounds up to 113
      expect(bumpFee(BigInt.from(100)), BigInt.from(113));
    });
  });

  group('decodeRevertReason — the contract\'s own words when it has any', () {
    test('string revert after a colon', () {
      expect(
        decodeRevertReason('RPCError: execution reverted: ERC20: transfer amount exceeds balance'),
        'ERC20: transfer amount exceeds balance',
      );
    });

    test('ABI-encoded string revert (0x08c379a0…)', () {
      final reason = 'BEP20: transfer amount exceeds balance';
      final bytes = reason.codeUnits;
      final hexLen = (bytes.length).toRadixString(16).padLeft(64, '0');
      final padded = StringBuffer();
      for (final b in bytes) {
        padded.write(b.toRadixString(16).padLeft(2, '0'));
      }
      final offset = 32.toRadixString(16).padLeft(64, '0');
      final text = '0x08c379a0$offset$hexLen$padded';
      expect(decodeRevertReason('execution reverted (data: $text)'), reason);
    });

    test('bare revert without a reason says exactly that', () {
      expect(
        decodeRevertReason('execution reverted'),
        contains('no reason given'),
      );
    });

    test('undecodable hex is never invented into words', () {
      final decoded = decodeRevertReason('execution reverted 0xdeadbeefcafebabe');
      expect(decoded, contains('undecoded'));
      expect(decoded, contains('0xdead'));
    });

    test('insufficient funds becomes plain words', () {
      expect(
        decodeRevertReason('insufficient funds for gas * price + value'),
        contains('cannot cover'),
      );
    });

    test('a plain message passes through untouched', () {
      expect(decodeRevertReason('some node complaint'), 'some node complaint');
    });
  });

  group('readBroadcastError — every refusal shape has honest guidance', () {
    test('already known means accepted, never resend', () {
      final r = readBroadcastError('RPCError: already known');
      expect(r.verdict, BroadcastVerdict.acceptedKnown);
      expect(r.plainWords, contains('Do not resend'));
    });

    test('nonce too low explains replacement/dropped', () {
      final r = readBroadcastError('nonce too low: next nonce 42, tx nonce 41');
      expect(r.verdict, BroadcastVerdict.nonceTooLow);
      expect(r.plainWords, contains('check the explorer'));
    });

    test('underpriced vs replacement-underpriced are distinct', () {
      expect(readBroadcastError('transaction underpriced').verdict,
          BroadcastVerdict.underpriced);
      expect(
        readBroadcastError('replacement transaction underpriced').verdict,
        BroadcastVerdict.replacementUnderpriced,
      );
    });

    test('insufficient funds and intrinsic gas', () {
      expect(readBroadcastError('insufficient funds for transfer').verdict,
          BroadcastVerdict.insufficientFunds);
      expect(readBroadcastError('intrinsic gas too low').verdict,
          BroadcastVerdict.intrinsicGas);
    });

    test('transport failures are unknown outcomes — never "failed"', () {
      expect(readBroadcastError('SocketException: connection closed').verdict,
          BroadcastVerdict.unknownOutcome);
      expect(readBroadcastError('ClientException: timeout').verdict,
          BroadcastVerdict.unknownOutcome);
    });

    test('anything else keeps the node\'s text', () {
      final r = readBroadcastError('weird node error');
      expect(r.verdict, BroadcastVerdict.failed);
      expect(r.plainWords, 'weird node error');
    });
  });

  group('ERC-20 Transfer log decoding (fee-on-transfer check)', () {
    const token = '0x55d398326f99059fF775485246999027B3197955';
    const from = '0x7EA499b984050c75192387b5A0e81d6d39db50CD';
    const to = '0xE068c17463Cc816DC5A410F06a2cbD4e03863046';

    String topic(String address) =>
        '0x000000000000000000000000${address.toLowerCase().replaceFirst('0x', '')}';

    EvmLog transfer(String valueHex64) => EvmLog(
          address: token,
          topics: [erc20TransferTopic, topic(from), topic(to)],
          data: '0x$valueHex64',
        );

    test('finds the amount actually sent to the recipient', () {
      final amount = BigInt.from(123456789);
      final hex = amount.toRadixString(16).padLeft(64, '0');
      expect(
        findTransferAmount(logs: [transfer(hex)], token: token, from: from, to: to),
        amount,
      );
    });

    test('ignores logs from other contracts or other parties', () {
      final hex = BigInt.one.toRadixString(16).padLeft(64, '0');
      final foreign = EvmLog(
        address: '0x1111111111111111111111111111111111111111',
        topics: [erc20TransferTopic, topic(from), topic(to)],
        data: '0x$hex',
      );
      expect(findTransferAmount(logs: [foreign], token: token, from: from, to: to),
          isNull);
      final wrongParty = EvmLog(
        address: token,
        topics: [erc20TransferTopic, topic(to), topic(from)],
        data: '0x$hex',
      );
      expect(
          findTransferAmount(
              logs: [wrongParty], token: token, from: from, to: to),
          isNull);
      expect(findTransferAmount(logs: const [], token: token, from: from, to: to),
          isNull);
    });

    test('a smaller received amount is detectable (fee-on-transfer)', () {
      final sent = BigInt.from(1000000);
      final received = BigInt.from(990000);
      final hex = received.toRadixString(16).padLeft(64, '0');
      final found =
          findTransferAmount(logs: [transfer(hex)], token: token, from: from, to: to);
      expect(found, received);
      expect(found! < sent, isTrue);
    });
  });
}
