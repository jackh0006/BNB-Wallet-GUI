import 'dart:io';
import 'dart:typed_data';
import 'package:asn1lib/asn1lib.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

void main() async {
  // Fetch a real certificate from a known HTTPS site
  final client = HttpClient();
  client.badCertificateCallback = (cert, host, port) => true;
  
  try {
    final request = await client.getUrl(Uri.parse('https://bsc-dataseed.bnbchain.org'));
    final response = await request.close();
    print('Connected');
  } catch (e) {
    print('Error connecting: $e');
  }
  
  client.close();
  
  // Let's try to parse a known certificate DER
  // Use a simple self-signed cert for testing
  // We'll generate one using OpenSSL if available
}
