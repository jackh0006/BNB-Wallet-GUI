import 'package:rlp/rlp.dart';
import 'package:web3dart/web3dart.dart';

void main() {
  // Test RLP encoding
  var encoded = Rlp.encode(["dog", "cat"]);
  print(encoded);
  
  // Test with BigInt
  var encoded2 = Rlp.encode([BigInt.from(1), BigInt.from(2)]);
  print(encoded2);
}
