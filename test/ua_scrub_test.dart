import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:bnb_wallet_gui/net/privacy_client.dart';
import 'package:bnb_wallet_gui/storage.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Round-6: proves the RPC/explorer transport no longer announces
/// `Dart/<version> (dart:io)` — a software fingerprint DPI and node
/// operators could read and correlate.
class _MockPathProvider extends PathProviderPlatform {
  _MockPathProvider(this.dir);
  final String dir;

  @override
  Future<String?> getApplicationSupportPath() async => dir;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tmp = await Directory.systemTemp.createTemp('bnb-ua-test');
    PathProviderPlatform.instance = _MockPathProvider(tmp.path);
    await AppStorage.init();
  });
  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  test('direct RPC client sends NO User-Agent header at all', () async {
    // The widget-test binding replaces HttpOverrides with a mock that blocks
    // real sockets (all requests 400). Lift it for this test only — we talk to
    // a loopback server we control, and restore the binding's override after.
    final savedOverrides = HttpOverrides.current;
    HttpOverrides.global = null;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    String? seenUserAgent;
    var gotRequest = false;
    server.listen((request) {
      gotRequest = true;
      seenUserAgent = request.headers.value('user-agent');
      request.response
        ..statusCode = 200
        ..write('{"jsonrpc":"2.0","id":1,"result":"0x1"}');
      request.response.close();
    });

    final client = createRpcClient();
    try {
      final response = await client.get(
        Uri.parse('http://127.0.0.1:${server.port}/'),
      );
      expect(response.statusCode, 200);
      expect(gotRequest, isTrue);
      expect(
        seenUserAgent,
        isNull,
        reason: 'the dart:io default "Dart/x.y (dart:io)" fingerprint must not be sent',
      );
    } finally {
      client.close();
      await server.close(force: true);
      HttpOverrides.global = savedOverrides;
    }
  });
}
