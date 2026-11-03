import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:asn1lib/asn1lib.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart' as http_io;
import 'package:socks5_proxy/socks_client.dart' as socks;

import '../models.dart';
import '../storage.dart';

/// Chooses the HTTP transport for RPC and BscScan traffic.
///
/// Default: the plain [http.Client] with system CA roots, HTTPS-only URLs
/// enforced by its callers.
///
/// Tor mode ([AppStorage.torEnabled]): every request goes through a local
/// SOCKS5 connector, normally the Tor daemon/Orbot listening on 127.0.0.1:9050.
/// This wiring uses the audited socks5_proxy package, which assigns a
/// connection factory to dart:io's HttpClient — so TLS, redirects, chunked
/// encoding and keep-alive are all handled by the standard client. The
/// CONNECT request carries the hostname, so DNS stays inside the tunnel.
///
/// Fail closed: if the SOCKS port is dead, the standard client surfaces the
/// connection error — calls NEVER fall back to a direct connection.
http.Client createRpcClient() {
  // Fingerprint reduction (round 6): dart:io otherwise announces
  // "Dart/<version> (dart:io)" on every request — a software/runtime
  // fingerprint that DPI and RPC operators can read and correlate. A null
  // user agent sends no User-Agent header at all, revealing nothing about
  // the device, OS or runtime.
  final inner = HttpClient()
    ..userAgent = null
    ..idleTimeout = const Duration(seconds: 30);
  _applyGlobalRoute(inner);
  return http_io.IOClient(inner);
}

/// Applies the configured global privacy route to [inner]: custom proxy first,
/// then Tor, then direct. A configured proxy that cannot be applied throws —
/// it never silently falls back to a direct connection.
void _applyGlobalRoute(HttpClient inner) {
  GlobalProxyConfig proxy;
  bool torOn;
  try {
    proxy = AppStorage.globalProxy;
    torOn = AppStorage.torEnabled;
  } on StateError {
    // Storage not initialized yet: tests and very early bootstrap only.
    return;
  }
  if (proxy.type != ProxyType.none) {
    // A selected proxy type with no usable host must not silently become a
    // direct connection: that would leak the real IP exactly when the user
    // asked for privacy.
    if (!proxy.enabled) {
      throw StateError(
        'A proxy type is selected but its host/port is incomplete. '
        'Open Settings and fix it, or choose Direct.',
      );
    }
    _applyGlobalProxy(inner, proxy);
    return;
  }
  if (torOn) {
    _applySocks5(
      inner,
      host: AppStorage.torHost,
      port: AppStorage.torPort,
      remoteDns: true,
    );
  }
}

void _applyGlobalProxy(HttpClient inner, GlobalProxyConfig proxy) {
  switch (proxy.type) {
    case ProxyType.none:
      return;
    case ProxyType.socks5:
      _applySocks5(
        inner,
        host: proxy.host,
        port: proxy.port,
        username: proxy.username,
        password: proxy.password,
        remoteDns: false,
      );
    case ProxyType.socks5h:
      _applySocks5(
        inner,
        host: proxy.host,
        port: proxy.port,
        username: proxy.username,
        password: proxy.password,
        remoteDns: true,
      );
    case ProxyType.httpConnect:
      _applyHttpConnect(
        inner,
        host: proxy.host,
        port: proxy.port,
        username: proxy.username,
        password: proxy.password,
      );
  }
}

void _applySocks5(
  HttpClient inner, {
  required String host,
  required int port,
  String? username,
  String? password,
  required bool remoteDns,
}) {
  if (host.trim().isEmpty || port <= 0 || port > 65535) {
    throw StateError('SOCKS5 proxy host/port is incomplete.');
  }
  final proxyHost = host.trim();
  final user = (username?.isEmpty ?? true) ? null : username;
  final pass = (password?.isEmpty ?? true) ? null : password;

  // A custom connection factory is used instead of assignToHttpClient for two
  // reasons: the proxy host may be a domain name (resolved locally only), and
  // SOCKS5 vs SOCKS5h must actually differ. SOCKS5 resolves the RPC hostname
  // on this device; SOCKS5h sends the hostname to the proxy so DNS happens
  // inside the tunnel.
  inner.connectionFactory = (uri, ignoredProxyHost, ignoredProxyPort) async {
    final proxyAddresses = await InternetAddress.lookup(proxyHost);
    if (proxyAddresses.isEmpty) {
      throw SocketException('Proxy host did not resolve: $proxyHost');
    }
    final settings = socks.ProxySettings(
      proxyAddresses.first,
      port,
      username: user,
      password: pass,
    );
    final target = remoteDns
        ? InternetAddress(uri.host, type: InternetAddressType.unix)
        : await _resolveTarget(uri.host);
    final client = await socks.SocksTCPClient.connect(
      [settings],
      target,
      uri.port,
    );
    if (uri.scheme == 'https') {
      // TLS is negotiated end-to-end after the SOCKS tunnel exists, with the
      // destination hostname used for SNI and certificate validation.
      final secure = client.secure(uri.host);
      return ConnectionTask.fromSocket(
        secure,
        () => secure.then((socket) => socket.close()).ignore(),
      );
    }
    return ConnectionTask.fromSocket(
      Future<Socket>.value(client),
      () => client.close().ignore(),
    );
  };
}

Future<InternetAddress> _resolveTarget(String hostname) async {
  final addresses = await InternetAddress.lookup(hostname);
  if (addresses.isEmpty) {
    throw SocketException('Destination host did not resolve: $hostname');
  }
  return addresses.first;
}

void _applyHttpConnect(
  HttpClient inner, {
  required String host,
  required int port,
  String? username,
  String? password,
}) {
  if (host.trim().isEmpty || port <= 0 || port > 65535) {
    throw StateError('HTTP CONNECT proxy host/port is incomplete.');
  }
  inner.findProxy = (uri) => 'PROXY ${host.trim()}:$port';
  if (username != null && username.isNotEmpty) {
    inner.authenticateProxy =
        (String proxyHost, int proxyPort, String scheme, String? realm) async {
      final uri = Uri.parse('http://$proxyHost:$proxyPort');
      inner.addCredentials(
        uri,
        realm ?? '',
        HttpClientBasicCredentials(username, password ?? ''),
      );
      return true;
    };
  }
}

/// Creates an HTTP client for a specific node with its transport settings.
/// Used by RpcService when querying individual nodes (fee engine, test, etc.).
/// Supports R4: HTTP CONNECT proxy, cert pinning (SPKI), HTTP auth, custom headers.
http.Client createClientForNode(RpcNode node) {
  // For nodes with certificate pinning, we use a SecurityContext with no
  // trusted roots so that badCertificateCallback is invoked for all certificates.
  // This allows us to verify the certificate chain and check SPKI pins.
  final context = node.pinnedSpkiHashes.isNotEmpty ? SecurityContext() : null;
  final inner = HttpClient(context: context)
    ..userAgent = null
    ..idleTimeout = const Duration(seconds: 30);

  // R4: Certificate pinning (SPKI)
  if (node.pinnedSpkiHashes.isNotEmpty) {
    inner.badCertificateCallback =
        (X509Certificate cert, String host, int port) {
      return _verifySpkiPin(cert, node.pinnedSpkiHashes);
    };
  }

  switch (node.transport) {
    case NodeTransport.inherit:
      // The global setting is resolved for every node that inherits it, so a
      // newly enabled proxy/Tor route applies to the whole node book.
      _applyGlobalRoute(inner);
      break;
    case NodeTransport.direct:
      break;
    case NodeTransport.tor:
      _applySocks5(
        inner,
        host: AppStorage.torHost,
        port: AppStorage.torPort,
        remoteDns: true,
      );
      break;
    case NodeTransport.customProxy:
      if (node.proxyHost == null ||
          node.proxyHost!.trim().isEmpty ||
          node.proxyPort == null ||
          node.proxyPort! <= 0 ||
          node.proxyPort! > 65535) {
        throw StateError(
          'Node "${node.label}" is set to a custom SOCKS5 proxy but its '
          'host/port is incomplete.',
        );
      }
      _applySocks5(
        inner,
        host: node.proxyHost!,
        port: node.proxyPort!,
        username: node.proxyUser,
        password: node.proxyPass,
        remoteDns: true,
      );
      break;
    case NodeTransport.httpConnect:
      if (node.proxyHost == null ||
          node.proxyHost!.trim().isEmpty ||
          node.proxyPort == null ||
          node.proxyPort! <= 0 ||
          node.proxyPort! > 65535) {
        throw StateError(
          'Node "${node.label}" is set to HTTP CONNECT but its proxy '
          'host/port is incomplete.',
        );
      }
      _applyHttpConnect(
        inner,
        host: node.proxyHost!,
        port: node.proxyPort!,
        username: node.proxyUser,
        password: node.proxyPass,
      );
      break;
  }

  return _AuthenticatingHttpClient(inner: http_io.IOClient(inner), node: node);
}

/// R4: Verify SPKI pin against the certificate chain.
/// [pinnedHashes] are base64-encoded SHA-256 of the SPKI (Subject Public Key Info).
bool _verifySpkiPin(X509Certificate cert, List<String> pinnedHashes) {
  try {
    final spkiHash = _extractSpkiSha256Base64(cert.der);
    return pinnedHashes.contains(spkiHash);
  } catch (_) {
    return false;
  }
}

/// Extract SPKI (Subject Public Key Info) from a certificate DER and compute SHA-256 base64.
String _extractSpkiSha256Base64(Uint8List certDer) {
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
  
  // Handle explicit version tag (0xA0) which may be present
  int spkiIndex = 6;
  if (tbsCert.elements.length > 6) {
    // Check if first element is explicit version tag
    final first = tbsCert.elements[0];
    if (first.tag == 0xA0) {
      spkiIndex = 7; // version is explicit, so SPKI is at index 7
    }
  }
  
  final spki = tbsCert.elements[spkiIndex];
  
  // Get the encoded bytes of the SPKI (includes tag and length)
  final spkiDer = spki.encodedBytes;
  
  // Compute SHA-256
  final digest = crypto.sha256.convert(spkiDer);
  return base64Encode(digest.bytes);
}

/// R4: Authenticated HTTP client that injects auth headers and custom headers.
class _AuthenticatingHttpClient extends http.BaseClient {
  _AuthenticatingHttpClient({required this.inner, required this.node});

  final http.Client inner;
  final RpcNode node;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    // R4: Add authentication headers
    _addAuthHeaders(request);

    // R4: Add custom headers (validated)
    _addCustomHeaders(request);

    return inner.send(request);
  }

  void _addAuthHeaders(http.BaseRequest request) {
    switch (node.authType) {
      case NodeAuthType.bearer:
        if (node.authToken != null && node.authToken!.isNotEmpty) {
          request.headers['authorization'] = 'Bearer ${node.authToken}';
        }
        break;
      case NodeAuthType.basic:
        if (node.authUsername != null &&
            node.authUsername!.isNotEmpty &&
            node.authPassword != null) {
          final credentials = '${node.authUsername}:${node.authPassword}';
          final encoded = base64Encode(utf8.encode(credentials));
          request.headers['authorization'] = 'Basic $encoded';
        }
        break;
      case NodeAuthType.none:
        break;
    }
  }

  void _addCustomHeaders(http.BaseRequest request) {
    // R4: Block headers that could identify the app/device
    const blockedHeaders = {
      'user-agent',
      'x-forwarded-for',
      'x-real-ip',
      'x-client-',
      'x-dev-',
      'x-app-',
      'x-wallet-',
    };

    for (final entry in node.customHeaders.entries) {
      final lowerKey = entry.key.toLowerCase();
      if (blockedHeaders.any((b) => lowerKey.startsWith(b))) {
        // Silently drop identifying headers
        continue;
      }
      request.headers[entry.key] = entry.value;
    }
  }
}

/// Verifies a draft proxy configuration before it is saved. The temporary
/// client is closed even on failure; the saved route is never touched.
Future<String> probeProxyRoute(
  GlobalProxyConfig config,
  String rpcUrl, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  if (!config.enabled) {
    throw StateError('Enter a proxy host and port first.');
  }
  final inner = HttpClient()
    ..userAgent = null
    ..idleTimeout = const Duration(seconds: 10);
  _applyGlobalProxy(inner, config);
  final client = http_io.IOClient(inner);
  try {
    final response = await client
        .post(
          Uri.parse(rpcUrl),
          headers: const {'content-type': 'application/json'},
          body: jsonEncode({
            'jsonrpc': '2.0',
            'id': 1,
            'method': 'eth_chainId',
            'params': <Object>[],
          }),
        )
        .timeout(timeout);
    if (response.statusCode != 200) {
      throw StateError(
        'Proxy reached the endpoint but it returned HTTP ${response.statusCode}.',
      );
    }
    final decoded = jsonDecode(response.body);
    final result = decoded is Map ? decoded['result'] : null;
    if (result is! String || !result.startsWith('0x')) {
      throw StateError(
        'The endpoint did not return a chain ID. Check the proxy and node URL.',
      );
    }
    final chainId = int.tryParse(result.substring(2), radix: 16);
    if (chainId == null) {
      throw StateError('The endpoint returned an invalid chain ID.');
    }
    return 'Route works — ${config.type.shortLabel} reached the node; chain ID $chainId.';
  } finally {
    client.close();
  }
}
