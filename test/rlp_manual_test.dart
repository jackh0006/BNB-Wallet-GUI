import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:rlp/rlp.dart';
import 'package:web3dart/web3dart.dart';
import 'package:crypto/crypto.dart';

void main() {
  test('Manual RLP encoding', () {
    // Test manual RLP encoding for address
    final addressBytes = hexToBytes('70997970c51812dc3a010c7d01b50e0d17dc79c8');
    print('Address bytes: $addressBytes');
    print('Address bytes length: ${addressBytes.length}');
    
    // Manual RLP encoding for 20-byte string: 0x94 + 20 bytes
    final addressRlp1 = Uint8List.fromList([0x94] + addressBytes);
    print('Address RLP: ${bytesToHex(addressRlp1)}');
    
    // Test encoding a list with the address
    final chainId = 56;
    final nonce = 0;
    final maxPriorityFeePerGas = BigInt.from(0x3b9aca00);
    final maxFeePerGas = BigInt.from(0x3b9aca00);
    final gasLimit = 21000;
    final value = BigInt.from(0xde0b6b3a7640000);
    final data = <int>[];
    
    // Encode each field
    final chainIdEncoded = Rlp.encode([chainId]);
    print('ChainId encoded: ${bytesToHex(chainIdEncoded)}');
    
    final nonceEncoded = Rlp.encode([0]);
    print('Nonce encoded: ${bytesToHex(nonceEncoded)}');
    
    final maxPriorityFeePerGasEncoded = Rlp.encode([BigInt.from(0x3b9aca00)]);
    print('MaxPriorityFeePerGas encoded: ${bytesToHex(maxPriorityFeePerGasEncoded)}');
    
    final maxFeePerGasEncoded = Rlp.encode([BigInt.from(0x3b9aca00)]);
    print('MaxFeePerGas encoded: ${bytesToHex(maxFeePerGasEncoded)}');
    
    final gasLimitEncoded = Rlp.encode([21000]);
    print('GasLimit encoded: ${bytesToHex(gasLimitEncoded)}');
    
    // Address manually encoded
    final toBytes1 = hexToBytes('70997970c51812dc3a010c7d01b50e0d17dc79c8');
    final addressRlp = Uint8List.fromList([0x94] + toBytes1);
    print('Address RLP: ${bytesToHex(addressRlp)}');
    
    final valueEncoded = Rlp.encode([BigInt.from(0xde0b6b3a7640000)]);
    print('Value encoded: ${bytesToHex(valueEncoded)}');
    
    final dataEncoded = Rlp.encode([<int>[]]);
    print('Data encoded: ${bytesToHex(dataEncoded)}');
    
    final accessListEncoded = Rlp.encode([<int>[]]);
    print('AccessList encoded: ${bytesToHex(accessListEncoded)}');
    
    // Now manually construct the list
    // Items:
    // 1. chainId (56) -> encoded as int
    // 2. nonce (0) -> encoded as int
    // 3. maxPriorityFeePerGas (BigInt) -> encoded as BigInt
    // 4. maxFeePerGas (BigInt) -> encoded as BigInt
    // 4. gasLimit (int) -> encoded as int
    // 5. to (Address) -> manually encoded as 0x94 + 20 bytes
    // 6. value (BigInt) -> encoded as BigInt
    // 7. data (bytes) -> encoded as empty list
    // 8. accessList (list) -> encoded as empty list
    
    // Encode each item using Rlp.encode([item]) and strip the list prefix
    final items = <Uint8List>[];
    
    // chainId
    items.add(stripListPrefix(Rlp.encode([56])));
    // nonce
    items.add(stripListPrefix(Rlp.encode([0])));
    // maxPriorityFeePerGas
    items.add(stripListPrefix(Rlp.encode([BigInt.from(0x3b9aca00)])));
    // maxFeePerGas
    items.add(stripListPrefix(Rlp.encode([BigInt.from(0x3b9aca00)])));
    // gasLimit
    items.add(stripListPrefix(Rlp.encode([21000])));
    // to address (manually encoded)
    final toBytes = hexToBytes('70997970c51812dc3a010c7d01b50e0d17dc79c8');
    items.add(Uint8List.fromList([0x94] + toBytes));
    // value
    items.add(stripListPrefix(Rlp.encode([BigInt.from(0xde0b6b3a7640000)])));
    // data
    items.add(stripListPrefix(Rlp.encode([<int>[]])));
    // accessList
    items.add(stripListPrefix(Rlp.encode([<int>[]])));
    
    // Concatenate all items
    final concatenated = BytesBuilder();
    for (final item in items) {
      concatenated.add(item);
    }
    final concatenatedBytes = concatenated.toBytes();
    print('Concatenated items: ${bytesToHex(concatenatedBytes)}');
    print('Concatenated length: ${concatenatedBytes.length}');
    
    // Add list prefix
    final listPrefix = _encodeLength(concatenatedBytes.length, 0xc0);
    print('List prefix: ${bytesToHex(listPrefix)}');
    
    final fullRlp = Uint8List.fromList(listPrefix + concatenatedBytes);
    print('Full RLP: ${bytesToHex(fullRlp)}');
    print('Full RLP length: ${fullRlp.length}');
    
    // Add 0x02 prefix
    final withPrefix = Uint8List.fromList([0x02] + fullRlp);
    print('With prefix: ${bytesToHex(withPrefix)}');
    
    // Hash
    final hash = keccak256(withPrefix);
    print('Hash: ${bytesToHex(hash, include0x: true)}');
  });
}

Uint8List stripListPrefix(Uint8List encoded) {
  if (encoded.isEmpty) return Uint8List.fromList([]);
  
  final firstByte = encoded[0];
  if (firstByte < 0xc0) {
    return encoded;
  } else if (firstByte <= 0xf7) {
    final length = firstByte - 0xc0;
    return encoded.sublist(1, 1 + length);
  } else {
    final lengthOfLength = firstByte - 0xf7;
    var length = 0;
    for (int i = 0; i < lengthOfLength; i++) {
      length = (length << 8) | encoded[1 + i];
    }
    final valueStart = 1 + (firstByte - 0xf7);
    return encoded.sublist(1 + (firstByte - 0xf7), 1 + (firstByte - 0xf7) + length);
  }
}

Uint8List _encodeLength(int length, int offset) {
  if (length <= 55) {
    return Uint8List.fromList([offset + length]);
  } else {
    var x = Uint32List(1);
    x[0] = length;
    var y = Uint8List.view(x.buffer);
    var num = 3;
    while (y[num] == 0) {
      --num;
    }
    var e = Uint8List(num + 2);
    e[0] = 0x80 + num + 1;
    for (var i = 1; i < e.length; ++i) {
      e[i] = y[num--];
    }
    return e;
  }
}
