import 'dart:typed_data';
import 'package:web3dart/web3dart.dart';

void main() {
  // Test the signToEcSignature output for EIP-1559
  final privateKey = EthPrivateKey.fromHex('0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80');
  print('Address: ${privateKey.address.eip55With0x}');
  
  // Create a simple payload
  final payload = Uint8List.fromList([1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32]);
  
  // Sign with EIP-1559
  final sig1559 = privateKey.signToEcSignature(payload, chainId: 56, isEIP1559: true);
  print('EIP-1559 signature:');
  print('  r: ${sig1559.r}');
  print('  s: ${sig1559.s}');
  print('  v: ${sig1559.v}');
  
  // Sign with legacy
  final sigLegacy = privateKey.signToEcSignature(payload, chainId: 56, isEIP1559: false);
  print('Legacy signature:');
  print('  r: ${sigLegacy.r}');
  print('  s: ${sigLegacy.s}');
  print('  v: ${sigLegacy.v}');
  
  // Test ecRecover with v = sig.v + 27
  final msgSig = MsgSignature(sig1559.r, sig1559.s, sig1559.v + 27);
  print('MsgSignature for ecRecover: v=${msgSig.v}');
  
  try {
    final recovered = ecRecover(payload, msgSig);
    print('Recovered pubkey: ${bytesToHex(recovered)}');
    // final recoveredAddr = EthereumAddress(publicKeyToAddress(recovered));
    // print('Recovered address: ${recoveredAddr.eip55With0x}');
  } catch (e) {
    print('ecRecover error: $e');
  }
  
  // Test with v = sig.v (without +27)
  final msgSig2 = MsgSignature(sig1559.r, sig1559.s, sig1559.v);
  print('MsgSignature for ecRecover (v=sig.v): v=${msgSig2.v}');
  try {
    final recovered = ecRecover(payload, msgSig2);
    print('Recovered pubkey: ${bytesToHex(recovered)}');
  } catch (e) {
    print('ecRecover error (v=sig.v): $e');
  }
}
