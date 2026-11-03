import 'dart:typed_data';
import 'package:rlp/rlp.dart';
import 'package:web3dart/web3dart.dart';
import 'package:crypto/crypto.dart';

void main() {
  print("=== INDEPENDENT EIP-1559 SIGNATURE INVESTIGATION ===\n");
  
  // Known test vector: Anvil test key
  final privateKeyHex = '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80';
  final expectedAddress = '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266';
  
  final privateKey = EthPrivateKey.fromHex(privateKeyHex);
  print('Private key: $privateKeyHex');
  print('Expected address: $expectedAddress');
  print('Actual address from web3dart: ${privateKey.address.eip55With0x}\n');
  
  // Transaction parameters (matching the cold wallet test)
  final chainId = 56; // BSC Mainnet
  final nonce = 0;
  final maxPriorityFeePerGas = BigInt.from(0x3b9aca00); // 1 gwei
  final maxFeePerGas = BigInt.from(0x3b9aca00); // 1 gwei
  final gasLimit = 21000;
  final to = '0x70997970C51812dc3A010C7d01b50e0d17dc79C8';
  final value = BigInt.from(0xde0b6b3a7640000); // 1 ETH in wei
  final data = <int>[];
  
  // Build transaction for signing using web3dart's Transaction class
  final tx = Transaction(
    from: EthereumAddress.fromHex(expectedAddress),
    to: EthereumAddress.fromHex(to),
    value: EtherAmount.inWei(value),
    nonce: nonce,
    maxGas: gasLimit,
    maxFeePerGas: EtherAmount.inWei(maxFeePerGas),
    maxPriorityFeePerGas: EtherAmount.inWei(maxPriorityFeePerGas),
    data: Uint8List.fromList(data),
  );
  
  // Build the signing payload exactly as EIP-1559 specifies
  // EIP-1559: keccak256(0x02 || rlp([chainId, nonce, maxPriorityFeePerGas, maxFeePerGas, gasLimit, to, value, data, accessList]))
  final toBytes = hexToBytes(_strip0x(to));
  
  final rlpListForSigning = [
    chainId,
    nonce,
    maxPriorityFeePerGas,
    maxFeePerGas,
    gasLimit,
    toBytes,
    value,
    data,
    <int>[], // access list
  ];
  
  print('\n=== SIGNING PAYLOAD CONSTRUCTION ===');
  print('rlpListForSigning: $rlpListForSigning');
  
  final encodedForSigning = Rlp.encode(rlpListForSigning);
  print('RLP encoded length: ${encodedForSigning.length}');
  print('RLP encoded (hex): ${bytesToHex(encodedForSigning)}');
  
  final withPrefix = Uint8List.fromList([0x02] + encodedForSigning);
  print('With prefix length: ${withPrefix.length}');
  print('With prefix (hex): ${bytesToHex(withPrefix)}');
  
  final signingHash = keccak256(withPrefix);
  print('Signing hash (keccak256): ${bytesToHex(signingHash, include0x: true)}');
  
  // Sign using web3dart
  print('\n=== SIGNING WITH web3dart ===');
  final signature = privateKey.signToEcSignature(signingHash, chainId: chainId, isEIP1559: true);
  print('Signature:');
  print('  r = ${signature.r}');
  print('  s = ${signature.s}');
  print('  v = ${signature.v} (this is the recovery ID 0-3)');
  
  // Verify the signature using web3dart's isValidSignature
  print('\n=== VERIFICATION USING web3dart isValidSignature ===');
  final publicKey = privateKey.encodedPublicKey;
  print('Public key: ${bytesToHex(publicKey)}');
  
  final msgSigForVerify = MsgSignature(signature.r, signature.s, signature.v + 27);
  print('MsgSignature for verify: v = ${msgSigForVerify.v}');
  
  final isValid = isValidSignature(signingHash, msgSigForVerify, publicKey);
  print('isValidSignature result: $isValid');
  
  // Now try ecRecover directly
  print('\n=== DIRECT ecRecover TEST ===');
  for (final recoveryId in [0, 1, 2, 3]) {
    final msgSig = MsgSignature(signature.r, signature.s, 27 + recoveryId);
    try {
      final recoveredPubKey = ecRecover(signingHash, msgSig);
      final recoveredAddr = EthereumAddress(publicKeyToAddress(recoveredPubKey));
      print('recoveryId=$recoveryId: ${recoveredAddr.eip55With0x} ${recoveredAddr.eip55With0x == expectedAddress ? "✓ MATCH" : "✗ MISMATCH"}');
    } catch (e) {
      print('recoveryId=$recoveryId: ERROR - $e');
    }
  }
  
  // Now build the full signed transaction RLP
  print('\n=== FULL SIGNED TRANSACTION RLP ===');
  final yParity = signature.v & 1;
  print('yParity = $yParity (signature.v = ${signature.v})');
  
  final signedRlpList = [
    chainId,
    nonce,
    maxPriorityFeePerGas,
    maxFeePerGas,
    gasLimit,
    toBytes,
    value,
    data,
    <int>[], // access list
    yParity,
    signature.r,
    signature.s,
  ];
  
  print('signedRlpList: $signedRlpList');
  
  final signedRlpEncoded = Rlp.encode(signedRlpList);
  print('Signed RLP encoded length: ${signedRlpEncoded.length}');
  print('Signed RLP encoded (hex): ${bytesToHex(signedRlpEncoded)}');
  
  final fullRawTx = Uint8List.fromList([0x02] + signedRlpEncoded);
  print('Full raw transaction (hex): ${bytesToHex(fullRawTx, include0x: true)}');
  
  final txHash = keccak256(fullRawTx);
  print('Transaction hash: ${bytesToHex(txHash, include0x: true)}');
  
  // Now test verification by parsing the signed transaction
  print('\n=== VERIFICATION BY PARSING SIGNED TRANSACTION ===');
  // We can use web3dart to parse the signed transaction
  try {
    // Try to create a Transaction from the signed bytes
    // web3dart doesn't have a direct parser for signed EIP-1559 transactions
    // But we can verify by checking if the signature components match
    print('Manual verification:');
    print('  r matches: ${signature.r}');
    print('  s matches: ${signature.s}');
    print('  v (recovery ID) = ${signature.v}');
  } catch (e) {
    print('Error: $e');
  }
  
  // Test the exact signing payload our implementation creates
  print('\n=== OUR IMPLEMENTATION\'S _encodeTransactionForSigning ===');
  // Replicate our implementation's _encodeTransactionForSigning
  final ourRlpList = [
    chainId,
    nonce,
    maxPriorityFeePerGas,
    maxFeePerGas,
    gasLimit,
    toBytes,
    value,
    data,
    <int>[], // access list
  ];
  final ourEncoded = Rlp.encode(ourRlpList);
  final ourWithPrefix = Uint8List.fromList([0x02] + ourEncoded);
  final ourHash = keccak256(ourWithPrefix);
  print('Our signing hash: ${bytesToHex(ourHash, include0x: true)}');
  print('Match: ${bytesToHex(ourHash) == bytesToHex(signingHash)}');
  
  // Sign with our hash
  final ourSignature = privateKey.signToEcSignature(ourHash, chainId: chainId, isEIP1559: true);
  print('Our signature:');
  print('  r = ${ourSignature.r}');
  print('  s = ${ourSignature.s}');
  print('  v = ${ourSignature.v}');
  
  // Verify our signature
  final ourMsgSig = MsgSignature(ourSignature.r, ourSignature.s, ourSignature.v + 27);
  final ourValid = isValidSignature(ourHash, ourMsgSig, publicKey);
  print('Our signature isValid: $ourValid');
  
  // Try ecRecover with our signature
  print('\n=== ecRecover WITH OUR SIGNATURE ===');
  for (final recoveryId in [0, 1, 2, 3]) {
    final msgSig = MsgSignature(ourSignature.r, ourSignature.s, 27 + recoveryId);
    try {
      final recoveredPubKey = ecRecover(ourHash, msgSig);
      final recoveredAddr = EthereumAddress(publicKeyToAddress(recoveredPubKey));
      print('recoveryId=$recoveryId: ${recoveredAddr.eip55With0x} ${recoveredAddr.eip55With0x == expectedAddress ? "✓ MATCH" : "✗ MISMATCH"}');
    } catch (e) {
      print('recoveryId=$recoveryId: ERROR - $e');
    }
  }
}

String _strip0x(String value) =>
    value.startsWith('0x') || value.startsWith('0X') ? value.substring(2) : value;
