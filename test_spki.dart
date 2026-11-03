import 'dart:typed_data';
import 'dart:convert';
import 'package:asn1lib/asn1lib.dart';
import 'package:crypto/crypto.dart';

/// Extract SPKI (Subject Public Key Info) from a certificate DER and compute SHA-256
String extractSpkiSha256Base64(Uint8List certDer) {
  final parser = ASN1Parser(certDer);
  final cert = parser.nextObject() as ASN1Sequence;
  
  // Certificate structure:
  // SEQUENCE {
  //   tbsCertificate TBSCertificate,
  //   signatureAlgorithm AlgorithmIdentifier,
  //   signatureValue BIT STRING
  // }
  
  final tbsCert = cert.elements[0] as ASN1Sequence;
  
  // TBSCertificate structure:
  // SEQUENCE {
  //   version [0] EXPLICIT Version,
  //   serialNumber CertificateSerialNumber,
  //   signature AlgorithmIdentifier,
  //   issuer Name,
  //   validity Validity,
  //   subject Name,
  //   subjectPublicKeyInfo SubjectPublicKeyInfo,  // index 6
  //   ...
  // }
  
  final spki = tbsCert.elements[6] as ASN1Object;
  
  // Get the encoded bytes of the SPKI (includes tag and length)
  final spkiDer = spki.encodedBytes;
  
  // Compute SHA-256
  final digest = sha256.convert(spkiDer);
  return base64Encode(digest.bytes);
}

void main() {
  print('SPKI extraction function defined');
}
