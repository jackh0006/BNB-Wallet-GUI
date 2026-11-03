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
  // Create a SecurityContext with no trusted roots
  final context = SecurityContext();
  // Don't call context.setTrustedCertificates() - this means no system CAs are trusted
  
  final client = HttpClient(context: context);
  
  // Pin for bsc-dataseed.bnbchain.org (we'll compute it dynamically)
  final pinnedSpkiHashes = <String>[];
  
  client.badCertificateCallback = (cert, host, port) {
    print('badCertificateCallback called for $host');
    try {
      final spkiHash = extractSpkiSha256Base64(cert.der);
      print('SPKI SHA-256 (base64): $spkiHash');
      
      // Check if this certificate's SPKI matches any pinned hash
      if (pinnedSpkiHashes.contains(spkiHash)) {
        print('PIN MATCH! Accepting certificate.');
        return true;
      } else {
        print('PIN MISMATCH! Rejecting certificate.');
        return false;
      }
    } catch (e) {
      print('Error extracting SPKI: $e');
      return false;
    }
  };
  
  // First, let's get the pin by connecting without pinning
  print('=== Getting pin ===');
  final context1 = SecurityContext();
  final client1 = HttpClient(context: context1);
  client1.badCertificateCallback = (cert, host, port) {
    final spkiHash = extractSpkiSha256Base64(cert.der);
    print('Current SPKI: $spkiHash');
    pinnedSpkiHashes.add(spkiHash);
    return true;
  };
  
  try {
    final request = await client1.getUrl(Uri.parse('https://bsc-dataseed.bnbchain.org'));
    request.followRedirects = false;
    final response = await request.close();
    print('First connection: ${response.statusCode}');
  } catch (e) {
    print('Error: $e');
  }
  client1.close();
  
  // Now connect with pinning
  print('=== Connecting with pinning ===');
  final context2 = SecurityContext();
  final client2 = HttpClient(context: context2);
  client2.badCertificateCallback = (cert, host, port) {
    final spkiHash = extractSpkiSha256Base64(cert.der);
    if (pinnedSpkiHashes.contains(spkiHash)) {
      print('PIN MATCH! Accepting.');
      return true;
    }
    print('PIN MISMATCH! Rejecting.');
    return false;
  };
  
  try {
    final request = await client2.getUrl(Uri.parse('https://bsc-dataseed.bnbchain.org'));
    request.followRedirects = false;
    final response = await request.close();
    print('Pinned connection: ${response.statusCode}');
  } catch (e) {
    print('Error with pinning: $e');
  }
  client2.close();
}
