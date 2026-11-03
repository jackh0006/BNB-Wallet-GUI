import 'package:flutter_test/flutter_test.dart';
import 'package:rlp/rlp.dart';

void main() {
  test('Address RLP encoding', () {
    // Test the Address class from rlp package
    final address = Address('0x70997970C51812dc3A010C7d01b50e0d17dc79C8');
    print('Address: $address');
    print('Address bytes: ${address.toBytes()}');
    
    final encoded = Rlp.encode([address]);
    print('Encoded: ${bytesToHex(encoded)}');
    
    // Expected: 0x94 + 20 bytes
    // The encoded should start with f5 (list of 5 items? no, list of 1 item with 20-byte string)
    // Actually, list with 1 item that is a 20-byte string
    // List prefix: c0 + 1 = c1? No, for list with 1 item of length 21 (1 prefix + 20 bytes)
    // Length = 1 (prefix) + 20 = 21 = 0x15
    // List prefix: c0 + 0x15 = 0xd5
    // Then the address: 94 + 20 bytes
    print('Expected prefix: d594...');
  });
}
