import 'dart:io';
import 'dart:typed_data';

void main() async {
  // Test creating a SecurityContext with custom trusted certificates
  final context = SecurityContext();
  // context.setTrustedCertificates('path/to/cert.pem');
  
  final client = HttpClient(context: context);
  client.badCertificateCallback = (cert, host, port) {
    print('badCertificateCallback called for $host');
    return false;
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
