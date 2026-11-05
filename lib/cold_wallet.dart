/// Cold Wallet Mode (§10f) — shared types for offline signing.
///
/// This file contains all types needed for the cold wallet flow that must be
/// shared between the cold device (signer) and the online companion.
/// It avoids importing wallet_core.dart to prevent circular dependencies.
library;

import 'package:flutter/foundation.dart';

/// The wallet's operating mode. Default is [WalletMode.hot] (normal hot wallet).
/// [WalletMode.cold] = offline signer (holds seed, no network).
/// [WalletMode.online] = watch-only companion (no secrets, broadcasts for cold).
enum WalletMode { hot, cold, online }

extension WalletModeLabel on WalletMode {
  String get label {
    switch (this) {
      case WalletMode.hot:
        return 'Normal (hot wallet)';
      case WalletMode.cold:
        return 'Cold (offline signer)';
      case WalletMode.online:
        return 'Online (watch-only companion)';
    }
  }

  String get shortLabel {
    switch (this) {
      case WalletMode.hot:
        return 'Hot';
      case WalletMode.cold:
        return 'Cold';
      case WalletMode.online:
        return 'Online';
    }
  }
}

/// Public pairing data exported from a cold device and scanned by the online
/// companion. Contains NO secrets — only public keys/addresses and metadata.
@immutable
class ColdPairingData {
  const ColdPairingData({
    required this.version,
    required this.walletName,
    required this.chainId,
    required this.addresses, // list of derived addresses (default: first 20)
    required this.fingerprint, // 4-byte hash of first address as hex + 4 colored shapes
    required this.exportedAt,
    this.xpub, // optional extended public key (warning: links all future addresses)
    this.includeXpub = false,
  });

  final int version; // protocol version = 1
  final String walletName;
  final int chainId;
  final List<String> addresses;
  final String fingerprint; // 8 hex chars (4 bytes) + 4 shape codes
  final String exportedAt; // ISO timestamp
  final String? xpub;
  final bool includeXpub;

  Map<String, dynamic> toJson() => {
    'version': version,
    'walletName': walletName,
    'chainId': chainId,
    'addresses': addresses,
    'fingerprint': fingerprint,
    'exportedAt': exportedAt,
    if (includeXpub && xpub != null) 'xpub': xpub,
    'includeXpub': includeXpub,
  };

  factory ColdPairingData.fromJson(Map<String, dynamic> json) =>
      ColdPairingData(
        version: (json['version'] as num?)?.toInt() ?? 1,
        walletName: '${json['walletName'] ?? ''}',
        chainId: (json['chainId'] as num?)?.toInt() ?? 56,
        addresses: (json['addresses'] as List?)?.cast<String>() ?? const [],
        fingerprint: '${json['fingerprint'] ?? ''}',
        exportedAt: '${json['exportedAt'] ?? ''}',
        xpub: json['xpub']?.toString(),
        includeXpub: json['includeXpub'] == true,
      );
}

/// A transaction request sent from the online device to the cold device
/// for offline signing. Contains the unsigned transaction and metadata.
@immutable
class ColdTxRequest {
  const ColdTxRequest({
    required this.version,
    required this.chainId,
    required this.from,
    required this.to,
    required this.value, // wei as hex string
    required this.gasLimit,
    required this.maxFeePerGas,
    required this.maxPriorityFeePerGas,
    required this.nonce,
    required this.data, // calldata as hex (0x-prefixed)
    required this.assetInfo, // decoded token info for display
    required this.expiresAt, // ISO timestamp (default 10 min from creation)
    required this.createdAt,
    this.id, // random request ID for tracking
  });

  final int version; // = 1
  final int chainId;
  final String from;
  final String to;
  final String value;
  final String gasLimit;
  final String maxFeePerGas;
  final String maxPriorityFeePerGas;
  final int nonce;
  final String data; // 0x-prefixed calldata
  final ColdTxAssetInfo assetInfo;
  final String expiresAt;
  final String createdAt;
  final String? id;

  Map<String, dynamic> toJson() => {
    'version': version,
    'chainId': chainId,
    'from': from,
    'to': to,
    'value': value,
    'gasLimit': gasLimit,
    'maxFeePerGas': maxFeePerGas,
    'maxPriorityFeePerGas': maxPriorityFeePerGas,
    'nonce': nonce,
    'data': data,
    'assetInfo': assetInfo.toJson(),
    'expiresAt': expiresAt,
    'createdAt': createdAt,
    if (id != null) 'id': id,
  };

  factory ColdTxRequest.fromJson(Map<String, dynamic> json) => ColdTxRequest(
    version: (json['version'] as num?)?.toInt() ?? 1,
    chainId: (json['chainId'] as num?)?.toInt() ?? 56,
    from: '${json['from'] ?? ''}',
    to: '${json['to'] ?? ''}',
    value: '${json['value'] ?? ''}',
    gasLimit: '${json['gasLimit'] ?? ''}',
    maxFeePerGas: '${json['maxFeePerGas'] ?? ''}',
    maxPriorityFeePerGas: '${json['maxPriorityFeePerGas'] ?? ''}',
    nonce: (json['nonce'] as num?)?.toInt() ?? 0,
    data: '${json['data'] ?? ''}',
    assetInfo: ColdTxAssetInfo.fromJson(
      json['assetInfo'] as Map<String, dynamic>? ?? {},
    ),
    expiresAt: '${json['expiresAt'] ?? ''}',
    createdAt: '${json['createdAt'] ?? ''}',
    id: json['id']?.toString(),
  );

  /// Check if this request has expired
  bool get isExpired => DateTime.now().isAfter(DateTime.parse(expiresAt));
}

/// Asset information for display on the cold device
@immutable
class ColdTxAssetInfo {
  const ColdTxAssetInfo({
    required this.isNative,
    this.symbol,
    this.name,
    this.contractAddress,
    this.decimals,
    this.isUnknown = false,
    this.warning,
  });

  final bool isNative; // true for BNB
  final String? symbol; // e.g., 'USDT'
  final String? name; // e.g., 'Tether USD'
  final String? contractAddress;
  final int? decimals;
  final bool isUnknown; // token not in cold device's list
  final String? warning; // e.g., 'fee-on-transfer suspected'

  Map<String, dynamic> toJson() => {
    'isNative': isNative,
    if (symbol != null) 'symbol': symbol,
    if (name != null) 'name': name,
    if (contractAddress != null) 'contractAddress': contractAddress,
    if (decimals != null) 'decimals': decimals,
    'isUnknown': isUnknown,
    if (warning != null) 'warning': warning,
  };

  factory ColdTxAssetInfo.fromJson(Map<String, dynamic> json) =>
      ColdTxAssetInfo(
        isNative: json['isNative'] == true,
        symbol: json['symbol']?.toString(),
        name: json['name']?.toString(),
        contractAddress: json['contractAddress']?.toString(),
        decimals: (json['decimals'] as num?)?.toInt(),
        isUnknown: json['isUnknown'] == true,
        warning: json['warning']?.toString(),
      );
}

/// Result returned from the cold device after signing
@immutable
class ColdTxSignature {
  const ColdTxSignature({
    required this.version,
    required this.requestId, // matches the ColdTxRequest.id
    required this.chainId,
    required this.from, // recovered signer address
    required this.r, // signature components
    required this.s,
    required this.v, // full ECDSA recovery ID (0..3), NOT just yParity
    required this.signedTxHash, // hash of the signed transaction
    required this.signedAt,
    this.requestHash,
    this.yParity,
    this.rawSignedTx, // optional full signed transaction RLP
  });

  final int version;
  final String requestId;
  final String? requestHash;
  final int chainId;
  final String from;
  final String r;
  final String s;
  final String v;
  final int? yParity;
  final String signedTxHash;
  final String signedAt;
  final String? rawSignedTx;

  Map<String, dynamic> toJson() => {
    'version': version,
    'requestId': requestId,
    if (requestHash != null) 'requestHash': requestHash,
    'chainId': chainId,
    'from': from,
    'r': r,
    's': s,
    'v': v,
    if (yParity != null) 'yParity': yParity,
    'signedTxHash': signedTxHash,
    'signedAt': signedAt,
    if (rawSignedTx != null) 'rawSignedTx': rawSignedTx,
  };

  factory ColdTxSignature.fromJson(Map<String, dynamic> json) =>
      ColdTxSignature(
        version: (json['version'] as num?)?.toInt() ?? 1,
        requestId: '${json['requestId'] ?? ''}',
        requestHash: json['requestHash']?.toString(),
        chainId: (json['chainId'] as num?)?.toInt() ?? 56,
        from: '${json['from'] ?? ''}',
        r: '${json['r'] ?? ''}',
        s: '${json['s'] ?? ''}',
        v: '${json['v'] ?? ''}',
        yParity: (json['yParity'] as num?)?.toInt(),
        signedTxHash: '${json['signedTxHash'] ?? ''}',
        signedAt: '${json['signedAt'] ?? ''}',
        rawSignedTx: json['rawSignedTx']?.toString(),
      );
}

/// Balance snapshot imported into the cold device from the online device
@immutable
class BalanceSnapshot {
  const BalanceSnapshot({
    required this.address,
    required this.balances, // token symbol -> raw amount (wei)
    required this.fetchedAt,
    required this.blockNumber,
    this.source = 'online', // 'online' | 'manual'
  });

  final String address;
  final Map<String, String> balances;
  final String fetchedAt; // ISO timestamp
  final int blockNumber;
  final String source;

  Map<String, dynamic> toJson() => {
    'address': address,
    'balances': balances,
    'fetchedAt': fetchedAt,
    'blockNumber': blockNumber,
    'source': source,
  };

  factory BalanceSnapshot.fromJson(Map<String, dynamic> json) =>
      BalanceSnapshot(
        address: '${json['address'] ?? ''}',
        balances: (json['balances'] as Map?)?.cast<String, String>() ?? {},
        fetchedAt: '${json['fetchedAt'] ?? ''}',
        blockNumber: (json['blockNumber'] as num?)?.toInt() ?? 0,
        source: '${json['source'] ?? 'online'}',
      );
}

/// Cold device hygiene status (for display)
@immutable
class ColdHygieneStatus {
  const ColdHygieneStatus({
    required this.airplaneModeOn,
    required this.wifiOff,
    required this.mobileDataOff,
    required this.bluetoothOff,
    required this.nfcOff,
    required this.noActiveNetworkInterface,
    required this.batteryLevel,
    required this.isCharging,
    required this.checkedAt,
  });

  final bool airplaneModeOn;
  final bool wifiOff;
  final bool mobileDataOff;
  final bool bluetoothOff;
  final bool nfcOff;
  final bool noActiveNetworkInterface;
  final int? batteryLevel; // 0-100, null if unknown
  final bool isCharging;
  final String checkedAt;

  int get passedCount {
    int count = 0;
    if (airplaneModeOn) count++;
    if (wifiOff) count++;
    if (mobileDataOff) count++;
    if (bluetoothOff) count++;
    if (nfcOff) count++;
    if (noActiveNetworkInterface) count++;
    return count;
  }

  int get totalCount => 6;

  bool get allPassed => passedCount == totalCount;
}

/// Result of decoding a ColdTxRequest on the cold device.
@immutable
class ColdTxDecodeResult {
  const ColdTxDecodeResult({
    required this.chainId,
    required this.from,
    required this.to,
    required this.value,
    required this.gasLimit,
    required this.maxFeePerGas,
    required this.maxPriorityFeePerGas,
    required this.nonce,
    required this.data,
    this.functionName,
    this.decodedTo,
    this.decodedValue,
    required this.assetInfo,
    required this.totalPossibleFee,
    required this.expiresAt,
    this.warning,
  });

  final int chainId;
  final String from;
  final String to;
  final BigInt value;
  final BigInt gasLimit;
  final BigInt maxFeePerGas;
  final BigInt maxPriorityFeePerGas;
  final int nonce;
  final String data;
  final String? functionName;
  final String? decodedTo;
  final BigInt? decodedValue;
  final ColdTxAssetInfo assetInfo;
  final BigInt totalPossibleFee;
  final DateTime expiresAt;
  final String? warning;
}
