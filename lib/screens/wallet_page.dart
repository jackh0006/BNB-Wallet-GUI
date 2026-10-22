import 'dart:async';

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../wallet_core.dart';
import '../widgets/seed_picker.dart';
import 'backup_quiz_dialog.dart';
import 'common.dart';
import 'receipt_page.dart';

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage>
    with AutomaticKeepAliveClientMixin {
  List<HistoryTx>? _history;
  String? _historyError;
  bool _loadingHistory = false;
  Timer? _historyDebounce;
  Map<String, BigInt>? _balances;
  List<LocalReceipt>? _receipts;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    appState.addListener(_onStateChanged);
    _loadHistory();
    _loadBalancesSummary();
    _loadReceipts();
  }

  @override
  void dispose() {
    _historyDebounce?.cancel();
    appState.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (!mounted) return;
    // Many notifies can arrive in one burst (connection story lines, RPC
    // transitions). Coalesce them: wait 400 ms of quiet before fetching
    // history again, so the change-notify storm cannot start a fetch per
    // line on weak machines.
    _historyDebounce?.cancel();
    _historyDebounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) {
        _loadHistory();
        _loadBalancesSummary();
        _loadReceipts();
      }
    });
  }

  /// The locally kept receipts (newest first, encrypted at rest). They make
  /// the history work offline — no BscScan key needed for this part.
  Future<void> _loadReceipts() async {
    if (!appState.unlocked) {
      _receipts = null;
      if (mounted) setState(() {});
      return;
    }
    final receipts = await appState.loadLocalReceipts();
    if (mounted) setState(() => _receipts = receipts.isEmpty ? null : receipts);
  }

  /// Terminal v1 prints the wallet dashboard (balances right after unlock).
  /// This is the GUI equivalent: the Wallet screen must plainly show the
  /// wallet the moment one is unlocked — never just a message about it.
  Future<void> _loadBalancesSummary() async {
    if (!appState.unlocked || appState.address == null) {
      if (mounted) setState(() => _balances = null);
      return;
    }
    try {
      final balances = await loadBalances(appState.address!);
      if (mounted) setState(() => _balances = balances);
    } catch (_) {
      // Home narrates connection problems into the story card; this summary
      // simply keeps whatever it last showed.
    }
  }

  Future<void> _loadHistory() async {
    if (!appState.unlocked ||
        appState.address == null ||
        appState.bscscanKey == null) {
      setState(() {
        _history = null;
        _historyError = null;
      });
      return;
    }
    setState(() {
      _loadingHistory = true;
      _historyError = null;
    });
    try {
      final history = await appState.rpc.history(appState.address!);
      if (!mounted) return;
      setState(() {
        _history = history;
        _loadingHistory = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _historyError = error.toString().replaceFirst('Exception: ', '');
        _loadingHistory = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Wallet')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
          children: [
            if (!appState.unlocked) ...[
              _lockedCard(),
            ] else ...[
              _unlockedCard(),
              const SizedBox(height: 14),
              _profilesCard(),
              const SizedBox(height: 14),
              _historyCard(),
            ],
            const SizedBox(height: 14),
            _dangerCard(),
          ],
        ),
      ),
    );
  }

  Widget _lockedCard() {
    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Wallet',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create a new BIP-39 wallet or import an existing private key, recovery phrase, '
            'Ethereum V3 keystore file, or encrypted local vault.',
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: () => showCreateWalletDialog(context),
                icon: const Icon(Icons.add),
                label: const Text('Create wallet'),
              ),
              OutlinedButton.icon(
                onPressed: () => showImportWalletDialog(context),
                icon: const Icon(Icons.file_download),
                label: const Text('Import'),
              ),
              OutlinedButton.icon(
                onPressed: () => showUnlockVaultDialog(context),
                icon: const Icon(Icons.lock_open),
                label: const Text('Unlock vault'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _unlockedCard() {
    final address = appState.address!;
    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  shortAddress(address),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Copy address',
                icon: const Icon(Icons.copy, size: 18),
                onPressed: () => copyText(context, address, 'Address'),
              ),
              IconButton(
                tooltip: 'Receive QR',
                icon: const Icon(Icons.qr_code, size: 18),
                onPressed: () => showQrDialog(context, address),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (appState.watchOnly) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFF0B90B).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Watch-only · this device holds no key for this address',
                style: TextStyle(color: Color(0xFFF0B90B), fontSize: 12),
              ),
            ),
            const SizedBox(height: 6),
          ],
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Balances',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                tooltip: 'Refresh balances',
                icon: const Icon(Icons.refresh, size: 18),
                onPressed: _loadBalancesSummary,
              ),
            ],
          ),
          if (_balances == null)
            const Text(
              'Fetching balances…',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            )
          else
            for (final token in [
              const TokenInfo(
                symbol: 'BNB',
                name: 'BNB Smart Chain',
                address: '',
                decimals: 18,
                native: true,
              ),
              ...appState.rpc.tokens,
            ])
              if (_balances!.containsKey(token.symbol) &&
                  !appState.isTokenHidden(token))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _balances![token.symbol]! < BigInt.zero
                              ? '${token.symbol}: unavailable right now'
                              : '${WalletCore.formatUnits(_balances![token.symbol]!, token.decimals)} ${token.symbol}',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                      if (!token.native)
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Hide ${token.symbol}',
                          icon: const Icon(
                            Icons.visibility_off_outlined,
                            size: 16,
                          ),
                          onPressed: () async {
                            await appState.setTokenHidden(token, true);
                            if (!mounted) return;
                            showInfo(
                              context,
                              '${token.symbol} hidden. '
                              'Settings → Tokens can bring it back.',
                            );
                          },
                        ),
                    ],
                  ),
                ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (!appState.watchOnly) ...[
                OutlinedButton.icon(
                  onPressed: () => _revealSecrets(context),
                  icon: const Icon(Icons.visibility),
                  label: const Text('Reveal secrets'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _saveVault(context),
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save to vault'),
                ),
              ],
              OutlinedButton.icon(
                onPressed: () => _saveProfile(context),
                icon: const Icon(Icons.bookmark_add_outlined),
                label: const Text('Save profile'),
              ),
              if (appState.watchOnly)
                OutlinedButton.icon(
                  onPressed: () async {
                    await appState.closeWatchOnly();
                    if (!mounted) return;
                    showInfo(context, 'Watch-only profile closed.');
                  },
                  icon: const Icon(Icons.visibility_off_outlined),
                  label: const Text('Close watch profile'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _profilesCard() {
    final profiles = appState.profiles;
    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Public profiles',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'Labels and public addresses only. Never secrets.',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 8),
          if (profiles.isEmpty)
            const Text(
              'No profiles saved yet.',
              style: TextStyle(color: Colors.white54),
            )
          else
            for (var i = 0; i < profiles.length; i++)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.bookmark_outline),
                title: Text(profiles[i].label),
                subtitle: Text(shortAddress(profiles[i].address)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, size: 18),
                      onPressed: () async {
                        final label = await promptText(
                          context,
                          title: 'Rename profile',
                          initialValue: profiles[i].label,
                          label: 'Label',
                        );
                        if (label != null && label.isNotEmpty) {
                          await appState.renameProfile(i, label);
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18),
                      onPressed: () => appState.deleteProfile(i),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  Widget _historyCard() {
    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Transaction history',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 18),
                onPressed: _loadHistory,
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (_receipts != null && _receipts!.isNotEmpty) ...[
            const Text(
              'Receipts from this device (kept encrypted, offline)',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            for (final receipt in _receipts!)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: Icon(
                  receipt.status == 'success'
                      ? Icons.check_circle_outline
                      : Icons.error_outline,
                  size: 18,
                  color: receipt.status == 'success'
                      ? Colors.greenAccent
                      : Colors.redAccent,
                ),
                title: Text(
                  '${receipt.amountHuman} ${receipt.assetSymbol} → ${shortAddress(receipt.to)}',
                  style: const TextStyle(fontSize: 13),
                ),
                subtitle: Text(
                  'block ${receipt.blockNumber} · '
                  '${receipt.finalized ? 'final' : 'included'} · '
                  '${receipt.verifiedNodes >= 2 ? '2 nodes ✓' : '1 node'}',
                  style: const TextStyle(fontSize: 12),
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ReceiptPage(receipt: receipt),
                  ),
                ),
              ),
            const Divider(),
          ],
          if (appState.bscscanKey == null)
            const Text(
              'Add a BscScan API key in Settings to enable history. Balances and transfers do not need it.',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            )
          else if (_loadingHistory)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_historyError != null)
            Text(
              _historyError!,
              style: const TextStyle(color: Colors.redAccent),
            )
          else if (_history == null || _history!.isEmpty)
            const Text(
              'No normal transactions found.',
              style: TextStyle(color: Colors.white54),
            )
          else
            for (final tx in _history!)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: Icon(
                  tx.from.toLowerCase() == appState.address?.toLowerCase()
                      ? Icons.arrow_upward
                      : Icons.arrow_downward,
                  size: 18,
                ),
                title: Text(shortAddress(tx.hash)),
                subtitle: Text(
                  '${tx.from.toLowerCase() == appState.address?.toLowerCase() ? 'OUT' : 'IN'} · ${tx.timestamp}',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.open_in_new, size: 16),
                  onPressed: () =>
                      copyText(context, tx.hash, 'Transaction hash'),
                ),
              ),
        ],
      ),
    );
  }

  Widget _dangerCard() {
    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sensitive actions',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Revealing a private key or recovery phrase gives anyone who sees the screen full control. '
            'Never share them, never type them into a website.',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: () => appState.lock(),
                icon: const Icon(Icons.lock_outline),
                label: const Text('Lock wallet'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _revealSecrets(BuildContext context) async {
    final confirmed = await confirmDialog(
      context,
      title: 'Reveal secrets?',
      message: 'Anyone who can see this screen can steal all funds. Only reveal secrets on a trusted, private device.',
      confirmLabel: 'Reveal',
    );
    if (!confirmed || !mounted) return;
    final key = appState.privateKey!;
    await showMessage(
      context,
      'Sensitive export',
      'Address: ${appState.address}\n\n'
          'Private key:\n${WalletCore.privateKeyHex(key)}\n\n'
          'Recovery phrase:\n${appState.mnemonic ?? 'Not available for this import.'}\n\n'
          'Store one secure offline backup. Never photograph or share it.',
    );
  }

  Future<void> _saveVault(BuildContext context) async {
    final password = await promptText(
      context,
      title: 'Save encrypted vault',
      label: 'Vault password (16+ characters)',
      obscure: true,
      validator: (value) =>
          value.length >= 16 ? null : 'Use at least 16 characters.',
    );
    if (password == null || password.isEmpty || !mounted) return;
    final label = await promptText(
      context,
      title: 'Vault account label',
      label: 'Label',
      initialValue: 'Wallet ${appState.profiles.length + 1}',
    );
    if (label == null || !mounted) return;
    try {
      await appState.saveVaultAccount(
        password,
        label: label,
        key: appState.privateKey!,
        mnemonic: appState.mnemonic,
      );
      if (mounted) showInfo(context, 'Encrypted vault saved.');
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

  Future<void> _saveProfile(BuildContext context) async {
    final label = await promptText(
      context,
      title: 'Save public profile',
      label: 'Label',
      initialValue: 'Wallet ${appState.profiles.length + 1}',
    );
    if (label == null || label.isEmpty || !mounted) return;
    await appState.addProfile(
      WalletProfile(
        label: label,
        address: appState.address!,
        source: appState.mnemonic != null ? 'phrase' : 'key',
        createdAt: DateTime.now().toIso8601String(),
      ),
    );
    if (mounted) showInfo(context, 'Public profile saved.');
  }
}

Future<void> showCreateWalletDialog(BuildContext context) async {
  final mnemonic = WalletCore.generateMnemonic();
  final accepted = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: const Text('Write this recovery phrase offline'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SelectableText(
              'This phrase controls the wallet. Anyone who sees it can take the funds.',
              style: TextStyle(color: Colors.redAccent),
            ),
            const SizedBox(height: 12),
            SelectableText(
              mnemonic,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('I stored it'),
        ),
      ],
    ),
  );
  if (accepted != true || !context.mounted) return;
  // §2: typing "I stored it" is not proof. Three random words must match the
  // phrase on paper before the wallet is created and unlocked.
  final verified = await runBackupQuiz(context, mnemonic);
  if (!verified || !context.mounted) return;
  final key = WalletCore.derivePrivateKey(phrase: mnemonic);
  await appState.unlock(key, mnemonic: mnemonic);
  appState.focusTab(1); // land on the wallet that just became visible
  if (!context.mounted) return;
  showInfo(context, 'Wallet created and unlocked.');
  await showOfferProfileAndVault(context);
}

Future<void> showImportWalletDialog(BuildContext context) async {
  final method = await showDialog<String>(
    context: context,
    builder: (context) => SimpleDialog(
      title: const Text('Import method'),
      children: [
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context, 'key'),
          child: const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.key),
            title: Text('Private key'),
            subtitle: Text('0x followed by 64 hex characters'),
          ),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context, 'phrase'),
          child: const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.article_outlined),
            title: Text('Recovery phrase'),
            subtitle: Text('12 or 24 words'),
          ),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context, 'keystore'),
          child: const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.description_outlined),
            title: Text('Ethereum V3 keystore'),
            subtitle: Text('Paste the JSON file contents'),
          ),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context, 'watch'),
          child: const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.visibility_outlined),
            title: Text('Watch an address'),
            subtitle: Text('Read-only: no key is imported or stored'),
          ),
        ),
      ],
    ),
  );
  if (method == null || !context.mounted) return;
  switch (method) {
    case 'key':
      await _importPrivateKey(context);
      break;
    case 'phrase':
      await _importPhrase(context);
      break;
    case 'keystore':
      await _importKeystore(context);
      break;
    case 'watch':
      await _importWatchAddress(context);
      break;
  }
}

Future<void> _importWatchAddress(BuildContext context) async {
  final raw = await promptText(
    context,
    title: 'Watch an address',
    label: 'Public address (0x + 40 hex characters)',
    validator: (value) => WalletCore.isValidAddress(value.trim())
        ? null
        : 'Enter a valid 0x address.',
  );
  if (raw == null || raw.trim().isEmpty || !context.mounted) return;
  try {
    await appState.openWatchOnly(raw.trim());
    appState.focusTab(1);
    if (!context.mounted) return;
    showInfo(
      context,
      'Watch-only profile opened. Balances and history are readable; this '
      'device holds no key for it.',
    );
  } catch (error) {
    if (context.mounted) showError(context, error);
  }
}

Future<void> _importPrivateKey(BuildContext context) async {
  final keyText = await promptText(
    context,
    title: 'Import private key',
    label: 'Private key (hidden)',
    obscure: true,
    validator: (value) {
      try {
        WalletCore.privateKeyFromHex(value);
        return null;
      } catch (_) {
        return 'Enter a valid 0x + 64 hex private key.';
      }
    },
  );
  if (keyText == null || !context.mounted) return;
  try {
    final key = WalletCore.privateKeyFromHex(keyText);
    await appState.unlock(key);
    appState.focusTab(1); // the wallet must visibly appear, not just a message
    if (context.mounted) showInfo(context, 'Wallet imported and unlocked.');
    await showOfferProfileAndVault(context);
  } catch (error) {
    if (context.mounted) showError(context, error);
  }
}

Future<void> _importPhrase(BuildContext context) async {
  // Secure entry: the phrase is built by tapping official BIP-39 words, so
  // the system keyboard/IME never records it. Fall back to paste (also fine:
  // pasted clipboard data never went through the keyboard) via a second
  // action; typing the phrase manually by keyboard is no longer offered.
  var phrase = await showSeedPicker(context, wordCount: 24);
  if (phrase == null) {
    phrase = await showSeedPicker(context, wordCount: 12);
  }
  if (phrase == null || !context.mounted) return;
  final path = await promptText(
    context,
    title: 'Derivation path',
    label: 'Path',
    initialValue: WalletCore.defaultPath,
  );
  if (path == null || !context.mounted) return;
  final passphrase = await promptText(
    context,
    title: 'BIP-39 passphrase',
    label: 'Optional passphrase (hidden)',
    obscure: true,
  );
  if (passphrase == null || !context.mounted) return;
  try {
    final key = WalletCore.derivePrivateKey(
      phrase: phrase,
      passphrase: passphrase,
      path: path,
    );
    await appState.unlock(key, mnemonic: phrase);
    appState.focusTab(1); // the wallet must visibly appear, not just a message
    if (context.mounted) showInfo(context, 'Wallet imported and unlocked.');
    await showOfferProfileAndVault(context);
  } catch (error) {
    if (context.mounted) showError(context, error);
  }
}

Future<void> _importKeystore(BuildContext context) async {
  final json = await promptText(
    context,
    title: 'Import V3 keystore',
    label: 'Keystore JSON',
  );
  if (json == null || !context.mounted) return;
  final password = await promptText(
    context,
    title: 'Keystore password',
    label: 'Password (hidden)',
    obscure: true,
  );
  if (password == null || !context.mounted) return;
  try {
    final key = WalletCore.decryptV3Keystore(json, password);
    await appState.unlock(key);
    appState.focusTab(1); // the wallet must visibly appear, not just a message
    if (context.mounted) showInfo(context, 'Keystore imported and unlocked.');
    await showOfferProfileAndVault(context);
  } catch (error) {
    if (context.mounted) showError(context, error);
  }
}

Future<void> showUnlockVaultDialog(
  BuildContext context, {
  bool jumpToWalletTab = false,
}) async {
  if (!appState.hasVault) {
    await showMessage(
      context,
      'No vault',
      'No encrypted local vault exists yet.',
    );
    return;
  }
  final password = await promptText(
    context,
    title: 'Unlock encrypted vault',
    label: 'Vault password (hidden)',
    obscure: true,
  );
  if (password == null || password.isEmpty || !context.mounted) return;
  List<VaultAccount> accounts;
  try {
    accounts = await appState.loadVaultAccounts(password);
  } catch (error) {
    if (context.mounted) showError(context, error);
    return;
  }
  if (accounts.isEmpty) {
    if (context.mounted)
      showMessage(context, 'Empty vault', 'The vault has no usable accounts.');
    return;
  }
  final index = await showDialog<int>(
    context: context,
    builder: (context) => SimpleDialog(
      title: const Text('Vault accounts'),
      children: [
        for (var i = 0; i < accounts.length; i++)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, i),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(accounts[i].label),
              subtitle: Text(shortAddress(accounts[i].address)),
            ),
          ),
      ],
    ),
  );
  if (index == null || !context.mounted) return;
  try {
    final key = await appState.unlockVaultAccount(password, index);
    await appState.unlock(key);
    // Callers that started away from the wallet (e.g. Home) ask to land on
    // the Wallet tab so the unlocked wallet is plainly on screen.
    if (jumpToWalletTab) appState.focusTab(1);
    // The account is ALREADY in the vault. Offering "save profile / save
    // vault" here (that offer belongs to brand-new imports) blocked the very
    // thing the user came for — the ready screen. Unlock ends here; whatever
    // tab you unlocked from is now live.
    if (context.mounted) showInfo(context, 'Vault account unlocked.');
  } catch (error) {
    if (context.mounted) showError(context, error);
  }
}

Future<void> showOfferProfileAndVault(BuildContext context) async {
  final saveProfile = await confirmDialog(
    context,
    title: 'Save public profile?',
    message: 'Store the label and public address only. No secret is saved.',
    confirmLabel: 'Save',
  );
  if (saveProfile && context.mounted) {
    final label = await promptText(
      context,
      title: 'Profile label',
      label: 'Label',
      initialValue: 'Wallet ${appState.profiles.length + 1}',
    );
    if (label != null && label.isNotEmpty && context.mounted) {
      await appState.addProfile(
        WalletProfile(
          label: label,
          address: appState.address!,
          source: appState.mnemonic != null ? 'phrase' : 'key',
          createdAt: DateTime.now().toIso8601String(),
        ),
      );
    }
  }
  if (!context.mounted) return;
  final saveVault = await confirmDialog(
    context,
    title: 'Save encrypted vault?',
    message: 'Store this account in an Argon2id + XChaCha20-Poly1305 encrypted local vault.',
    confirmLabel: 'Save',
  );
  if (!saveVault || !context.mounted) return;
  final password = await promptText(
    context,
    title: 'Vault password',
    label: 'Password (16+ characters, hidden)',
    obscure: true,
    validator: (value) =>
        value.length >= 16 ? null : 'Use at least 16 characters.',
  );
  if (password == null || password.isEmpty || !context.mounted) return;
  try {
    await appState.saveVaultAccount(
      password,
      label: 'Wallet ${appState.profiles.length + 1}',
      key: appState.privateKey!,
      mnemonic: appState.mnemonic,
    );
    if (context.mounted) showInfo(context, 'Encrypted vault saved.');
  } catch (error) {
    if (context.mounted) showError(context, error);
  }
}
