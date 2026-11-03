import 'dart:typed_data';
import 'package:web3dart/web3dart.dart';
import 'package:rlp/rlp.dart';

void main() {
  // Replicate the _encodeTransactionForSigning logic
  final chainId = 56;
  final nonce = 0;
  final maxPriorityFeePerGas = BigInt.from(0x3b9aca00); // 1 gwei
  final maxFeePerGas = BigInt.from(0x3b9aca00); // 1 gwei
  final gasLimit = 21000;
  final to = '0x70997970C51812dc3A010C7d01b50e0d17dc79C8';
  final value = BigInt.from(0xde0b6b3a7640000); // 1 ETH
  final data = <int>[];
  
  final rlpList = [
    chainId,
    nonce,
    maxPriorityFeePerGas,
    maxFeePerGas,
    gasLimit,
    to,
    value,
    data,
    <int>[], // access list
  ];

  final encoded = Rlp.encode(rlpList);
  final withPrefix = Uint8List.fromList([0x02] + encoded);
  final hash = keccak256(withPrefix);
  
  print('Hash: ${bytesToHex(hash, include0x: true)}');
  
  // Now sign this hash
  final privateKey = EthPrivateKey.fromHex('0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80');
  final sig = privateKey.signToEcSignature(hash, chainId: chainId, isEIP1559: true);
  print('Signature: r=${sig.r}, s=${sig.s}, v=${sig.v}');
  
  // Verify
  final msgSig = MsgSignature(sig.r, sig.s, sig.v + 27);
  final recovered = ecRecover(hash, msgSig);
  final recoveredAddr = EthereumAddress(publicKeyToAddress(recovered));
  print('Recovered address: ${recoveredAddr.eip55With0x}');
  print('Expected: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266');
}
