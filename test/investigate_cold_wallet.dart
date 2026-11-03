import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:rlp/rlp.dart';
import 'package:wallet/wallet.dart';
import 'package:web3dart/web3dart.dart';
import 'package:crypto/crypto.dart';

void main() {
  test('Investigate EIP-1559 signature verification', () {
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
    
    // IMPORTANT: signToEcSignature hashes the payload internally with keccak256!
    // So we pass the RAW payload (withPrefix), NOT the pre-hashed value.
    final payload = withPrefix;
    print('Payload for signToEcSignature (hex): ${bytesToHex(payload)}');
    
    // Sign using web3dart
    print('\n=== SIGNING WITH web3dart ===');
    final signature = privateKey.signToEcSignature(payload, chainId: chainId, isEIP1559: true);
    print('Signature:');
    print('  r = ${signature.r}');
    print('  s = ${signature.s}');
    print('  v = ${signature.v} (this is the recovery ID 0-3)');
    
    // Verify the signature using web3dart's isValidSignature
    // For isValidSignature, we need the MESSAGE HASH (keccak256 of payload)
    final messageHash = keccak256(payload);
    print('\n=== VERIFICATION USING web3dart isValidSignature ===');
    final publicKey = privateKey.encodedPublicKey;
    print('Public key: ${bytesToHex(publicKey)}');
    print('Message hash: ${bytesToHex(messageHash, include0x: true)}');
    
    final msgSigForVerify = MsgSignature(signature.r, signature.s, signature.v + 27);
    print('MsgSignature for verify: v = ${msgSigForVerify.v}');
    
    final isValid = isValidSignature(messageHash, msgSigForVerify, publicKey);
    print('isValidSignature result: $isValid');
    expect(isValid, isTrue, reason: 'web3dart isValidSignature should pass');
    
    // Now try ecRecover directly
    print('\n=== DIRECT ecRecover TEST ===');
    for (final recoveryId in [0, 1, 2, 3]) {
      final msgSig = MsgSignature(signature.r, signature.s, 27 + recoveryId);
      try {
        final recoveredPubKey = ecRecover(messageHash, msgSig);
        final recoveredAddr = EthereumAddress(publicKeyToAddress(recoveredPubKey));
        print('recoveryId=$recoveryId: ${recoveredAddr.eip55With0x} ${recoveredAddr.eip55With0x == expectedAddress ? "MATCH" : "MISMATCH"}');
      } catch (e) {
        print('recoveryId=$recoveryId: ERROR - $e');
      }
    }
    
    // Test the exact signing payload our implementation creates
    print('\n=== OUR IMPLEMENTATION\'S _encodeTransactionForSigning ===');
    final ourRlpList = [
      chainId,
      nonce,
      maxPriorityFeePerGas,
      maxFeePerGas,
      gasLimit,
      hexToBytes(_strip0x(to)),
      value,
      data,
      <int>[], // access list
    ];
    final ourEncoded = Rlp.encode(ourRlpList);
    final ourWithPrefix = Uint8List.fromList([0x02] + ourEncoded);
    print('Our payload (hex): ${bytesToHex(ourWithPrefix)}');
    print('Match: ${bytesToHex(ourWithPrefix) == bytesToHex(payload)}');
    
    // Sign with our hash
    final ourSignature = privateKey.signToEcSignature(ourWithPrefix, chainId: chainId, isEIP1559: true);
    print('Our signature:');
    print('  r = ${ourSignature.r}');
    print('  s = ${ourSignature.s}');
    print('  v = ${ourSignature.v}');
    
    // Verify our signature
    final ourMessageHash = keccak256(ourWithPrefix);
    final ourMsgSig = MsgSignature(ourSignature.r, ourSignature.s, ourSignature.v + 27);
    final ourValid = isValidSignature(ourMessageHash, ourMsgSig, publicKey);
    print('Our signature isValid: $ourValid');
    expect(ourValid, isTrue, reason: 'Our implementation signature should be valid');
    
    // Try ecRecover with our signature
    print('\n=== ecRecover WITH OUR SIGNATURE ===');
    for (final recoveryId in [0, 1, 2, 3]) {
      final msgSig = MsgSignature(ourSignature.r, ourSignature.s, 27 + recoveryId);
      try {
        final recoveredPubKey = ecRecover(ourMessageHash, msgSig);
        final recoveredAddr = EthereumAddress(publicKeyToAddress(recoveredPubKey));
        print('recoveryId=$recoveryId: ${recoveredAddr.eip55With0x} ${recoveredAddr.eip55With0x == expectedAddress ? "MATCH" : "MISMATCH"}');
      } catch (e) {
        print('recoveryId=$recoveryId: ERROR - $e');
      }
    }
    
    // Now test the exact same flow as our cold wallet implementation
    print('\n=== COLD WALLET IMPLEMENTATION FLOW ===');
    
    // Simulate what signTransaction does
    final coldWalletTx = Transaction(
      from: EthereumAddress.fromHex(expectedAddress),
      to: EthereumAddress.fromHex(to),
      value: EtherAmount.inWei(value),
      nonce: nonce,
      maxGas: gasLimit,
      maxFeePerGas: EtherAmount.inWei(maxFeePerGas),
      maxPriorityFeePerGas: EtherAmount.inWei(maxPriorityFeePerGas),
      data: Uint8List.fromList(data),
    );
    
    // Our _encodeTransactionForSigning returns the MESSAGE HASH (keccak256 of payload)
    final txPayload = _encodeTransactionForSigning(coldWalletTx, chainId);
    print('txPayload (message hash): ${bytesToHex(txPayload, include0x: true)}');
    
    // But signToEcSignature expects the RAW PAYLOAD, not the hash!
    // So we need to reconstruct the payload from the hash... but we can't reverse keccak256.
    // The issue is that _encodeTransactionForSigning returns the hash, but signToEcSignature needs the payload.
    
    // Let's use the payload directly
    final coldWalletPayload = _buildTransactionPayload(coldWalletTx, chainId);
    print('Cold wallet payload: ${bytesToHex(coldWalletPayload)}');
    
    final coldSignature = privateKey.signToEcSignature(coldWalletPayload, chainId: chainId, isEIP1559: true);
    
    print('Cold wallet signature:');
    print('  r = ${coldSignature.r}');
    print('  s = ${coldSignature.s}');
    print('  v = ${coldSignature.v}');
    
    // Now verify using _recoverSigner logic
    final r = coldSignature.r;
    final s = coldSignature.s;
    final recoveryId = coldSignature.v; // Our implementation stores full recovery ID
    
    print('Cold wallet signature recoveryId: $recoveryId');
    
    final coldMessageHash = keccak256(coldWalletPayload);
    final msgSig = MsgSignature(r, s, 27 + recoveryId);
    try {
      final recoveredPubKey = ecRecover(coldMessageHash, msgSig);
      final recoveredAddr = EthereumAddress(publicKeyToAddress(recoveredPubKey));
      print('Recovered address: ${recoveredAddr.eip55With0x} ${recoveredAddr.eip55With0x == expectedAddress ? "MATCH" : "MISMATCH"}');
    } catch (e) {
      print('ecRecover ERROR: $e');
    }
    
    // Also test with our verifyColdSignature logic
    final yParity = coldSignature.v & 1;
    print('yParity = $yParity');
    print('coldSignature.v = ${coldSignature.v}');
    print('yParity + 2 = ${yParity + 2}');
    
    // Try both recovery IDs matching yParity
    for (final testRecoveryId in [yParity, yParity + 2]) {
      if (testRecoveryId >= 0 && testRecoveryId <= 3) {
        final testMsgSig = MsgSignature(r, s, 27 + testRecoveryId);
        try {
          final recoveredPubKey = ecRecover(keccak256(coldWalletPayload), testMsgSig);
          final recoveredAddr = EthereumAddress(publicKeyToAddress(recoveredPubKey));
          print('Test recoveryId=$testRecoveryId: ${recoveredAddr.eip55With0x} ${recoveredAddr.eip55With0x == expectedAddress ? "MATCH" : "MISMATCH"}');
        } catch (e) {
          print('Test recoveryId=$testRecoveryId ERROR: $e');
        }
      }
    }
    
    // Also check what the full recovery ID actually is
    print('\n=== DEEP INSPECTION ===');
    print('coldSignature.v (full recovery ID): ${coldSignature.v}');
    print('Expected recovery ID from isValidSignature: ${coldSignature.v}');
    print('yParity (coldSignature.v & 1): ${coldSignature.v & 1}');
    
    // Test with the FULL recovery ID (not just yParity)
    final fullRecoveryMsgSig = MsgSignature(r, s, 27 + coldSignature.v);
    try {
      final recoveredPubKey = ecRecover(keccak256(coldWalletPayload), fullRecoveryMsgSig);
      final recoveredAddr = EthereumAddress(publicKeyToAddress(recoveredPubKey));
      print('Full recoveryId=${coldSignature.v}: ${recoveredAddr.eip55With0x} ${recoveredAddr.eip55With0x == expectedAddress ? "MATCH" : "MISMATCH"}');
    } catch (e) {
      print('Full recoveryId ERROR: $e');
    }
  });
}

Uint8List _buildTransactionPayload(Transaction tx, int chainId) {
  final toBytes = tx.to != null ? hexToBytes(_strip0x(tx.to!.eip55With0x)) : <int>[];
  
  final rlpList = [
    chainId,
    tx.nonce ?? 0,
    tx.maxPriorityFeePerGas?.getInWei ?? BigInt.zero,
    tx.maxFeePerGas?.getInWei ?? BigInt.zero,
    tx.maxGas ?? 0,
    toBytes,
    tx.value?.getInWei ?? BigInt.zero,
    tx.data ?? <int>[],
    <int>[], // access list
  ];

  final encoded = Rlp.encode(rlpList);
  return Uint8List.fromList([0x02] + encoded);
}

Uint8List _encodeTransactionForSigning(Transaction tx, int chainId) {
  final payload = _buildTransactionPayload(tx, chainId);
  return keccak256(payload);
}

String _strip0x(String value) =>
    value.startsWith('0x') || value.startsWith('0X') ? value.substring(2) : value;
