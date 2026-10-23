import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'rpc_service.dart';

/// Persists public configuration and the encrypted local vault.
///
/// Secrets are never stored in [SharedPreferences]; only public preferences
/// and the already-encrypted vault blob touch the normal app directories.
class AppStorage {
  AppStorage._();

  static final FlutterSecureStorage _secure = const FlutterSecureStorage();

  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  static SharedPreferences get prefs {
    final value = _prefs;
    if (value == null) {
      throw StateError('AppStorage.init() must be called before use.');
    }
    return value;
  }

  // ---- public configuration ----

  static String get network => prefs.getString('network') ?? 'mainnet';
  static Future<void> setNetwork(String value) =>
      prefs.setString('network', value);

  static String get rpc {
    final saved = prefs.getString('rpc');
    if (saved != null && saved.startsWith('https://')) return saved;
    return BnbNetworks.defaultRpcs[network] ??
        BnbNetworks.defaultRpcs['mainnet']!;
  }

  /// Public address of the last watch-only profile, if any. Never a secret.
  static String? get watchAddress => prefs.getString('watch_address');
  static Future<void> setWatchAddress(String? value) async {
    if (value == null || value.isEmpty) {
      await prefs.remove('watch_address');
    } else {
      await prefs.setString('watch_address', value);
    }
  }

  /// §9 Lite mode: static status icons and simple lists, no pulsing.
  static bool get liteMode => prefs.getBool('lite_mode') ?? false;
  static Future<void> setLiteMode(bool value) =>
      prefs.setBool('lite_mode', value);

  /// Theme mode: system (0), light (1), dark (2), amoled (3)
  static int get themeModeIndex => prefs.getInt('theme_mode') ?? 0;
  static Future<void> setThemeMode(int value) =>
      prefs.setInt('theme_mode', value);

  /// Locale code (e.g., 'en', 'fa', 'ar', 'zh', 'ru', 'es')
  static String get locale => prefs.getString('locale') ?? 'en';
  static Future<void> setLocale(String value) =>
      prefs.setString('locale', value);

  static Future<void> setRpc(String value) => prefs.setString('rpc', value);

  static List<RpcNode> get nodes {
    final raw = prefs.getString('nodes');
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return [
        for (final item in list)
          if (item is Map<String, dynamic>) RpcNode.fromJson(item),
      ];
    } catch (_) {
      return [];
    }
  }

  static Future<void> setNodes(List<RpcNode> nodes) =>
      prefs.setString('nodes', jsonEncode([for (final n in nodes) n.toJson()]));

  static List<TokenInfo> get customTokens {
    final raw = prefs.getString('tokens');
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return [
        for (final item in list)
          if (item is Map<String, dynamic>) TokenInfo.fromJson(item),
      ];
    } catch (_) {
      return [];
    }
  }

  static Future<void> setCustomTokens(List<TokenInfo> tokens) => prefs
      .setString('tokens', jsonEncode([for (final t in tokens) t.toJson()]));

  /// §3: built-in tokens can be hidden without deleting their metadata. Keys
  /// are `network:0xaddress` so the same contract on another chain is separate.
  static Set<String> get hiddenTokens => {
    ...?prefs.getStringList('hidden_tokens'),
  };

  static Future<void> setHiddenTokens(Iterable<String> keys) =>
      prefs.setStringList('hidden_tokens', keys.toList()..sort());

  static List<WalletProfile> get profiles {
    final raw = prefs.getString('profiles');
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return [
        for (final item in list)
          if (item is Map<String, dynamic>) WalletProfile.fromJson(item),
      ];
    } catch (_) {
      return [];
    }
  }

  static Future<void> setProfiles(List<WalletProfile> profiles) =>
      prefs.setString(
        'profiles',
        jsonEncode([for (final p in profiles) p.toJson()]),
      );

  // ---- local pending transactions (public chain facts only, never keys) ----

  static String? getPendingTxsJson() => prefs.getString('pending_txs');
  static Future<void> setPendingTxsJson(String value) =>
      prefs.setString('pending_txs', value);

  // ---- BscScan API key (secret, secure storage only) ----

  static Future<String?> getBscscanKey() =>
      _secure.read(key: 'bscscan_api_key');
  static Future<void> setBscscanKey(String value) =>
      _secure.write(key: 'bscscan_api_key', value: value);
  static Future<void> clearBscscanKey() =>
      _secure.delete(key: 'bscscan_api_key');

  // ---- encrypted vault ----

  static Future<File> _vaultFile() async {
    final dir = await getApplicationSupportDirectory();
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    if (Platform.isLinux || Platform.isMacOS) {
      final mode = await dir.stat();
      if (mode.type == FileSystemEntityType.directory) {
        // Best-effort owner-only directory; never fatal on platforms that
        // do not support POSIX modes.
        try {
          await Process.run('chmod', ['700', dir.path]);
        } catch (_) {}
      }
    }
    return File('${dir.path}/bnb-wallet-vault.bnb');
  }

  /// Returns the app's data directory (same as vault/receipts/logs).
  static Future<Directory> getDataDirectory() async {
    final dir = await getApplicationSupportDirectory();
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    if (Platform.isLinux || Platform.isMacOS) {
      final mode = await dir.stat();
      if (mode.type == FileSystemEntityType.directory) {
        try {
          await Process.run('chmod', ['700', dir.path]);
        } catch (_) {}
      }
    }
    return dir;
  }

  static Future<bool> vaultExists() async => (await _vaultFile()).exists();

  static Future<String?> readVault() async {
    try {
      final file = await _vaultFile();
      if (!await file.exists()) return null;
      final stat = await file.stat();
      if (stat.type != FileSystemEntityType.file) {
        throw const FileSystemException('Vault must be a regular file.');
      }
      if (stat.size > 5 * 1024 * 1024) {
        throw const FileSystemException('Vault is too large.');
      }
      return await file.readAsString();
    } catch (_) {
      return null;
    }
  }

  static Future<void> writeVault(String base64) async {
    final file = await _vaultFile();
    final sink = file.openWrite(mode: FileMode.write);
    sink.write(base64);
    await sink.flush();
    await sink.close();
    if (Platform.isLinux || Platform.isMacOS) {
      try {
        await Process.run('chmod', ['600', file.path]);
      } catch (_) {}
    }
  }

  static Future<void> deleteVault() async {
    final file = await _vaultFile();
    if (await file.exists()) await file.delete();
    final tmp = File('${file.path}.tmp');
    if (await tmp.exists()) await tmp.delete();
  }

  /// Atomic save: writes a temp file first, then renames it over the final
  /// path (atomic on POSIX). A crash can therefore never leave a half-written
  /// vault in place of the good one.
  static Future<void> writeVaultAtomic(String base64) async {
    final file = await _vaultFile();
    final tmp = File('${file.path}.tmp');
    final data = utf8.encode(base64);
    final sink = tmp.openWrite(mode: FileMode.write);
    sink.add(data);
    await sink.flush();
    await sink.close();
    try {
      await tmp.rename(file.path);
    } on FileSystemException {
      // rename() refuses to replace an existing file on some platforms.
      await file.delete();
      await tmp.rename(file.path);
    }
    if (Platform.isLinux || Platform.isMacOS) {
      try {
        await Process.run('chmod', ['600', file.path]);
      } catch (_) {}
    }
  }

  // ---- encrypted local receipts (key from wallet + drawer, see receipt_store) ----

  static Future<File> _receiptsFile() async {
    final vault = await _vaultFile();
    return File('${vault.parent.path}/bnb-wallet-receipts.bin');
  }

  static Future<String?> readReceipts() async {
    try {
      final file = await _receiptsFile();
      if (!await file.exists()) return null;
      final stat = await file.stat();
      if (stat.type != FileSystemEntityType.file) return null;
      if (stat.size > 5 * 1024 * 1024) return null;
      return await file.readAsString();
    } catch (_) {
      return null;
    }
  }

  /// Atomic save, same pattern as the vault: temp file, rename, owner-only.
  static Future<void> writeReceiptsAtomic(String base64) async {
    final file = await _receiptsFile();
    final tmp = File('${file.path}.tmp');
    final sink = tmp.openWrite(mode: FileMode.write);
    sink.write(base64);
    await sink.flush();
    await sink.close();
    try {
      await tmp.rename(file.path);
    } on FileSystemException {
      await file.delete();
      await tmp.rename(file.path);
    }
    if (Platform.isLinux || Platform.isMacOS) {
      try {
        await Process.run('chmod', ['600', file.path]);
      } catch (_) {}
    }
  }

  /// Erases everything the app can reach: shredded vault, preferences,
  /// secure-storage items. Overwriting flash is best-effort only (wear
  /// levelling makes guarantees impossible) — crypto-erase (deleting the
  /// device-bound key) is the strong part: remaining ciphertext stays inert.
  ///
  /// Returns the items that could NOT be removed (empty = fully clean), so
  /// the UI can never claim success while something still exists on disk.
  static Future<List<String>> eraseAllData() async {
    final leftovers = <String>[];
    final vault = await _vaultFile();
    final receipts = await _receiptsFile();
    for (final file in [
      vault,
      File('${vault.path}.tmp'),
      receipts,
      File('${receipts.path}.tmp'),
    ]) {
      try {
        if (await file.exists()) {
          final stat = await file.stat();
          // Best-effort shred with random bytes before unlink.
          final random = math.Random.secure();
          final junk = <int>[
            for (var i = 0; i < stat.size; i++) random.nextInt(256),
          ];
          await file.writeAsBytes(junk, flush: true);
          await file.delete();
        }
      } catch (_) {
        // Never block erase on single-file issues; the verification below
        // reports whatever survived instead of pretending it worked.
      }
      try {
        if (await file.exists()) leftovers.add(file.path);
      } catch (_) {
        leftovers.add(file.path);
      }
    }
    // The locked drawer holds the same class of key as the keyring copy:
    // shred it too, and drop the in-memory memo so a restart starts clean.
    final drawer = await _drawerFile();
    try {
      if (await drawer.exists()) {
        final stat = await drawer.stat();
        final random = math.Random.secure();
        await drawer.writeAsBytes([
          for (var i = 0; i < stat.size; i++) random.nextInt(256),
        ], flush: true);
        await drawer.delete();
      }
    } catch (_) {}
    try {
      if (await drawer.exists()) leftovers.add(drawer.path);
    } catch (_) {
      leftovers.add(drawer.path);
    }
    _deviceSecretCache = null;
    lastDeviceSecretFromDrawer = false;
    // Preferences: clear every key the plugin holds, then remove the backing
    // file itself — "erase everything" must leave no readable state behind.
    try {
      await prefs.clear();
    } catch (_) {}
    try {
      final prefsFile = File(
        '${(await getApplicationSupportDirectory()).path}'
        '/shared_preferences.json',
      );
      if (await prefsFile.exists()) await prefsFile.delete();
      if (await prefsFile.exists()) leftovers.add(prefsFile.path);
    } catch (_) {}
    for (final key in const [
      'network',
      'rpc',
      'nodes',
      'tokens',
      'profiles',
      'pending_txs',
      'auto_lock_seconds',
      'tor_enabled',
      'tor_host',
      'tor_port',
      'strict_node',
      'node_warned',
      'token_user_sources',
      'hidden_tokens',
      'watch_address',
      'lite_mode',
    ]) {
      try {
        if (prefs.containsKey(key)) leftovers.add('preference "$key"');
      } catch (_) {}
    }
    for (final task in [
      clearBscscanKey,
      clearPinHash,
      clearDeviceSecret,
      clearBackoffState,
    ]) {
      try {
        await task();
      } catch (_) {}
    }
    return leftovers;
  }

  // ---- optional app lock PIN (Argon2id hash, never the PIN itself) ----

  static Future<String?> getPinHash() => _secure.read(key: 'app_lock_pin_hash');
  static Future<void> setPinHash(String value) =>
      _secure.write(key: 'app_lock_pin_hash', value: value);
  static Future<void> clearPinHash() =>
      _secure.delete(key: 'app_lock_pin_hash');

  // ---- device-bound secret (second vault key factor) ----

  /// Memoized handle: the store that owns the device secret is consulted at
  /// most ONCE per session. Repeating storage round-trips on every vault
  /// operation starved the window thread on weak Ubuntu systems (taste
  /// round 3: "Force Quit / Wait" freezes).
  static String? _deviceSecretCache;

  /// Set for the current call when the secret came from (or was written to)
  /// the locked drawer instead of the platform keyring. The app narrates
  /// this state once per session, in plain words.
  static bool lastDeviceSecretFromDrawer = false;

  /// Hard limit for one keyring round-trip. libsecret calls run on the
  /// window (GTK main) thread in the Linux plugin, so an unbounded wait
  /// there freezes the whole app.
  static const Duration _keyringTimeout = Duration(seconds: 3);

  /// Android/iOS first choice: Keystore/secure-store-backed secret — it
  /// behaves well there and nothing blocks a UI thread. Desktops (Linux,
  /// macOS, Windows) deliberately use the locked drawer INSTEAD of the
  /// keyring: the Linux secure-storage plugin runs libsecret synchronously
  /// inside the GTK window thread, which froze weak machines exactly when a
  /// fresh wallet was being stored. Machine binding is preserved either way
  /// (a copied vault stays inert without THIS machine's drawer/keyring).
  static bool get _keyringPreferred => Platform.isAndroid || Platform.isIOS;

  /// Reads (or creates once) the 32-byte device-bound secret.
  ///
  /// Safety rule (unchanged): if a vault already exists and its secret can
  /// neither be found anywhere nor migrated, the wallet FAILS CLOSED — it
  /// never mints a replacement that would lock the user out of their own
  /// vault.
  static Future<String> getOrGenerateDeviceSecret() async {
    final cached = _deviceSecretCache;
    if (cached != null) return cached;

    lastDeviceSecretFromDrawer = false;
    return _keyringPreferred ? _viaKeyring() : _viaDrawer();
  }

  /// Mobile path: platform keyring first, drawer as the emergency fallback,
  /// fail-closed when a vault depends on a stuck keyring.
  static Future<String> _viaKeyring() async {
    String? keyring;
    var keyringStuck = false;
    try {
      keyring = await _secure.read(key: _deviceKey).timeout(_keyringTimeout);
    } on Exception {
      keyringStuck = true;
    }
    if (keyring != null && keyring.isNotEmpty) {
      try {
        if (base64Decode(keyring).length == 32) {
          _deviceSecretCache = keyring;
          return keyring;
        }
      } on FormatException {
        // Broken record — treat like an empty keyring slot.
      }
    }

    String? drawer;
    try {
      drawer = await _readDrawerSecret();
    } on Exception {
      drawer = null;
    }
    if (drawer != null) {
      _deviceSecretCache = drawer;
      lastDeviceSecretFromDrawer = true;
      return drawer;
    }

    // Nothing readable anywhere yet. A stuck keyring is only fatal when a
    // vault already depends on its secret living inside the keyring — in
    // that case retry once, then fail closed. Minting here would lock the
    // user out of their own vault forever.
    if (keyringStuck && await vaultExists()) {
      try {
        final retry = await _secure
            .read(key: _deviceKey)
            .timeout(_keyringTimeout);
        if (retry != null && retry.isNotEmpty) {
          if (base64Decode(retry).length == 32) {
            _deviceSecretCache = retry;
            return retry;
          }
        }
      } on Exception {
        // Still stuck — fall through to fail closed.
      }
      throw const DeviceKeyException('Device key unavailable.');
    }

    // Fresh situation (no vault, or keyring alive but empty): mint a new
    // secret. Prefer the keyring; if its write hangs or is refused, keep
    // the secret in the locked drawer instead of freezing the app.
    final encoded = base64Encode(_osRandom32());
    try {
      await _secure
          .write(key: _deviceKey, value: encoded)
          .timeout(_keyringTimeout);
      _deviceSecretCache = encoded;
      return encoded;
    } on Exception {
      lastDeviceSecretFromDrawer = true;
      try {
        final stored = await _writeDrawerSecret(encoded);
        _deviceSecretCache = stored;
        return stored;
      } on Exception {
        throw const DeviceKeyException('Device key unavailable.');
      }
    }
  }

  /// Desktop path: the locked drawer is the primary home. The keyring is
  /// touched exactly once in the wallet's life — to migrate a pre-existing
  /// vault's key out of it — never on the wallet-creation hot path.
  static Future<String> _viaDrawer() async {
    // Drawer first: instant, nothing native involved.
    String? drawer;
    try {
      drawer = await _readDrawerSecret();
    } on Exception {
      drawer = null;
    }
    if (drawer != null) {
      _deviceSecretCache = drawer;
      lastDeviceSecretFromDrawer = true;
      return drawer;
    }

    // No drawer yet. If an older vault exists, its device key may still
    // live in the platform keyring — migrate it ONCE, then never come back.
    if (await vaultExists()) {
      String? migrated;
      try {
        migrated = await _secure.read(key: _deviceKey).timeout(_keyringTimeout);
      } on Exception {
        migrated = null;
      }
      if (migrated != null && migrated.isNotEmpty) {
        var valid = false;
        try {
          valid = base64Decode(migrated).length == 32;
        } on FormatException {
          valid = false;
        }
        if (valid) {
          try {
            final stored = await _writeDrawerSecret(migrated);
            _deviceSecretCache = stored;
            lastDeviceSecretFromDrawer = true;
            return stored;
          } on Exception {
            // Drawer unwritable: keep the keyring-backed value rather than
            // failing — the session still works (memoized, one keyring hit).
            _deviceSecretCache = migrated;
            return migrated;
          }
        }
      }
      // Keyring stuck or unreadable while a vault depends on it: ONE retry,
      // then fail closed. Minting a replacement here would orphan the vault.
      try {
        final retry = await _secure
            .read(key: _deviceKey)
            .timeout(_keyringTimeout);
        if (retry != null && retry.isNotEmpty) {
          var valid = false;
          try {
            valid = base64Decode(retry).length == 32;
          } on FormatException {
            valid = false;
          }
          if (valid) {
            try {
              final stored = await _writeDrawerSecret(retry);
              _deviceSecretCache = stored;
              lastDeviceSecretFromDrawer = true;
              return stored;
            } on Exception {
              _deviceSecretCache = retry;
              return retry;
            }
          }
        }
      } on Exception {
        // Still stuck — fail closed below.
      }
      throw const DeviceKeyException('Device key unavailable.');
    }

    // Fresh machine, no vault: mint straight into the drawer. The keyring
    // is never asked for anything — wallet creation cannot freeze.
    final encoded = base64Encode(_osRandom32());
    try {
      final stored = await _writeDrawerSecret(encoded);
      _deviceSecretCache = stored;
      lastDeviceSecretFromDrawer = true;
      return stored;
    } on Exception {
      throw const DeviceKeyException('Device key unavailable.');
    }
  }

  /// The locked drawer: same directory as the vault file, owner-only.
  /// Drops the in-memory device-secret memo so the next getter call touches
  /// the keyring/drawer again. Used by erase flows and by tests that need a
  /// cold start (the memo is process-wide).
  static void resetDeviceSecretMemo() {
    _deviceSecretCache = null;
    lastDeviceSecretFromDrawer = false;
  }

  static Future<File> _drawerFile() async {
    final dir = await getApplicationSupportDirectory();
    final file = File('${dir.path}/device_secret_v2.drawer');
    // 0600, best effort (older Dart SDKs have no File.setPermissions — a
    // POSIX chmod via the system tool keeps behaviour without breaking the
    // build). Never fail the whole flow over a chmod.
    if (Platform.isLinux || Platform.isMacOS) {
      try {
        await Process.run('/bin/chmod', ['600', file.path]);
      } catch (_) {}
    }
    return file;
  }

  static Future<String?> _readDrawerSecret() async {
    final file = await _drawerFile();
    if (!await file.exists()) return null;
    final text = (await file.readAsString()).trim();
    try {
      if (base64Decode(text).length != 32) return null;
    } on FormatException {
      return null;
    }
    return text;
  }

  static Future<String> _writeDrawerSecret(String encoded) async {
    final file = await _drawerFile();
    await file.writeAsString(encoded, flush: true);
    return encoded;
  }

  /// 32 bytes from the OS CSPRNG. Never time-based, never reused.
  static Uint8List _osRandom32() {
    final random = math.Random.secure();
    return Uint8List.fromList(
      List<int>.generate(32, (_) => random.nextInt(256)),
    );
  }

  static Future<void> clearDeviceSecret() => _secure.delete(key: _deviceKey);

  static Future<bool> deviceKeyExists() async {
    try {
      final v = await _secure.read(key: _deviceKey);
      return v != null && v.isNotEmpty;
    } on Exception {
      return false;
    }
  }

  // ---- failed-unlock backoff ----

  static Future<void> setBackoffState(int count, int untilEpochMs) =>
      _secure.write(key: _backoffKey, value: '$count:$untilEpochMs');
  static Future<(int, int)?> getBackoffState() async {
    final raw = await _secure.read(key: _backoffKey);
    if (raw == null) return null;
    final parts = raw.split(':');
    if (parts.length != 2) return null;
    final count = int.tryParse(parts[0]);
    final until = int.tryParse(parts[1]);
    if (count == null || until == null) return null;
    return (count, until);
  }

  static Future<void> clearBackoffState() => _secure.delete(key: _backoffKey);

  // ---- auto-lock + privacy preferences ----

  static int get autoLockSeconds => prefs.getInt('auto_lock_seconds') ?? 60;
  static Future<void> setAutoLockSeconds(int seconds) =>
      prefs.setInt('auto_lock_seconds', seconds);

  static bool get torEnabled => prefs.getBool('tor_enabled') ?? false;
  static Future<void> setTorEnabled(bool value) =>
      prefs.setBool('tor_enabled', value);
  static String get torHost => prefs.getString('tor_host') ?? '127.0.0.1';
  static Future<void> setTorHost(String value) =>
      prefs.setString('tor_host', value);
  static int get torPort => prefs.getInt('tor_port') ?? 9050;
  static Future<void> setTorPort(int value) => prefs.setInt('tor_port', value);

  /// "Use only my node" (§10d strict mode): the wallet talks to the selected
  /// door ONLY — no built-in fallbacks, no other candidate, nothing else.
  static bool get strictNode => prefs.getBool('strict_node') ?? false;
  static Future<void> setStrictNode(bool value) =>
      prefs.setBool('strict_node', value);

  /// §10f Wallet mode: 0=hot (normal), 1=cold (offline signer), 2=online (watch-only companion).
  static int get walletModeIndex => prefs.getInt('wallet_mode') ?? 0;
  static Future<void> setWalletMode(int value) =>
      prefs.setInt('wallet_mode', value);

  /// URLs whose one-time "what a node sees" warning was already accepted.
  static List<String> get nodeWarnedUrls {
    final raw = prefs.getString('node_warned') ?? '';
    if (raw.isEmpty) return const [];
    try {
      return [for (final v in (jsonDecode(raw) as List)) v.toString()];
    } catch (_) {
      return const [];
    }
  }

  static Future<void> setNodeWarnedUrls(List<String> urls) =>
      prefs.setString('node_warned', jsonEncode(urls));

  // ---- trusted token-signing-list sources (§10e) ----

  /// The user's OWN trusted links (add/remove/reorder), kept separate from
  /// the shipped defaults so an update can never overwrite what the user
  /// decided to trust.
  static List<Map<String, String>> get userTokenSources {
    final raw = prefs.getString('token_user_sources') ?? '';
    if (raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List;
      return [
        for (final e in list)
          if (e is Map<String, dynamic>)
            {'name': '${e['name'] ?? ''}', 'url': '${e['url'] ?? ''}'},
      ];
    } catch (_) {
      return const [];
    }
  }

  static Future<void> setUserTokenSources(List<Map<String, String>> links) =>
      prefs.setString(
        'token_user_sources',
        jsonEncode([for (final l in links) l]),
      );

  /// One-time notice about what the source list is (and is not).
  static bool get tokenSourcesNoticeSeen =>
      prefs.getBool('token_sources_notice') ?? false;

  static Future<void> setTokenSourcesNoticeSeen() =>
      prefs.setBool('token_sources_notice', true);
}

/// The platform secure store could not serve its key. Never silently weakens.
class DeviceKeyException implements Exception {
  const DeviceKeyException(this.message);
  final String message;

  @override
  String toString() => message;
}

const String _deviceKey = 'device_secret_v2';
const String _backoffKey = 'app_lock_backoff';
