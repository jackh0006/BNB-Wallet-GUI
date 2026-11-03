import 'package:flutter_test/flutter_test.dart';
import 'package:rlp/rlp.dart';

void main() {
  test('Address constructor', () {
    // Test the Address constructor
    final address = Address('0x70997970C51812dc3A010C7d01b50e0d17dc79C8');
    print('Address: $address');
    print('Address bytes: ${address.toBytes()}');
  });
}
