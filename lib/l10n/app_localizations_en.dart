// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'BNB Wallet';

  @override
  String get home => 'Home';

  @override
  String get send => 'Send';

  @override
  String get receive => 'Receive';

  @override
  String get settings => 'Settings';

  @override
  String get logs => 'Logs';

  @override
  String get about => 'About';

  @override
  String get wallet => 'Wallet';

  @override
  String get balance => 'Balance';

  @override
  String get bnbBalance => 'BNB Balance';

  @override
  String tokenBalance(Object symbol) {
    return '$symbol Balance';
  }

  @override
  String get address => 'Address';

  @override
  String get copyAddress => 'Copy address';

  @override
  String get copySuccess => 'Copied to clipboard';

  @override
  String get qrCode => 'QR Code';

  @override
  String get receiveQR => 'Receive QR';

  @override
  String get sendAmount => 'Amount to send';

  @override
  String get sendTo => 'Send to';

  @override
  String get recipientAddress => 'Recipient address';

  @override
  String get enterAmount => 'Enter amount';

  @override
  String get max => 'Max';

  @override
  String get available => 'Available';

  @override
  String get fee => 'Fee';

  @override
  String get feeTier => 'Fee tier';

  @override
  String get low => 'Low';

  @override
  String get medium => 'Medium (recommended)';

  @override
  String get high => 'High';

  @override
  String get custom => 'Custom';

  @override
  String get estimatedTime => 'Estimated time';

  @override
  String get review => 'Review';

  @override
  String get confirm => 'Confirm';

  @override
  String get holdToConfirm => 'Hold to confirm';

  @override
  String get signing => 'Signing...';

  @override
  String get broadcasting => 'Broadcasting...';

  @override
  String get pending => 'Pending';

  @override
  String get success => 'Success';

  @override
  String get failed => 'Failed';

  @override
  String get transactionHash => 'Transaction hash';

  @override
  String get blockNumber => 'Block number';

  @override
  String get confirmations => 'Confirmations';

  @override
  String get finalized => 'Finalized';

  @override
  String get sendAgain => 'Send again';

  @override
  String get addToContacts => 'Add to contacts';

  @override
  String get copyHash => 'Copy hash';

  @override
  String get copyAll => 'Copy all details';

  @override
  String get shareAsText => 'Share as text';

  @override
  String get exportJson => 'Export JSON';

  @override
  String get exportPng => 'Export PNG';

  @override
  String get openInExplorer => 'Open in explorer';

  @override
  String get warningExplorer => 'This opens an external website. The explorer will see your IP and the transaction you\'re interested in. Continue?';

  @override
  String get settingsNetwork => 'Network';

  @override
  String get settingsNodes => 'Nodes';

  @override
  String get settingsTokens => 'Tokens';

  @override
  String get settingsSecurity => 'Security';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsPrivacy => 'Privacy';

  @override
  String get settingsAutoLock => 'Auto-lock';

  @override
  String get settingsErase => 'Erase everything';

  @override
  String get settingsAbout => 'About';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get themeSystem => 'System default';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeAmoled => 'AMOLED black';

  @override
  String get liteMode => 'Lite mode (no animations)';

  @override
  String get reduceMotion => 'Reduce motion (system)';

  @override
  String get torEnabled => 'Tor enabled';

  @override
  String get torHost => 'Tor host';

  @override
  String get torPort => 'Tor port';

  @override
  String get useCustomProxy => 'Use custom proxy';

  @override
  String get proxyHost => 'Proxy host';

  @override
  String get proxyPort => 'Proxy port';

  @override
  String get proxyUser => 'Proxy username';

  @override
  String get proxyPass => 'Proxy password';

  @override
  String get addNode => 'Add node';

  @override
  String get editNode => 'Edit node';

  @override
  String get nodeName => 'Node name';

  @override
  String get nodeUrl => 'Node URL';

  @override
  String get nodeNetwork => 'Network';

  @override
  String get nodeTransport => 'Transport';

  @override
  String get nodeAuth => 'Authentication';

  @override
  String get authNone => 'None';

  @override
  String get authBearer => 'Bearer token';

  @override
  String get authBasic => 'Basic auth';

  @override
  String get bearerToken => 'Bearer token';

  @override
  String get basicUser => 'Username';

  @override
  String get basicPass => 'Password';

  @override
  String get customHeaders => 'Custom headers';

  @override
  String get pinnedSpki => 'Pinned SPKI hashes (base64, one per line)';

  @override
  String get useForReads => 'Use for reads';

  @override
  String get useForBroadcast => 'Use for broadcast';

  @override
  String get selectionMode => 'Selection mode';

  @override
  String get selectionManual => 'Manual';

  @override
  String get selectionAuto => 'Auto-fastest';

  @override
  String get selectionRandom => 'Round-robin / random';

  @override
  String get selectionQuorum => 'Quorum';

  @override
  String get testNode => 'Test node';

  @override
  String get nodeChecklist => 'Node checklist';

  @override
  String get tokenSources => 'Token contract sources';

  @override
  String get addToken => 'Add token';

  @override
  String get tokenAddress => 'Token contract address';

  @override
  String get tokenSymbol => 'Symbol';

  @override
  String get tokenName => 'Name';

  @override
  String get tokenDecimals => 'Decimals';

  @override
  String get hideToken => 'Hide token';

  @override
  String get showToken => 'Show token';

  @override
  String get backupQuiz => 'Backup quiz';

  @override
  String get verifyPhrase => 'Verify recovery phrase';

  @override
  String get watchOnly => 'Watch-only';

  @override
  String get importWatchOnly => 'Import watch-only address';

  @override
  String get enterAddress => 'Enter address to watch';

  @override
  String get coldMode => 'Cold wallet mode';

  @override
  String get coldModeHot => 'Normal (hot wallet)';

  @override
  String get coldModeCold => 'Cold (offline signer)';

  @override
  String get coldModeOnline => 'Online (watch-only companion)';

  @override
  String get exportForOnline => 'Export for online device';

  @override
  String get importPairing => 'Import pairing data';

  @override
  String get coldHygiene => 'Cold device hygiene';

  @override
  String get airplaneMode => 'Airplane mode';

  @override
  String get wifi => 'Wi-Fi';

  @override
  String get mobileData => 'Mobile data';

  @override
  String get bluetooth => 'Bluetooth';

  @override
  String get nfc => 'NFC';

  @override
  String get networkInterface => 'Network interface';

  @override
  String get battery => 'Battery';

  @override
  String get charging => 'Charging';

  @override
  String get createWallet => 'Create wallet';

  @override
  String get importWallet => 'Import wallet';

  @override
  String get mnemonic => 'Recovery phrase';

  @override
  String get passphrase => 'BIP-39 passphrase (optional)';

  @override
  String get passphraseHint => 'Optional 25th word';

  @override
  String get confirmPhrase => 'Confirm phrase';

  @override
  String enterWords(Object end, Object start) {
    return 'Enter words $start–$end';
  }

  @override
  String get word => 'Word';

  @override
  String get create => 'Create';

  @override
  String get import => 'Import';

  @override
  String get unlock => 'Unlock';

  @override
  String get lock => 'Lock';

  @override
  String get pin => 'PIN';

  @override
  String get biometric => 'Biometric';

  @override
  String get changePin => 'Change PIN';

  @override
  String get enablePin => 'Enable PIN';

  @override
  String get disablePin => 'Disable PIN';

  @override
  String get autoLockSeconds => 'Auto-lock after';

  @override
  String get never => 'Never';

  @override
  String get seconds => 'seconds';

  @override
  String get minutes => 'minutes';

  @override
  String get eraseAllData => 'Erase all data';

  @override
  String get eraseWarning => 'This will delete all wallets, keys, history, logs, and settings. Funds can only be recovered with your recovery phrase.';

  @override
  String get confirmErase => 'Type \'ERASE\' to confirm';

  @override
  String get holdToErase => 'Hold to erase';

  @override
  String get erasing => 'Erasing...';

  @override
  String get erased => 'All data erased';

  @override
  String get logsSimple => 'Simple';

  @override
  String get logsExpert => 'Expert';

  @override
  String get logsFilter => 'Filter';

  @override
  String get logsSearch => 'Search';

  @override
  String get logsExport => 'Export';

  @override
  String get logsClear => 'Clear logs';

  @override
  String get logsWarning => 'Exporting logs may reveal your activity. Continue?';

  @override
  String get logLevelError => 'Error';

  @override
  String get logLevelWarn => 'Warning';

  @override
  String get logLevelInfo => 'Info';

  @override
  String get logLevelDebug => 'Debug';

  @override
  String get logLevelTrace => 'Trace';

  @override
  String get logCategoryVault => 'Vault';

  @override
  String get logCategoryKeys => 'Key operations';

  @override
  String get logCategoryNetwork => 'Network';

  @override
  String get logCategoryTor => 'Tor';

  @override
  String get logCategoryFees => 'Fees';

  @override
  String get logCategoryTx => 'Transactions';

  @override
  String get logCategoryTokens => 'Tokens';

  @override
  String get logCategorySecurity => 'Security';

  @override
  String get journeyMap => 'Journey Map';

  @override
  String get journeyPhone => 'My phone';

  @override
  String get journeyPrivacy => 'Privacy layer';

  @override
  String get journeyNode => 'Node';

  @override
  String get journeyChain => 'BNB Chain';

  @override
  String get journeyDone => 'Done';

  @override
  String get stateWaiting => 'Waiting';

  @override
  String get stateWorking => 'Working';

  @override
  String get stateOk => 'OK';

  @override
  String get stateProblem => 'Problem';

  @override
  String get nodeCard => 'Node';

  @override
  String get nodeLatency => 'Latency';

  @override
  String get nodeLatestBlock => 'Latest block';

  @override
  String get nodeRightChain => 'Right chain';

  @override
  String get nodeCompare => 'Compare another';

  @override
  String get nodeSwitch => 'Switch node';

  @override
  String get receipt => 'Receipt';

  @override
  String get receiptStatus => 'Status';

  @override
  String get receiptFrom => 'From';

  @override
  String get receiptTo => 'To';

  @override
  String get receiptAsset => 'Asset';

  @override
  String get receiptAmount => 'Amount';

  @override
  String get receiptAmountRaw => 'Raw amount';

  @override
  String get receiptNonce => 'Nonce';

  @override
  String get receiptGasLimit => 'Gas limit';

  @override
  String get receiptGasUsed => 'Gas used';

  @override
  String get receiptFee => 'Fee';

  @override
  String get receiptFeeTier => 'Fee tier';

  @override
  String get receiptFeeReason => 'Fee reason';

  @override
  String get receiptTxType => 'Tx type';

  @override
  String get receiptInputData => 'Input data';

  @override
  String get receiptEventLogs => 'Event logs';

  @override
  String get receiptBlockHash => 'Block hash';

  @override
  String get receiptTxIndex => 'Transaction index';

  @override
  String get receiptBalances => 'Balances before / after';

  @override
  String get receiptBefore => 'Before';

  @override
  String get receiptAfter => 'After';

  @override
  String get receiptVerified => 'Verified';

  @override
  String get receiptNodeUsed => 'Node used';

  @override
  String get receiptTransport => 'Transport';

  @override
  String get securityNotice => 'Security notice';

  @override
  String get honestLimits => 'Honest limits';

  @override
  String get version => 'Version';

  @override
  String get license => 'License';

  @override
  String get buildHash => 'Build hash';

  @override
  String get sbom => 'SBOM';

  @override
  String get contact => 'Contact';

  @override
  String get privacyPolicy => 'Privacy policy';

  @override
  String get threatModel => 'Threat model';

  @override
  String get architecture => 'Architecture';

  @override
  String get changelog => 'Changelog';

  @override
  String get contributing => 'Contributing';

  @override
  String get ok => 'OK';

  @override
  String get cancel => 'Cancel';

  @override
  String get close => 'Close';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get add => 'Add';

  @override
  String get remove => 'Remove';

  @override
  String get reset => 'Reset';

  @override
  String get test => 'Test';

  @override
  String get verify => 'Verify';

  @override
  String get copy => 'Copy';

  @override
  String get paste => 'Paste';

  @override
  String get scan => 'Scan';

  @override
  String get warning => 'Warning';

  @override
  String get error => 'Error';

  @override
  String get info => 'Info';

  @override
  String get loading => 'Loading...';

  @override
  String get retry => 'Retry';

  @override
  String get speedUp => 'Speed up';

  @override
  String get cancelTx => 'Cancel';

  @override
  String get replaceTx => 'Replace';

  @override
  String get insufficientBnb => 'Insufficient BNB for gas';

  @override
  String get needBnb => 'You need BNB to pay for gas. Receive some first.';

  @override
  String get addressPoisoning => 'This address resembles a recent contact but differs. Verify carefully.';

  @override
  String get selfContract => 'Sending to the token\'s own contract address will burn tokens.';

  @override
  String get zeroAddress => 'Sending to the zero address is not allowed.';

  @override
  String get newAddress => 'This address has never been used before. Verify it carefully.';

  @override
  String tokenSimulationFailed(Object reason) {
    return 'Simulation failed: $reason';
  }

  @override
  String get tokenUnknown => 'Unknown token';

  @override
  String get unlimitedApproval => 'Unlimited approval — token can spend all your balance';

  @override
  String get signUnknownData => 'Sign unknown data (advanced)';

  @override
  String get enableSignUnknown => 'Enable signing unknown calldata';

  @override
  String get blindSignWarning => 'Blind signing is dangerous. Only enable if you understand the risks.';

  @override
  String get disclosure => 'Disclosure';

  @override
  String get nodeSees => 'The node sees: your IP, the RPC method, and parameters. It can infer address linkages.';

  @override
  String get appDoesNotSend => 'The app does NOT send: device model, OS, app version, language, location, contacts, seed, keys, or passwords.';

  @override
  String get viewRawRequest => 'View raw request';

  @override
  String get copyLog => 'Copy log';

  @override
  String get privacyScreen => 'Network privacy';

  @override
  String get directMode => 'Direct HTTPS';

  @override
  String get torMode => 'Tor (SOCKS5)';

  @override
  String get bridgeMode => 'Tor + bridge';

  @override
  String get proxyMode => 'Custom proxy';

  @override
  String get ispSees => 'Your ISP sees:';

  @override
  String get ispNotSees => 'Your ISP does NOT see:';

  @override
  String get nodeSeesPrivacy => 'The RPC node sees:';

  @override
  String get nodeNotSeesPrivacy => 'The RPC node does NOT see:';

  @override
  String get chainSees => 'The blockchain sees:';

  @override
  String get chainNotSees => 'The blockchain does NOT see:';

  @override
  String get trafficLightGreen => 'Fully private';

  @override
  String get trafficLightYellow => 'Partly private';

  @override
  String get trafficLightRed => 'Blocked / failed';

  @override
  String get bootstrap => 'Bootstrap';

  @override
  String get circuit => 'Circuit';

  @override
  String get hop => 'Hop';

  @override
  String get bridgeType => 'Bridge type';

  @override
  String get killSwitch => 'Kill switch';

  @override
  String get whatCanTheySee => 'What can they see?';

  @override
  String get yourIsp => 'Your internet provider';

  @override
  String get theNode => 'The RPC node';

  @override
  String get everyone => 'Everyone on the blockchain';

  @override
  String get sees => 'Sees';

  @override
  String get cantSee => 'Can\'t see';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageFarsi => 'فارسی';

  @override
  String get languageArabic => 'العربية';

  @override
  String get languageChinese => '中文';

  @override
  String get languageRussian => 'Русский';

  @override
  String get languageSpanish => 'Español';
}
