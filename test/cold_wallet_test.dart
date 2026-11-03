import 'package:flutter_test/flutter_test.dart';
import 'package:bnb_wallet_gui/wallet_core.dart';
import 'package:bnb_wallet_gui/cold_wallet.dart';

void main() {
  group('Cold wallet signing (EIP-1559)', () {
    const testPhrase = 'test test test test test test test test test test test junk';
    const testPassphrase = '';
    const testPath = "m/44'/60'/0'/0/0";
    
    // Known test vector: the junk mnemonic derives to address 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
    const fromAddress = '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266';
    const toAddress = '0x70997970C51812dc3A010C7d01b50e0d17dc79C8';
    const value = '0xde0b6b3a7640000'; // 1 ETH in wei
    const gasLimit = '0x5208'; // 21000
    const maxFeePerGas = '0x3b9aca00'; // 1 gwei
    const maxPriorityFeePerGas = '0x3b9aca00'; // 1 gwei
    const nonce = 0;
    const chainId = 56; // BSC Mainnet
    const data = '0x'; // Empty data for simple transfer

    test('signTransaction produces valid signature components', () {
      final request = ColdTxRequest(
        version: 1,
        chainId: chainId,
        from: fromAddress,
        to: toAddress,
        value: value,
        gasLimit: gasLimit,
        maxFeePerGas: maxFeePerGas,
        maxPriorityFeePerGas: maxPriorityFeePerGas,
        nonce: nonce,
        data: data,
        assetInfo: const ColdTxAssetInfo(isNative: true),
        expiresAt: DateTime.now().add(const Duration(minutes: 10)).toUtc().toIso8601String(),
        createdAt: DateTime.now().toUtc().toIso8601String(),
        id: 'test-request-1',
      );

      final signature = WalletCore.signTransaction(
        phrase: testPhrase,
        passphrase: testPassphrase,
        request: request,
        path: testPath,
      );

      // Verify signature components are present and well-formed
      expect(signature.version, 1);
      expect(signature.requestId, 'test-request-1');
      expect(signature.chainId, chainId);
      expect(signature.from, fromAddress);
      
      // r and s should be 64 hex chars (32 bytes each)
      expect(signature.r, startsWith('0x'));
      expect(signature.r.length, 66); // 0x + 64 hex chars
      expect(signature.s, startsWith('0x'));
      expect(signature.s.length, 66);
      
      // v should be 0 or 1 for EIP-1559 (yParity)
      expect(signature.v, startsWith('0x'));
      final v = int.parse(signature.v.substring(2), radix: 16);
      expect(v, anyOf(0, 1));
      
      // signedTxHash should be a valid hash
      expect(signature.signedTxHash, startsWith('0x'));
      expect(signature.signedTxHash.length, 66); // 0x + 64 hex chars
      
      // rawSignedTx should be a valid hex string starting with 0x02 (EIP-1559)
      expect(signature.rawSignedTx, startsWith('0x02'));
    });

    test('verifyColdSignature accepts valid signature', () {
      final request = ColdTxRequest(
        version: 1,
        chainId: chainId,
        from: fromAddress,
        to: toAddress,
        value: value,
        gasLimit: gasLimit,
        maxFeePerGas: maxFeePerGas,
        maxPriorityFeePerGas: maxPriorityFeePerGas,
        nonce: nonce,
        data: data,
        assetInfo: const ColdTxAssetInfo(isNative: true),
        expiresAt: DateTime.now().add(const Duration(minutes: 10)).toUtc().toIso8601String(),
        createdAt: DateTime.now().toUtc().toIso8601String(),
        id: 'test-request-2',
      );

      final signature = WalletCore.signTransaction(
        phrase: testPhrase,
        passphrase: testPassphrase,
        request: request,
        path: testPath,
      );

      final isValid = WalletCore.verifyColdSignature(
        request: request,
        signature: signature,
        expectedFrom: fromAddress,
      );

      expect(isValid, isTrue);
    });

    test('verifyColdSignature rejects modified transaction', () {
      final request = ColdTxRequest(
        version: 1,
        chainId: chainId,
        from: fromAddress,
        to: toAddress,
        value: value,
        gasLimit: gasLimit,
        maxFeePerGas: maxFeePerGas,
        maxPriorityFeePerGas: maxPriorityFeePerGas,
        nonce: nonce,
        data: data,
        assetInfo: const ColdTxAssetInfo(isNative: true),
        expiresAt: DateTime.now().add(const Duration(minutes: 10)).toUtc().toIso8601String(),
        createdAt: DateTime.now().toUtc().toIso8601String(),
        id: 'test-request-3',
      );

      final signature = WalletCore.signTransaction(
        phrase: testPhrase,
        passphrase: testPassphrase,
        request: request,
        path: testPath,
      );

      // Modify the request (different recipient)
      final modifiedRequest = ColdTxRequest(
        version: 1,
        chainId: chainId,
        from: fromAddress,
        to: '0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC', // Different address
        value: value,
        gasLimit: gasLimit,
        maxFeePerGas: maxFeePerGas,
        maxPriorityFeePerGas: maxPriorityFeePerGas,
        nonce: nonce,
        data: data,
        assetInfo: const ColdTxAssetInfo(isNative: true),
        expiresAt: DateTime.now().add(const Duration(minutes: 10)).toUtc().toIso8601String(),
        createdAt: DateTime.now().toUtc().toIso8601String(),
        id: 'test-request-3',
      );

      final isValid = WalletCore.verifyColdSignature(
        request: modifiedRequest,
        signature: signature,
        expectedFrom: fromAddress,
      );

      expect(isValid, isFalse);
    });

    test('verifyColdSignature rejects modified value', () {
      final request = ColdTxRequest(
        version: 1,
        chainId: chainId,
        from: fromAddress,
        to: toAddress,
        value: value,
        gasLimit: gasLimit,
        maxFeePerGas: maxFeePerGas,
        maxPriorityFeePerGas: maxPriorityFeePerGas,
        nonce: nonce,
        data: data,
        assetInfo: const ColdTxAssetInfo(isNative: true),
        expiresAt: DateTime.now().add(const Duration(minutes: 10)).toUtc().toIso8601String(),
        createdAt: DateTime.now().toUtc().toIso8601String(),
        id: 'test-request-4',
      );

      final signature = WalletCore.signTransaction(
        phrase: testPhrase,
        passphrase: testPassphrase,
        request: request,
        path: testPath,
      );

      // Modify the request (different value)
      final modifiedRequest = ColdTxRequest(
        version: 1,
        chainId: chainId,
        from: fromAddress,
        to: toAddress,
        value: '0x1bc16d674ec80000', // 2 ETH
        gasLimit: gasLimit,
        maxFeePerGas: maxFeePerGas,
        maxPriorityFeePerGas: maxPriorityFeePerGas,
        nonce: nonce,
        data: data,
        assetInfo: const ColdTxAssetInfo(isNative: true),
        expiresAt: DateTime.now().add(const Duration(minutes: 10)).toUtc().toIso8601String(),
        createdAt: DateTime.now().toUtc().toIso8601String(),
        id: 'test-request-4',
      );

      final isValid = WalletCore.verifyColdSignature(
        request: modifiedRequest,
        signature: signature,
        expectedFrom: fromAddress,
      );

      expect(isValid, isFalse);
    });

    test('verifyColdSignature rejects wrong chain ID', () {
      final request = ColdTxRequest(
        version: 1,
        chainId: chainId,
        from: fromAddress,
        to: toAddress,
        value: value,
        gasLimit: gasLimit,
        maxFeePerGas: maxFeePerGas,
        maxPriorityFeePerGas: maxPriorityFeePerGas,
        nonce: nonce,
        data: data,
        assetInfo: const ColdTxAssetInfo(isNative: true),
        expiresAt: DateTime.now().add(const Duration(minutes: 10)).toUtc().toIso8601String(),
        createdAt: DateTime.now().toUtc().toIso8601String(),
        id: 'test-request-5',
      );

      final signature = WalletCore.signTransaction(
        phrase: testPhrase,
        passphrase: testPassphrase,
        request: request,
        path: testPath,
      );

      // Modify the request (different chain ID)
      final modifiedRequest = ColdTxRequest(
        version: 1,
        chainId: 97, // Testnet instead of mainnet
        from: fromAddress,
        to: toAddress,
        value: value,
        gasLimit: gasLimit,
        maxFeePerGas: maxFeePerGas,
        maxPriorityFeePerGas: maxPriorityFeePerGas,
        nonce: nonce,
        data: data,
        assetInfo: const ColdTxAssetInfo(isNative: true),
        expiresAt: DateTime.now().add(const Duration(minutes: 10)).toUtc().toIso8601String(),
        createdAt: DateTime.now().toUtc().toIso8601String(),
        id: 'test-request-5',
      );

      final isValid = WalletCore.verifyColdSignature(
        request: modifiedRequest,
        signature: signature,
        expectedFrom: fromAddress,
      );

      expect(isValid, isFalse);
    });

    test('verifyColdSignature rejects wrong nonce', () {
      final request = ColdTxRequest(
        version: 1,
        chainId: chainId,
        from: fromAddress,
        to: toAddress,
        value: value,
        gasLimit: gasLimit,
        maxFeePerGas: maxFeePerGas,
        maxPriorityFeePerGas: maxPriorityFeePerGas,
        nonce: nonce,
        data: data,
        assetInfo: const ColdTxAssetInfo(isNative: true),
        expiresAt: DateTime.now().add(const Duration(minutes: 10)).toUtc().toIso8601String(),
        createdAt: DateTime.now().toUtc().toIso8601String(),
        id: 'test-request-6',
      );

      final signature = WalletCore.signTransaction(
        phrase: testPhrase,
        passphrase: testPassphrase,
        request: request,
        path: testPath,
      );

      // Modify the request (different nonce)
      final modifiedRequest = ColdTxRequest(
        version: 1,
        chainId: chainId,
        from: fromAddress,
        to: toAddress,
        value: value,
        gasLimit: gasLimit,
        maxFeePerGas: maxFeePerGas,
        maxPriorityFeePerGas: maxPriorityFeePerGas,
        nonce: nonce + 1,
        data: data,
        assetInfo: const ColdTxAssetInfo(isNative: true),
        expiresAt: DateTime.now().add(const Duration(minutes: 10)).toUtc().toIso8601String(),
        createdAt: DateTime.now().toUtc().toIso8601String(),
        id: 'test-request-6',
      );

      final isValid = WalletCore.verifyColdSignature(
        request: modifiedRequest,
        signature: signature,
        expectedFrom: fromAddress,
      );

      expect(isValid, isFalse);
    });

    test('signTransaction with ERC-20 transfer data', () {
      // ERC-20 transfer: transfer(to, amount)
      // Function selector: 0xa9059cbb
      // to: 0x70997970C51812dc3A010C7d01b50e0d17dc79C8 (padded to 32 bytes)
      // amount: 1000000 (padded to 32 bytes)
      const erc20Data = '0xa9059cbb00000000000000000000000070997970c51812dc3a010c7d01b50e0d17dc79c800000000000000000000000000000000000000000000000000000000000f4240';
      
      final request = ColdTxRequest(
        version: 1,
        chainId: chainId,
        from: fromAddress,
        to: '0x55d398326f99059fF775485246999027B3197955', // USDT contract
        value: '0x0', // No native value for token transfer
        gasLimit: '0x186a0', // 100000
        maxFeePerGas: maxFeePerGas,
        maxPriorityFeePerGas: maxPriorityFeePerGas,
        nonce: nonce,
        data: erc20Data,
        assetInfo: ColdTxAssetInfo(
          isNative: false,
          contractAddress: '0x55d398326f99059fF775485246999027B3197955',
          symbol: 'USDT',
          name: 'Tether USD',
          decimals: 18,
        ),
        expiresAt: DateTime.now().add(const Duration(minutes: 10)).toUtc().toIso8601String(),
        createdAt: DateTime.now().toUtc().toIso8601String(),
        id: 'test-request-7',
      );

      final signature = WalletCore.signTransaction(
        phrase: testPhrase,
        passphrase: testPassphrase,
        request: request,
        path: testPath,
      );

      expect(signature.version, 1);
      expect(signature.from, fromAddress);
      expect(signature.rawSignedTx, startsWith('0x02'));
      
      final isValid = WalletCore.verifyColdSignature(
        request: request,
        signature: signature,
        expectedFrom: fromAddress,
      );

      expect(isValid, isTrue);
    });

    test('signTransaction is deterministic for same inputs (RFC 6979)', () {
      final request = ColdTxRequest(
        version: 1,
        chainId: chainId,
        from: fromAddress,
        to: toAddress,
        value: value,
        gasLimit: gasLimit,
        maxFeePerGas: maxFeePerGas,
        maxPriorityFeePerGas: maxPriorityFeePerGas,
        nonce: nonce,
        data: data,
        assetInfo: const ColdTxAssetInfo(isNative: true),
        expiresAt: DateTime.now().add(const Duration(minutes: 10)).toUtc().toIso8601String(),
        createdAt: DateTime.now().toUtc().toIso8601String(),
        id: 'test-request-8',
      );

      final sig1 = WalletCore.signTransaction(
        phrase: testPhrase,
        passphrase: testPassphrase,
        request: request,
        path: testPath,
      );

      final sig2 = WalletCore.signTransaction(
        phrase: testPhrase,
        passphrase: testPassphrase,
        request: request,
        path: testPath,
      );

      // RFC 6979 deterministic signatures: same inputs produce identical signatures
      expect(sig1.r, sig2.r);
      expect(sig1.s, sig2.s);
      expect(sig1.v, sig2.v);
      expect(sig1.rawSignedTx, sig2.rawSignedTx);
      
      // And should verify correctly
      expect(WalletCore.verifyColdSignature(request: request, signature: sig1, expectedFrom: fromAddress), isTrue);
      expect(WalletCore.verifyColdSignature(request: request, signature: sig2, expectedFrom: fromAddress), isTrue);
    });
  });
}
