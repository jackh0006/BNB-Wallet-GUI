import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'models.dart';
import 'wallet_core.dart';

/// Renders a complete receipt to a PNG without a browser, PDF library or any
/// network call. Used by "Save PNG" on the receipt page (spec §10c).
///
/// The image is drawn on a tall canvas, so it contains every line even when
/// the on-screen list is scrolled; long values wrap instead of being cut.
Future<Uint8List> renderReceiptPng(LocalReceipt receipt) async {
  const width = 1000.0;
  const padding = 48.0;
  final blocks = <_Block>[];

  void add(
    String text, {
    double size = 17,
    FontWeight weight = FontWeight.normal,
    Color color = const Color(0xFFE8EAED),
    double before = 0,
    double after = 8,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: size,
          color: color,
          fontWeight: weight,
          height: 1.35,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: width - padding * 2);
    blocks.add(_Block(painter, before, after));
  }

  add('X Wallet receipt', size: 32, weight: FontWeight.bold, after: 4);
  add(
    '${receipt.amountHuman} ${receipt.assetSymbol}'
    ' · ${receipt.status}${receipt.finalized ? ' · final' : ''}',
    size: 22,
    weight: FontWeight.w600,
    color: receipt.status == 'success'
        ? const Color(0xFF69C77A)
        : const Color(0xFFFF6B6B),
    after: 20,
  );

  add('Chain facts', weight: FontWeight.bold, size: 19, after: 4);
  add('Network: BSC ${receipt.network} · chain ${receipt.chainId}');
  add('Block: ${receipt.blockNumber}');
  if (receipt.blockHash != null) add('Block hash: ${receipt.blockHash}');
  if (receipt.transactionIndex != null) {
    add('Position in block: ${receipt.transactionIndex}');
  }
  add('Confirmations: ${receipt.confirmations}');
  add('Finality: ${receipt.finalized ? 'final' : 'waiting for finality'}');
  add('Nonce: ${receipt.nonce}');
  add('From: ${receipt.from}');
  add('To: ${receipt.to}');
  add('Transaction: ${receipt.hash}', after: 18);

  add('What you paid', weight: FontWeight.bold, size: 19, after: 4);
  add(
    'Charged fee: '
    '${WalletCore.formatEther(BigInt.parse(receipt.feeWei))} BNB',
  );
  add('Gas used / limit: ${receipt.gasUsed} / ${receipt.gasLimit}');
  if (receipt.effectiveGasPriceWei != null) {
    add(
      'Effective gas price: '
      '${WalletCore.formatUnits(BigInt.parse(receipt.effectiveGasPriceWei!), 9)} '
      'gwei',
    );
  }
  add('Tier chosen: ${receipt.tierLabel.isEmpty ? '—' : receipt.tierLabel}');
  if (receipt.reason.isNotEmpty) add('Why that fee: ${receipt.reason}');
  add('', after: 8);

  add('What the node knows', weight: FontWeight.bold, size: 19, after: 4);
  add(
    'Broadcast through: '
    '${Uri.tryParse(receipt.nodeUsed)?.host ?? receipt.nodeUsed}',
  );
  add('Transport: ${receipt.transport}');
  add('The node never saw keys, seed words or other accounts on the device.');
  add('', after: 8);
  add(
    'Saved ${receipt.savedAt}. Verify every address yourself — a receipt is '
    'a local record, not a promise from a third party.',
    color: const Color(0xFF9AA0A6),
    size: 13,
  );

  var height = padding * 2;
  for (final block in blocks) {
    height += block.before + block.painter.height + block.after;
  }
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, width, height),
    Paint()..color = const Color(0xFF0B0E11),
  );
  var y = padding;
  for (final block in blocks) {
    y += block.before;
    block.painter.paint(canvas, Offset(padding, y));
    y += block.painter.height + block.after;
  }
  final picture = recorder.endRecording();
  final image = await picture.toImage(width.round(), height.ceil());
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  if (data == null) {
    throw StateError('The receipt image could not be encoded.');
  }
  return data.buffer.asUint8List();
}

class _Block {
  const _Block(this.painter, this.before, this.after);
  final TextPainter painter;
  final double before;
  final double after;
}
