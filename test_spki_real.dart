import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:asn1lib/asn1lib.dart';
import 'package:crypto/crypto.dart';

String extractSpkiSha256Base64(Uint8List certDer) {
  final parser = ASN1Parser(certDer);
  final cert = parser.nextObject() as ASN1Sequence;
  final tbsCert = cert.elements[0] as ASN1Sequence;
  final spki = tbsCert.elements[6] as ASN1Object;
  final spkiDer = spki.encodedBytes;
  final digest = sha256.convert(spkiDer);
  return base64Encode(digest.bytes);
}

void main() async {
  final client = HttpClient();
  // Set a callback that always returns true to see if it's called
  client.badCertificateCallback = (cert, host, port) {
    print('badCertificateCallback called!');
    print('  host: $host, port: $port');
    try {
      final spkiHash = extractSpkiSha256Base64(cert.der);
      print('SPKI SHA-256 (base64): $spkiHash');
    } catch (e) {
      print('Error extracting SPKI: $e');
    }
    return true; // Accept all certificates
  };
  
  try {
    final request = await client.getUrl(Uri.parse('https://bsc-dataseed.bnbchain.org'));
    request.followRedirects = false;
    final response = await request.close();
    print('Response: ${response.statusCode}');
  } catch (e) {
    print('Error: $e');
  }
  client.close();
}
