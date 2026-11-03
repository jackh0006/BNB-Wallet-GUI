import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:bnb_wallet_gui/models.dart';
import 'package:bnb_wallet_gui/net/privacy_client.dart';

/// End-to-end check of the SPKI story:
///
///  * a certificate that fails the normal CA/hostname validation is refused
///    even when its pin matches;
///  * a correct pin succeeds only after the standard handshake passed;
///  * a wrong pin is refused;
///  * pin + HTTP CONNECT is rejected before any socket is opened.
///
/// Certificates are generated per run with the system openssl. They are
/// ephemeral, never committed, and have no relation to any real service.
void main() {
  final opensslAvailable = _opensslAvailable();
  if (!opensslAvailable) {
    test('TLS pinning integration', () {
      fail('openssl is required for the TLS pinning integration test');
    });
    return;
  }

  late Directory workDir;
  late HttpServer server;
  late int port;
  late SecurityContext clientContext;
  late String pin;

  setUpAll(() async {
    workDir = await Directory.systemTemp.createTemp('bnb-tls-test-');
    await _run([
      'req',
      '-x509',
      '-newkey',
      'rsa:2048',
      '-nodes',
      '-keyout',
      '${workDir.path}/ca.key',
      '-out',
      '${workDir.path}/ca.crt',
      '-days',
      '2',
      '-subj',
      '/CN=BNB Test CA',
      '-addext',
      'basicConstraints=critical,CA:TRUE',
      '-addext',
      'keyUsage=critical,keyCertSign,cRLSign',
    ]);
    await _run([
      'genpkey',
      '-algorithm',
      'RSA',
      '-pkeyopt',
      'rsa_keygen_bits:2048',
      '-out',
      '${workDir.path}/server.key',
    ]);
    await _run([
      'req',
      '-new',
      '-key',
      '${workDir.path}/server.key',
      '-out',
      '${workDir.path}/server.csr',
      '-subj',
      '/CN=127.0.0.1',
    ]);
    File('${workDir.path}/server.ext').writeAsStringSync('''
basicConstraints=CA:FALSE
keyUsage=digitalSignature,keyEncipherment
extendedKeyUsage=serverAuth
subjectAltName=IP:127.0.0.1
''');
    await _run([
      'x509',
      '-req',
      '-in',
      '${workDir.path}/server.csr',
      '-CA',
      '${workDir.path}/ca.crt',
      '-CAkey',
      '${workDir.path}/ca.key',
      '-CAcreateserial',
      '-out',
      '${workDir.path}/server.crt',
      '-days',
      '2',
      '-extfile',
      '${workDir.path}/server.ext',
    ]);
    await _run([
      'x509',
      '-in',
      '${workDir.path}/server.crt',
      '-outform',
      'DER',
      '-out',
      '${workDir.path}/server.der',
    ]);

    pin = spkiSha256Base64FromDer(
      File('${workDir.path}/server.der').readAsBytesSync(),
    );
    final opensslPin = await _opensslPin(workDir.path);
    expect(pin, opensslPin, reason: 'Dart and openssl must agree on the pin');

    final serverContext = SecurityContext()
      ..useCertificateChain('${workDir.path}/server.crt')
      ..usePrivateKey('${workDir.path}/server.key');
    server = await HttpServer.bindSecure(
      InternetAddress.anyIPv4,
      0,
      serverContext,
    );
    port = server.port;
    server.listen((request) async {
      request.response
        ..statusCode = HttpStatus.ok
        ..write('ok');
      await request.response.close();
    });

    clientContext = SecurityContext(withTrustedRoots: false)
      ..setTrustedCertificates('${workDir.path}/ca.crt');
  });

  tearDownAll(() async {
    await server.close(force: true);
    try {
      await workDir.delete(recursive: true);
    } catch (_) {}
  });

  test('correct pin succeeds after standard TLS validation', () async {
    final socket = await openPinnedTlsConnection('127.0.0.1', port, [
      pin,
    ], context: clientContext);
    expect(socket.peerCertificate, isNotNull);
    socket.destroy();
  });

  test('wrong pin is refused even though the chain is trusted', () async {
    await expectLater(
      openPinnedTlsConnection('127.0.0.1', port, [
        'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=',
      ], context: clientContext),
      throwsA(isA<HandshakeException>()),
    );
  });

  test('pin does not bypass hostname validation', () async {
    await expectLater(
      openPinnedTlsConnection('127.0.0.2', port, [pin], context: clientContext),
      throwsA(isA<HandshakeException>()),
    );
  });

  test('pin does not bypass CA validation', () async {
    await expectLater(
      openPinnedTlsConnection('127.0.0.1', port, [
        pin,
      ], context: SecurityContext(withTrustedRoots: false)),
      throwsA(isA<HandshakeException>()),
    );
  });

  test('verifySpkiPin fails closed on an empty pin list', () async {
    final socket = await SecureSocket.connect(
      '127.0.0.1',
      port,
      context: clientContext,
    );
    try {
      expect(verifySpkiPin(socket.peerCertificate!, const []), isFalse);
      expect(verifySpkiPin(socket.peerCertificate!, [pin]), isTrue);
    } finally {
      socket.destroy();
    }
  });

  test('pinned HTTP CONNECT is refused before opening a socket', () {
    final node = RpcNode(
      label: 'pinned-connect',
      url: 'https://127.0.0.1:1',
      transport: NodeTransport.httpConnect,
      proxyHost: '127.0.0.1',
      proxyPort: 1,
      pinnedSpkiHashes: [pin],
    );
    expect(() => createClientForNode(node), throwsA(isA<StateError>()));
  });
}

bool _opensslAvailable() {
  try {
    return Process.runSync('openssl', ['version']).exitCode == 0;
  } catch (_) {
    return false;
  }
}

Future<void> _run(List<String> args) async {
  final result = await Process.run('openssl', args);
  if (result.exitCode != 0) {
    throw StateError(
      'openssl ${args.first} failed (${result.exitCode}):\n'
      '${result.stdout}\n${result.stderr}',
    );
  }
}

Future<String> _opensslPin(String dir) async {
  final publicKey = await Process.run('openssl', [
    'x509',
    '-in',
    '$dir/server.crt',
    '-pubkey',
    '-noout',
  ]);
  if (publicKey.exitCode != 0) {
    throw StateError('openssl x509 -pubkey failed: ${publicKey.stderr}');
  }
  final pkey = await Process.start('openssl', [
    'pkey',
    '-pubin',
    '-outform',
    'DER',
  ]);
  pkey.stdin.add(utf8.encode('${publicKey.stdout}'));
  await pkey.stdin.close();
  final bytes = await pkey.stdout.fold<List<int>>(
    <int>[],
    (all, chunk) => all..addAll(chunk),
  );
  final pkeyCode = await pkey.exitCode;
  if (pkeyCode != 0) {
    final stderr = await pkey.stderr.transform(utf8.decoder).join();
    throw StateError('openssl pkey failed: $stderr');
  }

  final digest = await Process.start('openssl', ['dgst', '-sha256', '-binary']);
  digest.stdin.add(bytes);
  await digest.stdin.close();
  final hashed = await digest.stdout.fold<List<int>>(
    <int>[],
    (all, chunk) => all..addAll(chunk),
  );
  if (await digest.exitCode != 0) {
    throw StateError('openssl dgst failed');
  }
  return base64Encode(hashed);
}
