import 'dart:typed_data';
import 'package:web3dart/web3dart.dart';

void main() {
  // Use the known private key
  final privateKey = EthPrivateKey.fromHex('0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80');
  print('Address: ${privateKey.address.eip55With0x}');
  
  // Create a simple payload (32 bytes)
  final payload = Uint8List.fromList([
    0x72, 0x38, 0x67, 0xa4, 0xfb, 0x75, 0x38, 0x72,
    0x1e, 0xae, 0x53, 0xe2, 0x06, 0x08, 0x1d, 0xe8,
    0xa9, 0x7d, 0x3a, 0x0a, 0x38, 0x5c, 0x56, 0xc3,
    0x3b, 0x4f, 0x00, 0x0a, 0x35, 0x9e, 0x72, 0x94
  ]);
  
  print('Payload: ${bytesToHex(payload)}');
  
  // Sign with EIP-1559
  final sig = privateKey.signToEcSignature(payload, chainId: 56, isEIP1559: true);
  print('Signature:');
  print('  r: ${sig.r}');
  print('  s: ${sig.s}');
  print('  v: ${sig.v}');
  
  // Verify using ecRecover with both recovery IDs
  for (final recoveryId in [0, 1]) {
    final msgSig = MsgSignature(sig.r, sig.s, 27 + recoveryId);
    try {
      final recovered = ecRecover(payload, msgSig);
      final recoveredAddr = EthereumAddress(publicKeyToAddress(recovered));
      print('recoveryId=$recoveryId: ${recoveredAddr.eip55With0x}');
    } catch (e) {
      print('recoveryId=$recoveryId failed: $e');
    }
  }
  
  // Also test isValidSignature
  final publicKey = privateKey.encodedPublicKey;
  print('Public key: ${bytesToHex(publicKey)}');
  
  final msgSig = MsgSignature(sig.r, sig.s, sig.v + 27);
  final isValid = isValidSignature(payload, msgSig, publicKey);
  print('isValidSignature: $isValid');
}
