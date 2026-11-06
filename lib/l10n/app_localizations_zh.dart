// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'BNB 钱包';

  @override
  String get home => '首页';

  @override
  String get send => '发送';

  @override
  String get receive => '接收';

  @override
  String get settings => '设置';

  @override
  String get inspect => '检查';

  @override
  String get logs => '日志';

  @override
  String get about => '关于';

  @override
  String get wallet => '钱包';

  @override
  String get balance => '余额';

  @override
  String get bnbBalance => 'BNB 余额';

  @override
  String tokenBalance(Object symbol) {
    return '$symbol 余额';
  }

  @override
  String get address => '地址';

  @override
  String get copyAddress => '复制地址';

  @override
  String get copySuccess => '已复制到剪贴板';

  @override
  String get qrCode => '二维码';

  @override
  String get receiveQR => '收款二维码';

  @override
  String get sendAmount => '发送金额';

  @override
  String get sendTo => '发送到';

  @override
  String get recipientAddress => '接收地址';

  @override
  String get enterAmount => '输入金额';

  @override
  String get max => '最大';

  @override
  String get available => '可用';

  @override
  String get fee => '手续费';

  @override
  String get feeTier => '手续费档位';

  @override
  String get low => '低';

  @override
  String get medium => '中 (推荐)';

  @override
  String get high => '高';

  @override
  String get custom => '自定义';

  @override
  String get estimatedTime => '预计时间';

  @override
  String get review => '确认';

  @override
  String get confirm => '确认';

  @override
  String get holdToConfirm => '长按确认';

  @override
  String get signing => '签名中...';

  @override
  String get broadcasting => '广播中...';

  @override
  String get pending => '待确认';

  @override
  String get success => '成功';

  @override
  String get failed => '失败';

  @override
  String get transactionHash => '交易哈希';

  @override
  String get blockNumber => '区块号';

  @override
  String get confirmations => '确认数';

  @override
  String get finalized => '已确定';

  @override
  String get sendAgain => '再次发送';

  @override
  String get addToContacts => '添加到联系人';

  @override
  String get copyHash => '复制哈希';

  @override
  String get copyAll => '复制所有详情';

  @override
  String get shareAsText => '分享为文本';

  @override
  String get exportJson => '导出 JSON';

  @override
  String get exportPng => '导出 PNG';

  @override
  String get openInExplorer => '在浏览器打开';

  @override
  String get warningExplorer => '这会打开外部网站。浏览器将看到您的 IP 和关注的交易。继续？';

  @override
  String get settingsNetwork => '网络';

  @override
  String get settingsNodes => '节点';

  @override
  String get settingsTokens => '代币';

  @override
  String get settingsSecurity => '安全';

  @override
  String get settingsAppearance => '外观';

  @override
  String get settingsPrivacy => '隐私';

  @override
  String get settingsAutoLock => '自动锁定';

  @override
  String get settingsErase => '擦除所有';

  @override
  String get settingsAbout => '关于';

  @override
  String get settingsLanguage => '语言';

  @override
  String get settingsTheme => '主题';

  @override
  String get themeSystem => '跟随系统';

  @override
  String get themeLight => '浅色';

  @override
  String get themeDark => '深色';

  @override
  String get themeAmoled => 'AMOLED 黑';

  @override
  String get liteMode => '轻量模式 (无动画)';

  @override
  String get reduceMotion => '减少动画 (系统)';

  @override
  String get torEnabled => '启用 Tor';

  @override
  String get torHost => 'Tor 主机';

  @override
  String get torPort => 'Tor 端口';

  @override
  String get useCustomProxy => '使用自定义代理';

  @override
  String get proxyHost => '代理主机';

  @override
  String get proxyPort => '代理端口';

  @override
  String get proxyUser => '代理用户';

  @override
  String get proxyPass => '代理密码';

  @override
  String get addNode => '添加节点';

  @override
  String get editNode => '编辑节点';

  @override
  String get nodeName => '节点名称';

  @override
  String get nodeUrl => '节点 URL';

  @override
  String get nodeNetwork => '网络';

  @override
  String get nodeTransport => '传输';

  @override
  String get nodeAuth => '认证';

  @override
  String get authNone => '无';

  @override
  String get authBearer => 'Bearer 令牌';

  @override
  String get authBasic => '基本认证';

  @override
  String get bearerToken => 'Bearer 令牌';

  @override
  String get basicUser => '用户名';

  @override
  String get basicPass => '密码';

  @override
  String get customHeaders => '自定义头';

  @override
  String get pinnedSpki => '固定 SPKI 哈希 (base64，每行一个)';

  @override
  String get useForReads => '用于读取';

  @override
  String get useForBroadcast => '用于广播';

  @override
  String get selectionMode => '选择模式';

  @override
  String get selectionManual => '手动';

  @override
  String get selectionAuto => '自动最快';

  @override
  String get selectionRandom => '轮询 / 随机';

  @override
  String get selectionQuorum => '仲裁';

  @override
  String get testNode => '测试节点';

  @override
  String get nodeChecklist => '节点检查';

  @override
  String get tokenSources => '代币合约来源';

  @override
  String get addToken => '添加代币';

  @override
  String get tokenAddress => '代币合约地址';

  @override
  String get tokenSymbol => '符号';

  @override
  String get tokenName => '名称';

  @override
  String get tokenDecimals => '小数位';

  @override
  String get hideToken => '隐藏代币';

  @override
  String get showToken => '显示代币';

  @override
  String get backupQuiz => '备份测验';

  @override
  String get verifyPhrase => '验证恢复短语';

  @override
  String get watchOnly => '只读';

  @override
  String get importWatchOnly => '导入只读地址';

  @override
  String get enterAddress => '输入要监视的地址';

  @override
  String get coldMode => '冷钱包模式';

  @override
  String get coldModeHot => '普通 (热钱包)';

  @override
  String get coldModeCold => '冷 (离线签名)';

  @override
  String get coldModeOnline => '在线 (只读伴侣)';

  @override
  String get exportForOnline => '导出给在线设备';

  @override
  String get importPairing => '导入配对数据';

  @override
  String get coldHygiene => '冷设备卫生';

  @override
  String get airplaneMode => '飞行模式';

  @override
  String get wifi => 'Wi-Fi';

  @override
  String get mobileData => '移动数据';

  @override
  String get bluetooth => '蓝牙';

  @override
  String get nfc => 'NFC';

  @override
  String get networkInterface => '网络接口';

  @override
  String get battery => '电池';

  @override
  String get charging => '充电中';

  @override
  String get createWallet => '创建钱包';

  @override
  String get importWallet => '导入钱包';

  @override
  String get mnemonic => '恢复短语';

  @override
  String get passphrase => 'BIP-39 密语 (可选)';

  @override
  String get passphraseHint => '可选第 25 个词';

  @override
  String get confirmPhrase => '确认短语';

  @override
  String enterWords(Object end, Object start) {
    return '输入单词 $start–$end';
  }

  @override
  String get word => '单词';

  @override
  String get create => '创建';

  @override
  String get import => '导入';

  @override
  String get unlock => '解锁';

  @override
  String get lock => '锁定';

  @override
  String get pin => 'PIN';

  @override
  String get biometric => '生物识别';

  @override
  String get changePin => '更改 PIN';

  @override
  String get enablePin => '启用 PIN';

  @override
  String get disablePin => '禁用 PIN';

  @override
  String get autoLockSeconds => '自动锁定';

  @override
  String get never => '从不';

  @override
  String get seconds => '秒';

  @override
  String get minutes => '分钟';

  @override
  String get eraseAllData => '擦除所有数据';

  @override
  String get eraseWarning => '将删除所有钱包、密钥、历史、日志和设置。资金只能通过恢复短语找回。';

  @override
  String get confirmErase => '输入 \'ERASE\' 确认';

  @override
  String get holdToErase => '长按擦除';

  @override
  String get erasing => '擦除中...';

  @override
  String get erased => '所有数据已擦除';

  @override
  String get logsSimple => '简单';

  @override
  String get logsExpert => '专家';

  @override
  String get logsFilter => '筛选';

  @override
  String get logsSearch => '搜索';

  @override
  String get logsExport => '导出';

  @override
  String get logsClear => '清除日志';

  @override
  String get logsWarning => '导出日志可能泄露您的活动。继续？';

  @override
  String get logLevelError => '错误';

  @override
  String get logLevelWarn => '警告';

  @override
  String get logLevelInfo => '信息';

  @override
  String get logLevelDebug => '调试';

  @override
  String get logLevelTrace => '追踪';

  @override
  String get logCategoryVault => '保险库';

  @override
  String get logCategoryKeys => '密钥操作';

  @override
  String get logCategoryNetwork => '网络';

  @override
  String get logCategoryTor => 'Tor';

  @override
  String get logCategoryFees => '手续费';

  @override
  String get logCategoryTx => '交易';

  @override
  String get logCategoryTokens => '代币';

  @override
  String get logCategorySecurity => '安全';

  @override
  String get journeyMap => '旅程地图';

  @override
  String get journeyPhone => '我的手机';

  @override
  String get journeyPrivacy => '隐私层';

  @override
  String get journeyNode => '节点';

  @override
  String get journeyChain => 'BNB 链';

  @override
  String get journeyDone => '完成';

  @override
  String get stateWaiting => '等待';

  @override
  String get stateWorking => '进行中';

  @override
  String get stateOk => '正常';

  @override
  String get stateProblem => '问题';

  @override
  String get nodeCard => '节点';

  @override
  String get nodeLatency => '延迟';

  @override
  String get nodeLatestBlock => '最新区块';

  @override
  String get nodeRightChain => '正确链';

  @override
  String get nodeCompare => '对比其他';

  @override
  String get nodeSwitch => '切换节点';

  @override
  String get receipt => '收据';

  @override
  String get receiptStatus => '状态';

  @override
  String get receiptFrom => '发送方';

  @override
  String get receiptTo => '接收方';

  @override
  String get receiptAsset => '资产';

  @override
  String get receiptAmount => '金额';

  @override
  String get receiptAmountRaw => '原始金额';

  @override
  String get receiptNonce => 'Nonce';

  @override
  String get receiptGasLimit => 'Gas 限制';

  @override
  String get receiptGasUsed => 'Gas 已用';

  @override
  String get receiptFee => '手续费';

  @override
  String get receiptFeeTier => '费用档位';

  @override
  String get receiptFeeReason => '费用原因';

  @override
  String get receiptTxType => '交易类型';

  @override
  String get receiptInputData => '输入数据';

  @override
  String get receiptEventLogs => '事件日志';

  @override
  String get receiptBlockHash => '区块哈希';

  @override
  String get receiptTxIndex => '交易索引';

  @override
  String get receiptBalances => '前后余额';

  @override
  String get receiptBefore => '之前';

  @override
  String get receiptAfter => '之后';

  @override
  String get receiptVerified => '已验证';

  @override
  String get receiptNodeUsed => '使用的节点';

  @override
  String get receiptTransport => '传输';

  @override
  String get securityNotice => '安全须知';

  @override
  String get honestLimits => '诚实限制';

  @override
  String get version => '版本';

  @override
  String get license => '许可证';

  @override
  String get buildHash => '构建哈希';

  @override
  String get sbom => 'SBOM';

  @override
  String get contact => '联系';

  @override
  String get privacyPolicy => '隐私政策';

  @override
  String get threatModel => '威胁模型';

  @override
  String get architecture => '架构';

  @override
  String get changelog => '更新日志';

  @override
  String get contributing => '贡献';

  @override
  String get ok => '确定';

  @override
  String get cancel => '取消';

  @override
  String get close => '关闭';

  @override
  String get save => '保存';

  @override
  String get delete => '删除';

  @override
  String get edit => '编辑';

  @override
  String get add => '添加';

  @override
  String get remove => '移除';

  @override
  String get reset => '重置';

  @override
  String get test => '测试';

  @override
  String get verify => '验证';

  @override
  String get copy => '复制';

  @override
  String get paste => '粘贴';

  @override
  String get scan => '扫描';

  @override
  String get warning => '警告';

  @override
  String get error => '错误';

  @override
  String get info => '信息';

  @override
  String get loading => '加载中...';

  @override
  String get retry => '重试';

  @override
  String get speedUp => '加速';

  @override
  String get cancelTx => '取消';

  @override
  String get replaceTx => '替换';

  @override
  String get insufficientBnb => 'BNB 不足以支付 Gas';

  @override
  String get needBnb => '需要 BNB 支付 Gas。请先接收一些。';

  @override
  String get addressPoisoning => '此地址类似最近联系人但不同。请仔细核实。';

  @override
  String get selfContract => '发送到代币自身合约地址会销毁代币。';

  @override
  String get zeroAddress => '不允许发送到零地址。';

  @override
  String get newAddress => '此地址从未使用过。请仔细核实。';

  @override
  String tokenSimulationFailed(Object reason) {
    return '模拟失败: $reason';
  }

  @override
  String get tokenUnknown => '未知代币';

  @override
  String get unlimitedApproval => '无限授权 — 代币可花费所有余额';

  @override
  String get signUnknownData => '签名未知数据 (高级)';

  @override
  String get enableSignUnknown => '启用签名未知 calldata';

  @override
  String get blindSignWarning => '盲签危险。仅在理解风险时启用。';

  @override
  String get disclosure => '披露';

  @override
  String get nodeSees => '节点看到: 您的 IP、RPC 方法和参数。可推断地址关联。';

  @override
  String get appDoesNotSend => '应用不发送: 设备型号、操作系统、应用版本、语言、位置、联系人、种子、密钥、密码。';

  @override
  String get viewRawRequest => '查看原始请求';

  @override
  String get copyLog => '复制日志';

  @override
  String get privacyScreen => '网络隐私';

  @override
  String get directMode => '直接 HTTPS';

  @override
  String get torMode => 'Tor (SOCKS5)';

  @override
  String get bridgeMode => 'Tor + 网桥';

  @override
  String get proxyMode => '自定义代理';

  @override
  String get ispSees => 'ISP 看到:';

  @override
  String get ispNotSees => 'ISP 看不到:';

  @override
  String get nodeSeesPrivacy => 'RPC 节点看到:';

  @override
  String get nodeNotSeesPrivacy => 'RPC 节点看不到:';

  @override
  String get chainSees => '区块链看到:';

  @override
  String get chainNotSees => '区块链看不到:';

  @override
  String get trafficLightGreen => '完全私密';

  @override
  String get trafficLightYellow => '部分私密';

  @override
  String get trafficLightRed => '阻塞 / 失败';

  @override
  String get bootstrap => '引导';

  @override
  String get circuit => '电路';

  @override
  String get hop => '跳数';

  @override
  String get bridgeType => '网桥类型';

  @override
  String get killSwitch => '熔断开关';

  @override
  String get whatCanTheySee => '他们能看到什么?';

  @override
  String get yourIsp => '您的 ISP';

  @override
  String get theNode => 'RPC 节点';

  @override
  String get everyone => '区块链上的所有人';

  @override
  String get sees => '看到';

  @override
  String get cantSee => '看不到';

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
