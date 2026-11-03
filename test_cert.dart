import 'dart:io';

void main() {
  // Check if we can get a certificate from an HTTPS connection
  final client = HttpClient();
  client.badCertificateCallback = (cert, host, port) {
    print('Certificate received!');
    print('  der length: ${cert.der.length}');
    print('  der first 30: ${cert.der.take(30).toList()}');
    print('  sha1: ${cert.sha1}');
    print('  subject: ${cert.subject}');
    print('  issuer: ${cert.issuer}');
    return true;
  };
  
  client.getUrl(Uri.parse('https://bsc-dataseed.bnbchain.org')).then((request) {
    request.followRedirects = false;
    return request.close();
  }).then((response) {
    print('Response: ${response.statusCode}');
    client.close();
  }).catchError((e) {
    print('Error: $e');
    client.close();
  });
}
