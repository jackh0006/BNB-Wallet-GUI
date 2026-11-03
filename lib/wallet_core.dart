import 'dart:math';
import 'dart:typed_data';

import 'package:bip32_plus/bip32_plus.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart';
import 'package:wallet/wallet.dart';
import 'package:collection/collection.dart';
import 'package:rlp/rlp.dart';
import 'package:web3dart/web3dart.dart';
import 'cold_wallet.dart';

/// Custom RLP Address subclass to ensure correct RLP encoding of 20-byte addresses.
/// The rlp package's Address class is used for correct RLP encoding (0x94 prefix).
/// Note: Address constructor expects Uint8List (20 bytes), not String.
class _RlpAddress extends Address {
  _RlpAddress(String hex) : super(hexToBytes(hex.startsWith('0x') ? hex : '0x\$hex'));
}

/// Pure wallet helpers for the BNB Wallet GUI.
///
/// Everything here is deterministic and has no network access. Secrets are
/// returned as [EthPrivateKey] objects; callers must never log them.
class WalletCore {
  WalletCore._();

  static const String zeroAddress =
      '0x0000000000000000000000000000000000000000';
  static const String defaultPath = "m/44'/60'/0'/0/0";

  /// Popular derivation paths, each listed exactly once. Most EVM wallets
  /// (MetaMask, Trust Wallet, SafePal, Ledger Live, Trezor) use the same first
  /// account path; the dialog explains that instead of repeating the path
  /// under every brand name. Account indexes are generated separately.
  static const Map<String, String> standardPaths = {
    'Standard EVM': "m/44'/60'/0'/0/0",
    'Ledger Legacy (MEW)': "m/44'/60'/0'/0",
    'Custom': '',
  };

  /// Builds the standard BIP-44 path for an account index (0 = first account).
  static String standardPathForAccount(int index) {
    if (index < 0) throw ArgumentError('Account index cannot be negative.');
    return "m/44'/60'/$index'/0/0";
  }

  /// Generates a BIP-39 mnemonic using a secure random source.
  /// [wordCount] can be 12 or 24 (BIP-39 standard).
  static String generateMnemonic({int wordCount = 24}) {
    if (wordCount != 12 && wordCount != 24) {
      throw ArgumentError('BIP-39 supports only 12 or 24 words.');
    }
    final mnemonic = Mnemonic.generate(
      Language.english,
      length: wordCount == 12 ? MnemonicLength.words12 : MnemonicLength.words24,
    );
    return mnemonic.sentence;
  }

  /// Generates a brand-new secp256k1 private key using a secure RNG.
  ///
  /// A raw private key has no checksum or recovery phrase. The caller must
  /// show it exactly once and require the user to back it up offline.
  static EthPrivateKey generatePrivateKey() {
    return EthPrivateKey.createRandom(Random.secure());
  }

  /// Validates a BIP-39 mnemonic. Returns true when the checksum is valid.
  static bool validateMnemonic(String phrase) {
    try {
      Mnemonic.fromSentence(phrase.trim(), Language.english);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Derives the private key for [path] (default BIP-44 Ethereum path).
  static EthPrivateKey derivePrivateKey({
    required String phrase,
    String passphrase = '',
    String path = defaultPath,
  }) {
    final mnemonic = Mnemonic.fromSentence(
      phrase.trim(),
      Language.english,
      passphrase: passphrase,
    );
    final seed = Uint8List.fromList(mnemonic.seed);
    final root = BIP32.fromSeed(seed);
    final child = root.derivePath(path);
    final key = child.privateKey;
    if (key == null) {
      throw ArgumentError('Could not derive a private key from that path.');
    }
    return EthPrivateKey(key);
  }

  /// Creates a private key from a 0x-prefixed 64-hex string.
  static EthPrivateKey privateKeyFromHex(String hex) {
    final cleaned = hex.trim();
    if (!cleaned.startsWith('0x') && !cleaned.startsWith('0X')) {
      throw ArgumentError('Private key must start with 0x.');
    }
    final body = cleaned.substring(2);
    if (body.length != 64) {
      throw ArgumentError('Private key must be 64 hexadecimal characters.');
    }
    if (!RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(body)) {
      throw ArgumentError('Private key contains invalid characters.');
    }
    return EthPrivateKey.fromHex(cleaned);
  }

  /// Creates a private key from WIF (Wallet Import Format) string.
  static EthPrivateKey privateKeyFromWIF(String wif) {
    final cleaned = wif.trim();
    try {
      final decoded = _decodeBase58Check(cleaned);
      if (decoded.length != 33 && decoded.length != 34) {
        throw ArgumentError('Invalid WIF length');
      }
      if (decoded[0] != 0x80) {
        throw ArgumentError('Invalid WIF version prefix');
      }
      int keyLength = 32;
      if (decoded.length == 34 && decoded[33] == 0x01) {
        keyLength = 32;
      } else if (decoded.length == 33) {
        keyLength = 32;
      } else {
        throw ArgumentError('Invalid WIF format');
      }
      final privateKeyBytes = decoded.sublist(1, 1 + keyLength);
      return EthPrivateKey(Uint8List.fromList(privateKeyBytes));
    } catch (e) {
      throw ArgumentError('Invalid WIF format: $e');
    }
  }

  /// Decodes a base58check encoded string.
  static Uint8List _decodeBase58Check(String input) {
    const alphabet =
        '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
    final alphabetMap = {
      for (var i = 0; i < alphabet.length; i++) alphabet[i]: i,
    };

    int leadingOnes = 0;
    for (final c in input.codeUnits) {
      if (c == '1'.codeUnitAt(0))
        leadingOnes++;
      else
        break;
    }

    BigInt num = BigInt.zero;
    for (final c in input.codeUnits) {
      final char = String.fromCharCode(c);
      final val = alphabetMap[char];
      if (val == null) throw ArgumentError('Invalid base58 character: $char');
      num = num * BigInt.from(58) + BigInt.from(val);
    }

    var bytes = _encodeBigIntAsUnsigned(num);
    bytes = bytes.sublist(bytes.indexWhere((b) => b != 0));
    bytes = Uint8List.fromList(List.filled(leadingOnes, 0) + bytes);

    if (bytes.length < 4) throw ArgumentError('Invalid base58check length');
    final payload = bytes.sublist(0, bytes.length - 4);
    final checksum = bytes.sublist(bytes.length - 4);
    final hash1 = keccak256(payload);
    final hash2 = keccak256(hash1);
    final expectedChecksum = hash2.sublist(0, 4);
    if (!const ListEquality().equals(checksum, expectedChecksum)) {
      throw ArgumentError('Invalid base58check checksum');
    }
    return payload;
  }

  /// EIP-55 checksummed address for a private key.
  static String addressFromPrivateKey(EthPrivateKey key) =>
      key.address.eip55With0x;

  /// 0x-prefixed 64-hex private key.
  static String privateKeyHex(EthPrivateKey key) =>
      bytesToHex(key.privateKey, include0x: true);

  /// WIF (Wallet Import Format) for a private key - compressed.
  static String privateKeyWIF(EthPrivateKey key) {
    return 'WIF encoding not yet implemented. Use hex: ${privateKeyHex(key)}';
  }

  /// EIP-55 checksummed form of any valid 20-byte hex address.
  static String checksumAddress(String input) {
    final body = _strip0x(input.trim());
    if (body.length != 40 || !RegExp(r'^[0-9a-fA-F]{40}$').hasMatch(body)) {
      throw ArgumentError('Invalid EVM address.');
    }
    final lower = body.toLowerCase();
    final hash = keccak256(Uint8List.fromList(lower.codeUnits));
    final hashHex = bytesToHex(hash);
    final out = StringBuffer('0x');
    for (var i = 0; i < lower.length; i++) {
      final c = lower[i];
      if (c.compareTo('a') >= 0 && c.compareTo('f') <= 0) {
        final nibble = int.parse(hashHex[i], radix: 16);
        out.write(nibble >= 8 ? c.toUpperCase() : c);
      } else {
        out.write(c);
      }
    }
    return out.toString();
  }

  /// True when [input] is a syntactically valid 0x EVM address.
  static bool isValidAddress(String input) {
    try {
      final body = _strip0x(input.trim());
      return body.length == 40 && RegExp(r'^[0-9a-fA-F]{40}$').hasMatch(body);
    } catch (_) {
      return false;
    }
  }

  /// True when [input] is the all-zero address.
  static bool isZeroAddress(String input) =>
      _strip0x(input.trim()).toLowerCase() == _strip0x(zeroAddress);

  /// Creates an Ethereum V3 keystore JSON for [key] protected by [password].
  static String createV3Keystore(EthPrivateKey key, String password) {
    final wallet = Wallet.createNew(key, password, Random.secure());
    return wallet.toJson();
  }

  /// Decrypts an Ethereum V3 keystore JSON. Throws on wrong password.
  static EthPrivateKey decryptV3Keystore(String json, String password) {
    final wallet = Wallet.fromJson(json, password);
    return wallet.privateKey;
  }

  /// Strict decimal amount parsing to base units, matching v1 exactly.
  static BigInt parseAmount(String text, int decimals) {
    final value = text.trim();
    if (value.isEmpty) throw ArgumentError('Amount is empty.');
    if (value.startsWith('-') || value.startsWith('+')) {
      throw ArgumentError('Amount must be positive.');
    }
    if (!RegExp(r'^[0-9.]+$').hasMatch(value) || value == '.') {
      throw ArgumentError('Amount contains invalid characters.');
    }
    if (value.split('.').length > 2) {
      throw ArgumentError('Amount has more than one decimal point.');
    }
    final dot = value.indexOf('.');
    final whole = dot == -1 ? value : value.substring(0, dot);
    final frac = dot == -1 ? '' : value.substring(dot + 1);
    if (frac.length > decimals) {
      throw ArgumentError('Amount has too many decimals for this asset.');
    }
    var base = whole.isEmpty ? '0' : whole;
    base += frac;
    for (var i = frac.length; i < decimals; i++) {
      base += '0';
    }
    final trimmed = base.replaceFirst(RegExp(r'^0+'), '');
    final normalized = trimmed.isEmpty ? '0' : trimmed;
    final max =
        '115792089237316195423570985008687907853269984665640564039457584007913129639935';
    if (normalized.length > max.length ||
        (normalized.length == max.length && normalized.compareTo(max) > 0)) {
      throw ArgumentError('Amount overflows the maximum token amount.');
    }
    return BigInt.parse(normalized);
  }

  /// Formats base units as a human-readable decimal string.
  static String formatUnits(BigInt value, int decimals) {
    if (decimals <= 0) return value.toString();
    final negative = value.isNegative;
    final abs = value.abs();
    final text = abs.toString().padLeft(decimals + 1, '0');
    final whole = text.substring(0, text.length - decimals);
    var frac = text.substring(text.length - decimals);
    frac = frac.replaceFirst(RegExp(r'0+$'), '');
    final out = frac.isEmpty ? whole : '$whole.$frac';
    return negative ? '-$out' : out;
  }

  /// Formats wei as BNB/ETH with up to 18 decimals.
  static String formatEther(BigInt wei) => formatUnits(wei, 18);

  /// Short display form: 0x1234…abcd.
  static String shortAddress(String address, [int chars = 6]) {
    if (address.length <= chars * 2 + 2) return address;
    return '${address.substring(0, chars + 2)}…${address.substring(address.length - chars)}';
  }

  /// Address-poisoning hint: a lookalike that shares the first OR last 4 hex
  /// chars with a known address while being a different address. Real "drip"
  /// attacks usually hijack only one of the two — the common case is a
  /// matching suffix — so either side matching is enough to warn.
  static bool sharesAffixes(String known, String candidate) {
    if (!isValidAddress(known) || !isValidAddress(candidate)) return false;
    final a = _strip0x(known).toLowerCase();
    final b = _strip0x(candidate).toLowerCase();
    if (a == b) return false;
    return a.substring(0, 4) == b.substring(0, 4) ||
        a.substring(36) == b.substring(36);
  }

  static String _strip0x(String value) =>
      value.startsWith('0x') || value.startsWith('0X')
      ? value.substring(2)
      : value;

  /// Encodes a non-negative BigInt as big-endian unsigned bytes.
  static Uint8List _encodeBigIntAsUnsigned(BigInt value) {
    if (value.isNegative) {
      throw ArgumentError('Value must be non-negative');
    }
    if (value == BigInt.zero) return Uint8List.fromList([0]);
    final bytes = <int>[];
    var v = value;
    while (v > BigInt.zero) {
      bytes.insert(0, (v & BigInt.from(0xFF)).toInt());
      v >>= 8;
    }
    return Uint8List.fromList(bytes);
  }

  // ============================================================
  // R5: Cold Wallet Mode (§10f) — pure offline crypto functions
  // ============================================================

  /// Derives the extended public key (xpub) for the account level
  /// `m/44'/60'/0'` from a mnemonic. This can be shared with the online
  /// companion to derive addresses, but WARNING: anyone with the xpub can
  /// link ALL future addresses of this account. Default pairing uses
  /// address list instead (see [deriveAddressList]).
  static String deriveXpub({required String phrase, String passphrase = ''}) {
    final mnemonic = Mnemonic.fromSentence(
      phrase.trim(),
      Language.english,
      passphrase: passphrase,
    );
    final seed = Uint8List.fromList(mnemonic.seed);
    final root = BIP32.fromSeed(seed);
    // Account level: m/44'/60'/0'
    final account = root.derivePath("m/44'/60'/0'");
    final xpub = account.neutered().toBase58();
    return xpub;
  }

  /// Derives a list of addresses from the seed, starting at index 0.
  /// Used for the default cold pairing (address list, not xpub).
  static List<String> deriveAddressList({
    required String phrase,
    String passphrase = '',
    int count = 20,
    int startIndex = 0,
  }) {
    final mnemonic = Mnemonic.fromSentence(
      phrase.trim(),
      Language.english,
      passphrase: passphrase,
    );
    final seed = Uint8List.fromList(mnemonic.seed);
    final root = BIP32.fromSeed(seed);
    final account = root.derivePath("m/44'/60'/0'");
    final addresses = <String>[];
    for (var i = startIndex; i < startIndex + count; i++) {
      final child = account.derivePath("0/$i");
      final key = child.privateKey;
      if (key != null) {
        final pk = EthPrivateKey(key);
        addresses.add(pk.address.eip55With0x);
      }
    }
    return addresses;
  }

  /// Derives addresses for a custom derivation path.
  /// Returns list of addresses for the given path pattern.
  static List<String> deriveAddressesCustomPath({
    required String phrase,
    String passphrase = '',
    required String pathPattern,
    int count = 20,
    int startIndex = 0,
  }) {
    final mnemonic = Mnemonic.fromSentence(
      phrase.trim(),
      Language.english,
      passphrase: passphrase,
    );
    final seed = Uint8List.fromList(mnemonic.seed);
    final root = BIP32.fromSeed(seed);
    final account = root.derivePath(pathPattern);
    final addresses = <String>[];
    for (var i = startIndex; i < startIndex + count; i++) {
      final child = account.derivePath("$i");
      final key = child.privateKey;
      if (key != null) {
        final pk = EthPrivateKey(key);
        addresses.add(pk.address.eip55With0x);
      }
    }
    return addresses;
  }

  /// Computes the cold pairing fingerprint: first 4 bytes of keccak256
  /// of the first address (lowercase, no 0x), returned as 8 hex chars
  /// plus 4 shape codes for visual verification.
  static String computeFingerprint(String firstAddress) {
    final body = _strip0x(firstAddress).toLowerCase();
    final hash = keccak256(Uint8List.fromList(body.codeUnits));
    final first4 = hash.take(4).toList();
    final hex = bytesToHex(Uint8List.fromList(first4));
    final shapes = first4.map((b) => _shapeForByte(b)).join(' ');
    return '$hex $shapes';
  }

  static String _shapeForByte(int byte) {
    const shapes = ['●', '■', '▲', '◆'];
    return shapes[byte % shapes.length];
  }

  /// Parses and decodes a ColdTxRequest on the cold device.
  /// Returns a human-readable summary and validates the transaction.
  /// Throws if the transaction cannot be decoded or is invalid.
  static ColdTxDecodeResult decodeTxRequest({
    required ColdTxRequest request,
    required List<String> coldAddresses,
    required Map<String, ColdTxAssetInfo> knownTokens,
    bool allowUnknownData = false,
  }) {
    if (request.chainId != 56 && request.chainId != 97) {
      throw ArgumentError('Unsupported chainId: ${request.chainId}');
    }

    final fromLower = request.from.toLowerCase();
    if (!coldAddresses.any((a) => a.toLowerCase() == fromLower)) {
      throw ArgumentError('From address does not belong to this cold wallet');
    }

    String? functionName;
    String? decodedTo;
    BigInt? decodedValue;
    String? warning;

    final data = _strip0x(request.data);
    if (data.isNotEmpty) {
      if (data.startsWith('a9059cbb')) {
        functionName = 'transfer';
        try {
          final toHex = '0x${data.substring(8, 72)}';
          decodedTo = checksumAddress(toHex);
          final valueHex = data.substring(72, 136);
          decodedValue = BigInt.parse(valueHex, radix: 16);
        } catch (_) {
          warning = 'Could not decode transfer calldata';
        }
      } else if (data.startsWith('095ea7b3')) {
        functionName = 'approve';
        warning =
            'This is an APPROVE transaction — unlimited approvals are risky';
      } else if (!allowUnknownData) {
        throw ArgumentError(
          'Unknown calldata (function 0x${data.substring(0, 8)}). '
          'Enable "Advanced: sign unknown data" in settings to proceed.',
        );
      }
    }

    ColdTxAssetInfo assetInfo = request.assetInfo;
    if (!request.assetInfo.isNative &&
        request.assetInfo.contractAddress != null) {
      final addr = request.assetInfo.contractAddress!.toLowerCase();
      if (knownTokens.containsKey(addr)) {
        assetInfo = knownTokens[addr]!;
      } else {
        assetInfo = ColdTxAssetInfo(
          isNative: false,
          contractAddress: request.assetInfo.contractAddress,
          isUnknown: true,
          warning:
              'Token not recognized on this device. Verify contract address.',
        );
      }
    }

    if (functionName == 'approve' && decodedValue != null) {
      final maxUint256 = BigInt.from(2).pow(256) - BigInt.one;
      if (decodedValue == maxUint256) {
        warning =
            (warning != null ? '$warning; ' : '') +
            'UNLIMITED approval — token can spend all your balance';
      }
    }

    final maxFee = BigInt.parse(_strip0x(request.maxFeePerGas));
    final gasLimit = BigInt.parse(_strip0x(request.gasLimit));
    final totalPossibleFee = maxFee * gasLimit;

    return ColdTxDecodeResult(
      chainId: request.chainId,
      from: request.from,
      to: request.to,
      value: BigInt.parse(_strip0x(request.value)),
      gasLimit: gasLimit,
      maxFeePerGas: maxFee,
      maxPriorityFeePerGas: BigInt.parse(
        _strip0x(request.maxPriorityFeePerGas),
      ),
      nonce: request.nonce,
      data: request.data,
      functionName: functionName,
      decodedTo: decodedTo,
      decodedValue: decodedValue,
      assetInfo: assetInfo,
      totalPossibleFee: totalPossibleFee,
      expiresAt: DateTime.parse(request.expiresAt),
      warning: warning,
    );
  }

  /// Signs a transaction on the cold device.
  /// Returns the signature components (r, s, v) and the signed transaction hash.
  /// Uses EIP-1559 transaction format with proper RLP encoding.
  static ColdTxSignature signTransaction({
    required String phrase,
    required ColdTxRequest request,
    String passphrase = '',
    String path = defaultPath,
  }) {
    final privateKey = derivePrivateKey(
      phrase: phrase,
      passphrase: passphrase,
      path: path,
    );

    final tx = Transaction(
      from: EthereumAddress.fromHex(request.from),
      to: EthereumAddress.fromHex(request.to),
      value: EtherAmount.inWei(BigInt.parse(_strip0x(request.value), radix: 16)),
      nonce: request.nonce,
      maxGas: int.parse(_strip0x(request.gasLimit), radix: 16),
      maxFeePerGas: EtherAmount.inWei(
        BigInt.parse(_strip0x(request.maxFeePerGas), radix: 16),
      ),
      maxPriorityFeePerGas: EtherAmount.inWei(
        BigInt.parse(_strip0x(request.maxPriorityFeePerGas), radix: 16),
      ),
      data: hexToBytes(_strip0x(request.data)),
    );

    // Build the transaction payload for signing (EIP-1559: 0x02 || rlp([...]))
    final txPayload = _buildTransactionPayload(tx, request.chainId);
    final signature = privateKey.signToEcSignature(
      txPayload,
      chainId: request.chainId,
      isEIP1559: true,
    );

    // Build the signed transaction RLP
    // EIP-1559: 0x02 || rlp([chainId, nonce, maxPriorityFeePerGas, maxFeePerGas, gasLimit, to, value, data, accessList, yParity, r, s])
    // yParity is 0 or 1 (the low bit of v for EIP-1559)
    final yParity = signature.v & 1;
    final toBytes = tx.to != null ? hexToBytes(_strip0x(tx.to!.eip55With0x)) : <int>[];
    final rlpList = [
      request.chainId,
      tx.nonce ?? 0,
      tx.maxPriorityFeePerGas?.getInWei ?? BigInt.zero,
      tx.maxFeePerGas?.getInWei ?? BigInt.zero,
      tx.maxGas ?? 0,
      toBytes,
      tx.value?.getInWei ?? BigInt.zero,
      tx.data ?? <int>[],
      <int>[], // access list
      yParity,
      signature.r,
      signature.s,
    ];

    final rawTxBytes = Rlp.encode(rlpList);
    final rawBytes = Uint8List.fromList([0x02] + rawTxBytes);
    final rawHex = bytesToHex(rawBytes, include0x: true, padToEvenLength: true);
    final hash = bytesToHex(keccak256(rawBytes), include0x: true);

    // For EIP-1559, store the full recovery ID (0-3) from signToEcSignature
    // This is needed for correct signature verification
    final v = signature.v;

    return ColdTxSignature(
      version: 1,
      requestId: request.id ?? '',
      chainId: request.chainId,
      from: privateKey.address.eip55With0x,
      r: '0x${signature.r.toRadixString(16).padLeft(64, '0')}',
      s: '0x${signature.s.toRadixString(16).padLeft(64, '0')}',
      v: '0x${v.toRadixString(16)}',
      signedTxHash: hash,
      signedAt: DateTime.now().toUtc().toIso8601String(),
      rawSignedTx: rawHex,
    );
  }

  /// Verifies a cold signature on the online device.
  /// Returns true if the signature is valid and matches the expected from address.
  static bool verifyColdSignature({
    required ColdTxRequest request,
    required ColdTxSignature signature,
    required String expectedFrom,
  }) {
    if (signature.requestId != request.id) return false;
    if (signature.chainId != request.chainId) return false;

    try {
      final tx = Transaction(
        from: EthereumAddress.fromHex(request.from),
        to: EthereumAddress.fromHex(request.to),
        value: EtherAmount.inWei(BigInt.parse(_strip0x(request.value), radix: 16)),
        nonce: request.nonce,
        maxGas: int.parse(_strip0x(request.gasLimit), radix: 16),
        maxFeePerGas: EtherAmount.inWei(
          BigInt.parse(_strip0x(request.maxFeePerGas), radix: 16),
        ),
        maxPriorityFeePerGas: EtherAmount.inWei(
          BigInt.parse(_strip0x(request.maxPriorityFeePerGas), radix: 16),
        ),
        data: hexToBytes(_strip0x(request.data)),
      );

      final recovered = _recoverSigner(tx, signature, expectedFrom: expectedFrom);
      final recoveredAddr = recovered.eip55With0x;

      if (recoveredAddr.toLowerCase() != expectedFrom.toLowerCase()) {
        return false;
      }

      return true;
    } catch (_) {
      return false;
    }
  }

  static EthereumAddress _recoverSigner(Transaction tx, ColdTxSignature sig, {String? expectedFrom}) {
    // Recover the signer address from the signature
    // Build the signing payload (same as used for signing)
    final txPayload = _encodeTransactionForSigning(tx, sig.chainId);
    
    // Parse signature components (hex strings with 0x prefix)
    final r = BigInt.parse(_strip0x(sig.r), radix: 16);
    final s = BigInt.parse(_strip0x(sig.s), radix: 16);
    // The v in ColdTxSignature is the full recovery ID (0-3) from signToEcSignature
    final recoveryId = int.parse(_strip0x(sig.v), radix: 16);
    
    // Use the full recovery ID from the signature for ecRecover
    final msgSig = MsgSignature(r, s, 27 + recoveryId);
    try {
      final recoveredPubKey = ecRecover(txPayload, msgSig);
      final addr = EthereumAddress(publicKeyToAddress(recoveredPubKey));
      if (expectedFrom != null && addr.eip55With0x.toLowerCase() == expectedFrom.toLowerCase()) {
        return addr;
      }
      // If no expectedFrom provided, return the recovered address
      return addr;
    } catch (e) {
      throw Exception('Could not recover address: $e');
    }
  }

  /// Builds the transaction payload for signing (EIP-1559).
  /// Returns the raw payload: 0x02 || rlp([chainId, nonce, maxPriorityFeePerGas,
  // maxFeePerGas, gasLimit, to, value, data, accessList])
  static Uint8List _buildTransactionPayload(Transaction tx, int chainId) {
    // Manually construct RLP encoding to avoid Address class issues
    // The 'to' address must be encoded as 0x94 + 20 bytes
    final toBytes = tx.to != null ? hexToBytes(_strip0x(tx.to!.eip55With0x)) : List<int>.filled(20, 0);
    final addressRlp = Uint8List.fromList([0x94] + toBytes);
    
    // Encode each field using Rlp.encode and strip list prefixes
    final items = <Uint8List>[];
    
    // chainId
    items.add(_stripListPrefix(Rlp.encode([chainId])));
    // nonce
    items.add(_stripListPrefix(Rlp.encode([tx.nonce ?? 0])));
    // maxPriorityFeePerGas
    items.add(_stripListPrefix(Rlp.encode([tx.maxPriorityFeePerGas?.getInWei ?? BigInt.zero])));
    // maxFeePerGas
    items.add(_stripListPrefix(Rlp.encode([tx.maxFeePerGas?.getInWei ?? BigInt.zero])));
    // gasLimit
    items.add(_stripListPrefix(Rlp.encode([tx.maxGas ?? 0])));
    // to address (manually encoded with 0x94 prefix)
    items.add(Uint8List.fromList([0x94] + toBytes));
    // value
    items.add(_stripListPrefix(Rlp.encode([tx.value?.getInWei ?? BigInt.zero])));
    // data
    items.add(_stripListPrefix(Rlp.encode([tx.data ?? <int>[]])));
    // access list
    items.add(_stripListPrefix(Rlp.encode([<int>[]])));
    
    // Concatenate all items
    final concatenated = BytesBuilder();
    for (final item in items) {
      concatenated.add(item);
    }
    final concatenatedBytes = concatenated.toBytes();
    
    // Add list prefix
    final listPrefix = _encodeLength(concatenatedBytes.length, 0xc0);
    final fullRlp = Uint8List.fromList(listPrefix + concatenatedBytes);
    return Uint8List.fromList([0x02] + fullRlp);
  }

  /// Encodes a transaction for signing (EIP-1559).
  /// Returns the keccak256 hash of the RLP-encoded unsigned transaction.
  static Uint8List _encodeTransactionForSigning(Transaction tx, int chainId) {
    final payload = _buildTransactionPayload(tx, chainId);
    return keccak256(payload);
  }

  /// Strips the RLP list prefix from an encoded item, returning just the item's data.
  static Uint8List _stripListPrefix(Uint8List encoded) {
    if (encoded.isEmpty) return Uint8List.fromList([]);
    
    final firstByte = encoded[0];
    if (firstByte < 0xc0) {
      return encoded;
    } else if (firstByte <= 0xf7) {
      final length = firstByte - 0xc0;
      return encoded.sublist(1, 1 + length);
    } else {
      final lengthOfLength = firstByte - 0xf7;
      var length = 0;
      for (int i = 0; i < lengthOfLength; i++) {
        length = (length << 8) | encoded[1 + i];
      }
      final valueStart = 1 + (firstByte - 0xf7);
      return encoded.sublist(1 + (firstByte - 0xf7), 1 + (firstByte - 0xf7) + length);
    }
  }

  /// Encodes an RLP length prefix.
  static Uint8List _encodeLength(int length, int offset) {
    if (length <= 55) {
      return Uint8List.fromList([offset + length]);
    } else {
      var x = Uint32List(1);
      x[0] = length;
      var y = Uint8List.view(x.buffer);
      var num = 3;
      while (y[num] == 0) {
        --num;
      }
      var e = Uint8List(num + 2);
      e[0] = 0x80 + num + 1;
      for (var i = 1; i < e.length; ++i) {
        e[i] = y[num--];
      }
      return e;
    }
  }

  static String formatFee(BigInt feeWei) => formatEther(feeWei);
}

/// One place that decides what may NEVER reach the system clipboard — the
/// second line of defense behind "no code path copies secrets at all".
class ClipboardGuard {
  const ClipboardGuard._();

  static bool secretFree(String text) {
    final t = text.trim();
    if (t.isEmpty) return false;
    if (_looksLikeMnemonic(t)) return false;
    if (RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(t)) return false;
    return true;
  }

  static bool _looksLikeMnemonic(String text) {
    final words = text.toLowerCase().split(RegExp(r'\s+'));
    const lengths = <int>{12, 15, 18, 21, 24};
    if (!lengths.contains(words.length)) return false;
    final alpha = RegExp(r'^[a-z]{3,12}$');
    return words.every(alpha.hasMatch);
  }
}
