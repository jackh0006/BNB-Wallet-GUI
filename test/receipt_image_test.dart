import 'package:flutter_test/flutter_test.dart';
import 'package:bnb_wallet_gui/models.dart';
import 'package:bnb_wallet_gui/receipt_image.dart';

LocalReceipt _receipt() => LocalReceipt(
  hash: '0xabc123abc123abc123abc123abc123abc123abc123abc123abc123abc123abcd',
  network: 'testnet',
  chainId: 97,
  status: 'success',
  from: '0xE068c17463Cc816DC5A410F06a2cbD4e03863046',
  to: '0x7EA499b984050c75192387b5A0e81d6d39db50CD',
  assetSymbol: 'BNB',
  assetAddress: '',
  amountHuman: '0.02',
  amountRaw: '20000000000000000',
  decimals: 18,
  nonce: 7,
  gasLimit: '25200',
  gasUsed: '21000',
  feeWei: '21000000000000',
  blockNumber: 123456,
  confirmations: 12,
  verifiedNodes: 2,
  finalized: true,
  tierLabel: 'Medium (recommended)',
  reason: 'Normal conditions',
  nodeUsed: 'https://data-seed-prebsc-1-s1.bnbchain.org:8545',
  transport: 'direct HTTPS',
  savedAt: '2026-10-21T00:00:00.000Z',
  rawTxHex: '0xdeadbeef',
  blockHash:
      '0x1111111111111111111111111111111111111111111111111111111111111111',
  transactionIndex: 3,
  txType: 'eip1559',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders a complete receipt PNG (spec §10c)', (tester) async {
    final bytes = await tester.runAsync(() => renderReceiptPng(_receipt()));
    expect(bytes, isNotNull);
    // PNG signature: 89 50 4E 47 0D 0A 1A 0A
    expect(bytes!.take(8).toList(), <int>[
      0x89,
      0x50,
      0x4E,
      0x47,
      0x0D,
      0x0A,
      0x1A,
      0x0A,
    ]);
    expect(bytes.length, greaterThan(1000));
  }, timeout: const Timeout(Duration(minutes: 2)));
}
