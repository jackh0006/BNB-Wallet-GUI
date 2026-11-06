// Real-EVM integration tests. Run only with ANVIL_URL set, e.g.
//   ANVIL_URL=http://127.0.0.1:8545 flutter test --tags integration test/integration
//
// The keys below are Anvil's public deterministic development accounts. They
// are not wallet secrets and hold only valueless test funds.
@Tags(['integration'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bnb_wallet_gui/cold_tx_codec.dart';
import 'package:bnb_wallet_gui/rpc_service.dart';
import 'package:bnb_wallet_gui/wallet_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wallet/wallet.dart';
import 'package:web3dart/web3dart.dart';

const _chainId = 97;
const _key0 =
    '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80';
const _from0 = '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266';
const _to1 = '0x70997970C51812dc3A010C7d01b50e0d17dc79C8';
const _key1 =
    '0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d';

RpcService _rpc(String url) {
  final rpc = RpcService();
  rpc.setNetwork('testnet');
  rpc.setStrictFlag(true);
  rpc.setConfiguredRpc(url);
  return rpc;
}

Future<TransactionReceipt> _send(
  RpcService rpc,
  EthPrivateKey key, {
  required String from,
  String? to,
  BigInt? value,
  required Uint8List data,
  int gas = 100000,
  BigInt? maxFee,
  BigInt? priority,
}) async {
  final tx = Transaction(
    from: EthereumAddress.fromHex(from),
    to: to == null ? null : EthereumAddress.fromHex(to),
    value: EtherAmount.inWei(value ?? BigInt.zero),
    nonce: await rpc.getNonce(from),
    maxGas: gas,
    maxFeePerGas: EtherAmount.inWei(maxFee ?? BigInt.from(3000000000)),
    maxPriorityFeePerGas: EtherAmount.inWei(
      priority ?? BigInt.from(1000000000),
    ),
    data: data,
  );
  final signed = await rpc.signOnly(tx, key);
  if (to != null) {
    // Contract creation has an empty `to`, which the strict transfer codec
    // intentionally does not model. For transfers, prove the signed bytes
    // match every reviewed field.
    final parsed = ColdTxCodec.parseSigned(hexToBytes(signed.rawHex));
    expect(parsed.fields.chainId, _chainId);
    expect(parsed.fields.to.toLowerCase(), to.toLowerCase());
    expect(parsed.fields.value, value ?? BigInt.zero);
    expect(parsed.fields.data, data);
  }
  final hash = await rpc.sendRawHex(signed.rawHex);
  expect(hash.toLowerCase(), signed.hash.toLowerCase());
  final info = await rpc.client!.getTransactionByHash(hash);
  expect(info, isNotNull);
  expect(info!.from.eip55With0x.toLowerCase(), from.toLowerCase());
  expect(info.to?.eip55With0x.toLowerCase(), to?.toLowerCase());
  expect(info.value.getInWei, value ?? BigInt.zero);
  expect(info.input, data);
  return _waitReceipt(rpc, hash);
}

Future<TransactionReceipt> _waitReceipt(RpcService rpc, String hash) async {
  for (var i = 0; i < 100; i++) {
    final receipt = await rpc.receipt(hash);
    if (receipt != null) return receipt;
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  fail('transaction $hash was not mined');
}

void main() {
  final url = Platform.environment['ANVIL_URL'];
  final skip = url == null ? 'ANVIL_URL is not set' : null;

  test(
    'native transfer is signed, field-exact, mined and credited',
    () async {
      final rpc = _rpc(url!);
      addTearDown(rpc.dispose);
      await rpc.connect(allowFallback: false);
      expect(rpc.chainId, _chainId);

      final before = await rpc.getNativeBalance(_to1);
      final amount = BigInt.from(123456789);
      final receipt = await _send(
        rpc,
        WalletCore.privateKeyFromHex(_key0),
        from: _from0,
        to: _to1,
        value: amount,
        data: Uint8List(0),
        gas: 21000,
      );
      expect(receipt.status, isTrue);
      final after = await rpc.getNativeBalance(_to1);
      expect(after - before, amount);
    },
    skip: skip,
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'wrong chain is rejected before signing',
    () async {
      final rpc = _rpc(url!);
      addTearDown(rpc.dispose);
      rpc.setNetwork('mainnet'); // expects 56, Anvil is 97
      rpc.setConfiguredRpc(url);
      expect(rpc.chainId, 56);
      expect(rpc.isConnected, isFalse);
      var threw = false;
      Object? failure;
      try {
        await rpc.connect(allowFallback: false);
      } catch (error) {
        threw = true;
        failure = error;
      }
      expect(
        threw,
        isTrue,
        reason: 'connect accepted a wrong-chain node; $failure',
      );
      expect(rpc.isConnected, isFalse);
    },
    skip: skip,
    timeout: const Timeout(Duration(minutes: 1)),
  );

  test(
    'ERC-20 deploy, mint, transfer, approve and revoke',
    () async {
      final rpc = _rpc(url!);
      addTearDown(rpc.dispose);
      await rpc.connect(allowFallback: false);

      final fixture = jsonDecode(
        File('test/integration/fixtures/test_token.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final bytecode = hexToBytes(fixture['bytecode'] as String);
      final abi = ContractAbi.fromJson(jsonEncode(fixture['abi']), 'TestToken');
      final key0 = WalletCore.privateKeyFromHex(_key0);
      final key1 = WalletCore.privateKeyFromHex(_key1);

      final deploy = await _send(
        rpc,
        key0,
        from: _from0,
        data: bytecode,
        gas: 3000000,
      );
      expect(deploy.status, isTrue);
      final token = deploy.contractAddress!;

      final contract = DeployedContract(abi, token);
      final mint = contract.function('mint');
      final transfer = contract.function('transfer');
      final approve = contract.function('approve');
      final balanceOf = contract.function('balanceOf');
      final allowance = contract.function('allowance');
      final decimals = contract.function('decimals');
      final symbol = contract.function('symbol');

      final oneToken = BigInt.from(10).pow(18);
      final mintReceipt = await _send(
        rpc,
        key0,
        from: _from0,
        to: token.eip55With0x,
        data: mint.encodeCall([
          EthereumAddress.fromHex(_from0),
          oneToken * BigInt.from(1000),
        ]),
        gas: 200000,
      );
      expect(mintReceipt.status, isTrue);

      final dec =
          (await rpc.client!.call(
                contract: contract,
                function: decimals,
                params: const [],
              )).first
              as BigInt;
      expect(dec, BigInt.from(18));
      final sym =
          (await rpc.client!.call(
                contract: contract,
                function: symbol,
                params: const [],
              )).first
              as String;
      expect(sym, 'TST');

      final amount = BigInt.from(12345);
      final transferReceipt = await _send(
        rpc,
        key0,
        from: _from0,
        to: token.eip55With0x,
        data: transfer.encodeCall([EthereumAddress.fromHex(_to1), amount]),
        gas: 100000,
      );
      expect(transferReceipt.status, isTrue);
      final toBalance =
          (await rpc.client!.call(
                contract: contract,
                function: balanceOf,
                params: [EthereumAddress.fromHex(_to1)],
              )).first
              as BigInt;
      expect(toBalance, amount);

      final approveReceipt = await _send(
        rpc,
        key0,
        from: _from0,
        to: token.eip55With0x,
        data: approve.encodeCall([
          EthereumAddress.fromHex(_to1),
          BigInt.from(5000),
        ]),
        gas: 100000,
      );
      expect(approveReceipt.status, isTrue);
      var allowed =
          (await rpc.client!.call(
                contract: contract,
                function: allowance,
                params: [
                  EthereumAddress.fromHex(_from0),
                  EthereumAddress.fromHex(_to1),
                ],
              )).first
              as BigInt;
      expect(allowed, BigInt.from(5000));

      final revokeReceipt = await _send(
        rpc,
        key0,
        from: _from0,
        to: token.eip55With0x,
        data: approve.encodeCall([EthereumAddress.fromHex(_to1), BigInt.zero]),
        gas: 100000,
      );
      expect(revokeReceipt.status, isTrue);
      allowed =
          (await rpc.client!.call(
                contract: contract,
                function: allowance,
                params: [
                  EthereumAddress.fromHex(_from0),
                  EthereumAddress.fromHex(_to1),
                ],
              )).first
              as BigInt;
      expect(allowed, BigInt.zero);

      // A transfer above the sender's balance must revert, not silently pass.
      final revertReceipt = await _send(
        rpc,
        key1,
        from: _to1,
        to: token.eip55With0x,
        data: transfer.encodeCall([
          EthereumAddress.fromHex(_from0),
          BigInt.from(10).pow(30),
        ]),
        gas: 100000,
      );
      expect(revertReceipt.status, isFalse);
    },
    skip: skip,
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
