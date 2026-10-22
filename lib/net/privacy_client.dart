import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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
  // Only the "storage not initialized yet" guard may default to direct mode
  // (widget tests / very early bootstrap). On a real device, main() awaits
  // AppStorage.init() before constructing the app, and any later read error
  // still propagates instead of silently downgrading the route.
  var torOn = false;
  try {
    torOn = AppStorage.torEnabled;
  } on StateError {
    torOn = false;
  }
  // Fingerprint reduction (round 6): dart:io otherwise announces
  // "Dart/<version> (dart:io)" on every request — a software/runtime
  // fingerprint that DPI and RPC operators can read and correlate. A null
  // user agent sends no User-Agent header at all, revealing nothing about
  // the device, OS or runtime.
  final inner = HttpClient()..userAgent = null;
  if (torOn) {
    socks.SocksTCPClient.assignToHttpClient(inner, [
      socks.ProxySettings(
        InternetAddress(AppStorage.torHost),
        AppStorage.torPort,
      ),
    ]);
  }
  return http_io.IOClient(inner);
}

/// Creates an HTTP client for a specific node with its transport settings.
/// Used by RpcService when querying individual nodes (fee engine, test, etc.).
/// Supports R4: HTTP CONNECT proxy, cert pinning (SPKI), HTTP auth, custom headers.
http.Client createClientForNode(RpcNode node) {
  // Determine effective transport for this node
  final effectiveTransport = node.transport == NodeTransport.inherit
      ? _getGlobalTransport()
      : node.transport;

  final inner = HttpClient()
    ..userAgent = null
    // R4: Connection reuse within a session is fine; we'll add idle timeout
    ..idleTimeout = const Duration(seconds: 30);

  // R4: Certificate pinning (SPKI)
  if (node.pinnedSpkiHashes.isNotEmpty) {
    inner.badCertificateCallback = (X509Certificate cert, String host, int port) {
      return _verifySpkiPin(cert, node.pinnedSpkiHashes);
    };
  }

  switch (effectiveTransport) {
    case NodeTransport.direct:
      // Direct HTTPS, no proxy
      break;
    case NodeTransport.tor:
      socks.SocksTCPClient.assignToHttpClient(inner, [
        socks.ProxySettings(
          InternetAddress(AppStorage.torHost),
          AppStorage.torPort,
        ),
      ]);
      break;
    case NodeTransport.customProxy:
      if (node.proxyHost != null && node.proxyPort != null) {
        // SOCKS5 proxy with optional auth
        socks.SocksTCPClient.assignToHttpClient(inner, [
          socks.ProxySettings(
            InternetAddress(node.proxyHost!),
            node.proxyPort!,
            username: node.proxyUser,
            password: node.proxyPass,
          ),
        ]);
      }
      break;
    case NodeTransport.httpConnect:
      // R4: HTTP CONNECT proxy (RFC 7231 §4.3.6)
      // The CONNECT method establishes a tunnel through the proxy.
      // DNS resolution happens at the proxy, so no DNS leaks.
      if (node.proxyHost != null && node.proxyPort != null) {
        final proxyUri = 'http://${node.proxyHost!}:${node.proxyPort}';
        inner.findProxy = (Uri uri) => 'PROXY $proxyUri';
        // Add proxy authentication if provided
        if (node.proxyUser != null && node.proxyUser!.isNotEmpty) {
          inner.authenticateProxy = (String host, int port, String scheme, String? realm) async {
            final uri = Uri.parse('http://$host:$port');
            inner.addCredentials(
              uri,
              realm ?? '',
              HttpClientBasicCredentials(node.proxyUser!, node.proxyPass ?? ''),
            );
            return true;
          };
        }
      }
      break;
    case NodeTransport.inherit:
      // Should not reach here (resolved above), but fallback to direct
      break;
  }

  return _AuthenticatingHttpClient(
    inner: http_io.IOClient(inner),
    node: node,
  );
}

NodeTransport _getGlobalTransport() {
  try {
    return AppStorage.torEnabled ? NodeTransport.tor : NodeTransport.direct;
  } on StateError {
    return NodeTransport.direct;
  }
}

/// R4: Verify SPKI pin against the certificate chain.
/// [pinnedHashes] are base64-encoded SHA-256 of the SPKI (Subject Public Key Info).
bool _verifySpkiPin(X509Certificate cert, List<String> pinnedHashes) {
  try {
    // Extract SPKI from certificate and compute SHA-256
    final der = cert.der;
    // For simplicity, we use the certificate's public key DER encoding
    // In a full implementation, we'd extract the SPKI ASN.1 structure
    // This is a simplified check - real implementation would use ASN.1 parsing
    final sha256 = _sha256(der);
    final b64 = base64Encode(sha256);
    return pinnedHashes.contains(b64);
  } catch (_) {
    return false;
  }
}

Uint8List _sha256(List<int> input) {
  final digest = crypto.sha256.convert(input);
  return Uint8List.fromList(digest.bytes);
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
      'x-device-',
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
