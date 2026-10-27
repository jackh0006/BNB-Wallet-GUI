import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'models.dart';

/// Result of looking for the Tor daemon and its pluggable transports.
class TorProbe {
  const TorProbe({
    required this.torPath,
    required this.torVersion,
    required this.transportPaths,
  });

  final String? torPath;
  final String? torVersion;
  final Map<TorBridgeType, String> transportPaths;

  bool get torAvailable => torPath != null;

  String? binaryFor(TorBridgeType type) => transportPaths[type];

  /// Human-readable state for every bridge family, including the ones Ubuntu
  /// does not package. The UI uses this to explain exactly what is missing.
  Map<TorBridgeType, String> get availability {
    return {
      TorBridgeType.none: torAvailable ? 'Tor daemon found' : 'tor missing',
      for (final type in const [
        TorBridgeType.obfs4,
        TorBridgeType.snowflake,
        TorBridgeType.webtunnel,
        TorBridgeType.meek,
        TorBridgeType.custom,
      ])
        type: type == TorBridgeType.custom
            ? 'Your own bridge/plugin lines'
            : (binaryFor(type) == null
                  ? '${type.binaryName} missing'
                  : binaryFor(type)!),
    };
  }
}

class TorStartException implements Exception {
  const TorStartException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Owns the optional `tor` child process started by this app. It never touches
/// a Tor daemon the user started elsewhere: only the PID captured at spawn is
/// ever signalled, and only that process's temporary config/data directory is
/// removed.
class TorManager extends ChangeNotifier {
  TorManager._();

  static final TorManager instance = TorManager._();

  Process? _process;
  Directory? _directory;
  StreamSubscription<String>? _stdout;
  StreamSubscription<String>? _stderr;
  Completer<void>? _bootstrap;
  Completer<int>? _exited;
  TorProbe? _probeCache;
  bool _starting = false;
  bool _ready = false;
  bool _intentionalStop = false;
  int _bootstrapPercent = 0;
  String? _lastError;
  final List<String> _logTail = [];

  bool get starting => _starting;
  bool get running => _process != null;
  bool get ready => _ready;
  int get bootstrapPercent => _bootstrapPercent;
  int? get pid => _process?.pid;
  String? get lastError => _lastError;
  List<String> get logTail => List.unmodifiable(_logTail);

  bool get supported => Platform.isLinux;

  String get statusText {
    if (_starting) {
      return 'Starting Tor${_bootstrapPercent > 0 ? ' — $_bootstrapPercent%' : ''}…';
    }
    if (_process != null && _ready) return 'Managed Tor is running (pid $pid).';
    if (_process != null) return 'Tor is running but has not bootstrapped yet.';
    return 'Managed Tor is stopped.';
  }

  /// Finds `tor` and the transport clients. PATH is scanned without a shell.
  Future<TorProbe> probe({bool refresh = false}) async {
    if (!refresh && _probeCache != null) return _probeCache!;
    final tor = await _findExecutable('tor');
    String? version;
    if (tor != null) {
      try {
        final result = await Process.run(tor, const [
          '--version',
        ]).timeout(const Duration(seconds: 4));
        final first = '${result.stdout}'.split('\n').first.trim();
        if (first.isNotEmpty) version = first;
      } catch (_) {
        // Existence is enough to try; the daemon may still refuse to run.
      }
    }
    final transports = <TorBridgeType, String>{};
    for (final type in const [
      TorBridgeType.obfs4,
      TorBridgeType.snowflake,
      TorBridgeType.webtunnel,
      TorBridgeType.meek,
    ]) {
      final path = await _findExecutable(type.binaryName);
      if (path != null) transports[type] = path;
    }
    final probe = TorProbe(
      torPath: tor,
      torVersion: version,
      transportPaths: transports,
    );
    _probeCache = probe;
    return probe;
  }

  /// Starts a private Tor daemon on 127.0.0.1:[port] and waits for 100%
  /// bootstrap. Throws with a readable reason if the daemon cannot start.
  Future<void> start({
    required int port,
    required TorBridgeType bridgeType,
    required List<String> bridgeLines,
  }) async {
    if (!supported) {
      throw const TorStartException(
        'Managed Tor is only available on Linux. On Android use Orbot in '
        'SOCKS mode; on other systems start Tor yourself and use the '
        'external SOCKS settings.',
      );
    }
    if (port <= 0 || port > 65535) {
      throw const TorStartException('Tor SOCKS port must be 1–65535.');
    }
    if (_starting) {
      throw const TorStartException('Tor is already starting.');
    }
    if (_process != null) await stop();

    _starting = true;
    _ready = false;
    _bootstrapPercent = 0;
    _lastError = null;
    _logTail.clear();
    notifyListeners();

    Directory? directory;
    try {
      final probe = await this.probe(refresh: true);
      if (probe.torPath == null) {
        throw const TorStartException(
          'The tor package is not installed. On Ubuntu/Debian run: '
          'sudo apt install tor',
        );
      }
      String? transportPath;
      if (bridgeType != TorBridgeType.none) {
        final normalized = normalizeBridgeLines(bridgeType, bridgeLines);
        if (bridgeType != TorBridgeType.custom) {
          transportPath = probe.binaryFor(bridgeType);
          if (transportPath == null) {
            throw TorStartException(
              '${bridgeType.label} needs ${bridgeType.binaryName}, which is '
              'not installed. On Ubuntu/Debian try: sudo apt install '
              '${_packageFor(bridgeType)}. If your distribution has no '
              'package, use a Custom bridge and point to the client binary '
              'yourself.',
            );
          }
        }
        if (normalized.isEmpty) {
          throw TorStartException(
            '${bridgeType.label} needs at least one bridge line.',
          );
        }
      }

      await _ensurePortFree(port);
      directory = await Directory.systemTemp.createTemp('bnb-wallet-tor-');
      await _chmod(directory.path, '700');
      final data = Directory('${directory.path}/data');
      await data.create();
      await _chmod(data.path, '700');

      final config = buildTorrc(
        port: port,
        dataDirectory: data.path,
        bridgeType: bridgeType,
        bridgeLines: bridgeLines,
        transportBinary: transportPath,
      );
      final configFile = File('${directory.path}/torrc');
      await configFile.writeAsString(config, flush: true);
      await _chmod(configFile.path, '600');

      final process = await Process.start(probe.torPath!, [
        '-f',
        configFile.path,
      ], runInShell: false);
      _process = process;
      _directory = directory;
      _intentionalStop = false;
      _bootstrap = Completer<void>();
      _exited = Completer<int>();

      _stdout = process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(_handleLogLine);
      _stderr = process.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(_handleLogLine);
      unawaited(
        process.exitCode.then((code) {
          _handleExit(code);
        }),
      );

      await _bootstrap!.future.timeout(const Duration(seconds: 90));
      _ready = true;
      _starting = false;
      _bootstrapPercent = 100;
      _lastError = null;
      notifyListeners();
    } catch (error) {
      _starting = false;
      _ready = false;
      _lastError = _friendly(error);
      await _forceStop();
      _directory = null;
      if (directory != null) {
        try {
          await directory.delete(recursive: true);
        } catch (_) {}
      }
      notifyListeners();
      if (error is TorStartException) rethrow;
      throw TorStartException(_lastError!);
    }
  }

  /// Stops ONLY the process this app spawned. Safe to call repeatedly.
  Future<void> stop() async {
    _intentionalStop = true;
    _starting = false;
    final process = _process;
    if (process == null) {
      _ready = false;
      await _removeDirectory();
      notifyListeners();
      return;
    }
    try {
      process.kill(ProcessSignal.sigterm);
    } catch (_) {}
    final exited = _exited?.future;
    if (exited != null) {
      try {
        await exited.timeout(const Duration(seconds: 8));
      } on TimeoutException {
        try {
          process.kill(ProcessSignal.sigkill);
        } catch (_) {}
        try {
          await exited.timeout(const Duration(seconds: 3));
        } catch (_) {}
      }
    }
    _process = null;
    _ready = false;
    _bootstrapPercent = 0;
    await _removeDirectory();
    notifyListeners();
  }

  Future<void> _forceStop() async {
    final process = _process;
    _intentionalStop = true;
    if (process != null) {
      try {
        process.kill(ProcessSignal.sigterm);
      } catch (_) {}
      try {
        await _exited?.future.timeout(const Duration(seconds: 4));
      } catch (_) {
        try {
          process.kill(ProcessSignal.sigkill);
        } catch (_) {}
      }
    }
    _process = null;
    _ready = false;
    await _removeDirectory();
  }

  void _handleLogLine(String line) {
    final text = line
        .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '')
        .trim();
    if (text.isEmpty) return;
    _logTail.add(text);
    if (_logTail.length > 40) _logTail.removeAt(0);

    final match = RegExp(r'Bootstrapped (\d+)%').firstMatch(text);
    if (match != null) {
      final percent = int.tryParse(match.group(1) ?? '') ?? 0;
      if (percent != _bootstrapPercent) {
        _bootstrapPercent = percent;
        notifyListeners();
      }
    }
    if (text.contains('Bootstrapped 100%') ||
        text.contains('Bootstrapped 100 %')) {
      if (!(_bootstrap?.isCompleted ?? true)) _bootstrap!.complete();
    }
    if (text.contains('[err]') || text.contains('[warn]')) {
      _lastError = text;
      notifyListeners();
    }
  }

  void _handleExit(int code) {
    _process = null;
    _ready = false;
    _starting = false;
    if (!_intentionalStop) {
      _lastError =
          'Tor exited with code $code. ${_logTail.isEmpty ? '' : _logTail.last}';
    }
    if (!(_bootstrap?.isCompleted ?? true)) {
      _bootstrap!.completeError(
        TorStartException(
          _lastError ?? 'Tor exited before it finished bootstrapping.',
        ),
      );
    }
    if (!(_exited?.isCompleted ?? true)) _exited!.complete(code);
    unawaited(_removeDirectory());
    notifyListeners();
  }

  Future<void> _removeDirectory() async {
    final directory = _directory;
    _directory = null;
    await _stdout?.cancel();
    await _stderr?.cancel();
    _stdout = null;
    _stderr = null;
    if (directory == null) return;
    try {
      await directory.delete(recursive: true);
    } catch (_) {}
  }

  static Future<void> _ensurePortFree(int port) async {
    try {
      final socket = await ServerSocket.bind(
        InternetAddress.loopbackIPv4,
        port,
      );
      await socket.close();
    } on SocketException {
      throw TorStartException(
        '127.0.0.1:$port is already in use. Stop the other Tor instance or '
        'choose a different SOCKS port.',
      );
    }
  }

  static Future<void> _chmod(String path, String mode) async {
    final result = await Process.run('/bin/chmod', [mode, path]);
    if (result.exitCode != 0) {
      throw TorStartException('Could not secure $path (chmod $mode failed).');
    }
  }

  static String _packageFor(TorBridgeType type) {
    switch (type) {
      case TorBridgeType.obfs4:
        return 'obfs4proxy';
      case TorBridgeType.snowflake:
        return 'snowflake-client';
      case TorBridgeType.webtunnel:
        return 'webtunnel-client';
      case TorBridgeType.meek:
        return 'meek-client';
      case TorBridgeType.none:
      case TorBridgeType.custom:
        return 'tor';
    }
  }

  static String _friendly(Object error) {
    if (error is TorStartException) return error.message;
    if (error is TimeoutException) {
      return 'Tor did not finish bootstrapping within 90 seconds. The bridge '
          'may be blocked or unreachable.';
    }
    if (error is ProcessException) {
      return 'Could not start Tor: ${error.message}';
    }
    return '$error';
  }

  static Future<String?> _findExecutable(String name) async {
    if (name.isEmpty) return null;
    final candidates = <String>[];
    final path = Platform.environment['PATH'] ?? '';
    for (final dir in path.split(':')) {
      if (dir.trim().isNotEmpty) candidates.add('${dir.trim()}/$name');
    }
    for (final dir in const [
      '/usr/bin',
      '/usr/local/bin',
      '/bin',
      '/snap/bin',
    ]) {
      candidates.add('$dir/$name');
    }
    for (final candidate in candidates.toSet()) {
      try {
        final stat = await File(candidate).stat();
        if (stat.type == FileSystemEntityType.file && (stat.mode & 0x49) != 0) {
          return candidate;
        }
      } catch (_) {}
    }
    return null;
  }

  /// Validates and normalizes bridge lines before they are written to torrc.
  ///
  /// Built-in transports return bare lines such as
  /// `obfs4 1.2.3.4:443 FINGERPRINT cert=…`. Custom returns raw
  /// `Bridge …` / `ClientTransportPlugin …` lines. Control characters are
  /// rejected so a pasted newline cannot inject extra torrc directives.
  static List<String> normalizeBridgeLines(
    TorBridgeType type,
    Iterable<String> raw,
  ) {
    final out = <String>[];
    for (final original in raw) {
      var line = original.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      if (line.length > 4096) {
        throw const TorStartException('A bridge line is unreasonably long.');
      }
      if (line.runes.any((rune) => rune < 0x20 || rune == 0x7F)) {
        throw const TorStartException(
          'Bridge lines cannot contain control characters or extra lines.',
        );
      }
      if (type == TorBridgeType.none) {
        throw const TorStartException(
          'Bridge lines are only used when a bridge type is selected.',
        );
      }
      if (type == TorBridgeType.custom) {
        if (line.toLowerCase().startsWith('bridge ')) {
          line = line.substring(7).trim();
        } else if (line.startsWith('ClientTransportPlugin ')) {
          out.add(line);
          continue;
        }
        if (line.isEmpty) continue;
        out.add(line);
        continue;
      }

      if (line.toLowerCase().startsWith('bridge ')) {
        line = line.substring(7).trim();
      }
      if (line.toLowerCase().startsWith('clienttransportplugin ')) {
        throw const TorStartException(
          'Put ClientTransportPlugin lines under Custom, not under a built-in '
          'bridge type.',
        );
      }
      if (!line.toLowerCase().startsWith('${type.name} ')) {
        for (final other in const [
          TorBridgeType.obfs4,
          TorBridgeType.snowflake,
          TorBridgeType.webtunnel,
          TorBridgeType.meek,
        ]) {
          if (other != type &&
              line.toLowerCase().startsWith('${other.name} ')) {
            throw TorStartException(
              'That bridge line belongs to ${other.label}; choose that type '
              'instead.',
            );
          }
        }
        line = '${type.name} $line';
      }
      out.add(line);
    }
    if (out.isEmpty && type != TorBridgeType.none) {
      throw const TorStartException('At least one bridge line is required.');
    }
    if (type == TorBridgeType.custom) {
      final hasBridge = out.any(
        (line) => !line.startsWith('ClientTransportPlugin '),
      );
      if (!hasBridge) {
        throw const TorStartException(
          'Custom mode needs at least one Bridge line in addition to any '
          'ClientTransportPlugin line.',
        );
      }
    }
    return out;
  }

  /// Builds an owner-only torrc. Exposed for tests; contains no secrets.
  static String buildTorrc({
    required int port,
    required String dataDirectory,
    required TorBridgeType bridgeType,
    required List<String> bridgeLines,
    String? transportBinary,
  }) {
    if (port <= 0 || port > 65535) {
      throw const TorStartException('Tor SOCKS port must be 1–65535.');
    }
    if (dataDirectory.trim().isEmpty ||
        dataDirectory.contains('\n') ||
        dataDirectory.contains('\r')) {
      throw const TorStartException('Invalid Tor data directory.');
    }
    final normalized = normalizeBridgeLines(bridgeType, bridgeLines);
    final buffer = StringBuffer()
      ..writeln('SocksPort 127.0.0.1:$port')
      ..writeln('ControlPort 0')
      ..writeln('DataDirectory $dataDirectory')
      ..writeln('Log notice stdout')
      ..writeln('ClientOnly 1')
      ..writeln('AvoidDiskWrites 1')
      ..writeln('SafeLogging 1');
    if (bridgeType != TorBridgeType.none) {
      buffer.writeln('UseBridges 1');
      if (bridgeType != TorBridgeType.custom) {
        if (transportBinary == null || transportBinary.trim().isEmpty) {
          throw const TorStartException(
            'The selected bridge transport binary was not found.',
          );
        }
        buffer.writeln(
          'ClientTransportPlugin ${bridgeType.name} exec $transportBinary',
        );
        for (final line in normalized) {
          buffer.writeln('Bridge $line');
        }
      } else {
        for (final line in normalized) {
          if (line.startsWith('ClientTransportPlugin ')) {
            buffer.writeln(line);
          } else {
            buffer.writeln('Bridge $line');
          }
        }
      }
    }
    return buffer.toString();
  }
}
