// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'X Wallet';

  @override
  String get home => 'الرئيسية';

  @override
  String get send => 'إرسال';

  @override
  String get receive => 'استلام';

  @override
  String get settings => 'الإعدادات';

  @override
  String get inspect => 'فحص';

  @override
  String get logs => 'السجلات';

  @override
  String get about => 'حول';

  @override
  String get wallet => 'المحفظة';

  @override
  String get balance => 'الرصيد';

  @override
  String get bnbBalance => 'رصيد BNB';

  @override
  String tokenBalance(Object symbol) {
    return 'رصيد $symbol';
  }

  @override
  String get address => 'العنوان';

  @override
  String get copyAddress => 'نسخ العنوان';

  @override
  String get copySuccess => 'تم النسخ إلى الحافظة';

  @override
  String get qrCode => 'رمز QR';

  @override
  String get receiveQR => 'QR للاستلام';

  @override
  String get sendAmount => 'المبلغ للإرسال';

  @override
  String get sendTo => 'إرسال إلى';

  @override
  String get recipientAddress => 'عنوان المستلم';

  @override
  String get enterAmount => 'أدخل المبلغ';

  @override
  String get max => 'الحد الأقصى';

  @override
  String get available => 'المتاح';

  @override
  String get fee => 'الرسوم';

  @override
  String get feeTier => 'مستوى الرسوم';

  @override
  String get low => 'منخفض';

  @override
  String get medium => 'متوسط (موصى به)';

  @override
  String get high => 'عالي';

  @override
  String get custom => 'مخصص';

  @override
  String get estimatedTime => 'الوقت المقدر';

  @override
  String get review => 'مراجعة';

  @override
  String get confirm => 'تأكيد';

  @override
  String get holdToConfirm => 'اضغط مطولاً للتأكيد';

  @override
  String get signing => 'جاري التوقيع...';

  @override
  String get broadcasting => 'جاري البث...';

  @override
  String get pending => 'معلق';

  @override
  String get success => 'نجاح';

  @override
  String get failed => 'فشل';

  @override
  String get transactionHash => 'هاش المعاملة';

  @override
  String get blockNumber => 'رقم الكتلة';

  @override
  String get confirmations => 'التأكيدات';

  @override
  String get finalized => 'منتهية';

  @override
  String get sendAgain => 'إرسال مرة أخرى';

  @override
  String get addToContacts => 'إضافة إلى جهات الاتصال';

  @override
  String get copyHash => 'نسخ الهاش';

  @override
  String get copyAll => 'نسخ كل التفاصيل';

  @override
  String get shareAsText => 'مشاركة كنص';

  @override
  String get exportJson => 'تصدير JSON';

  @override
  String get exportPng => 'تصدير PNG';

  @override
  String get openInExplorer => 'فتح في المستكشف';

  @override
  String get warningExplorer =>
      'هذا يفتح موقع خارجي. المستكشف سيرى IP والمعاملة. استمر؟';

  @override
  String get settingsNetwork => 'الشبكة';

  @override
  String get settingsNodes => 'العقد';

  @override
  String get settingsTokens => 'الرموز';

  @override
  String get settingsSecurity => 'الأمان';

  @override
  String get settingsAppearance => 'المظهر';

  @override
  String get settingsPrivacy => 'الخصوصية';

  @override
  String get settingsAutoLock => 'القفل التلقائي';

  @override
  String get settingsErase => 'مسح كل شيء';

  @override
  String get settingsAbout => 'حول';

  @override
  String get settingsLanguage => 'اللغة';

  @override
  String get settingsTheme => 'السمة';

  @override
  String get themeSystem => 'افتراضي النظام';

  @override
  String get themeLight => 'فاتح';

  @override
  String get themeDark => 'داكن';

  @override
  String get themeAmoled => 'أسود AMOLED';

  @override
  String get liteMode => 'وضع خفيف (بدون رسوم متحركة)';

  @override
  String get reduceMotion => 'تقليل الحركة (النظام)';

  @override
  String get torEnabled => 'Tor مفعل';

  @override
  String get torHost => 'مضيف Tor';

  @override
  String get torPort => 'منفذ Tor';

  @override
  String get useCustomProxy => 'استخدام بروكسي مخصص';

  @override
  String get proxyHost => 'مضيف البروكسي';

  @override
  String get proxyPort => 'منفذ البروكسي';

  @override
  String get proxyUser => 'مستخدم البروكسي';

  @override
  String get proxyPass => 'كلمة مرور البروكسي';

  @override
  String get addNode => 'إضافة عقدة';

  @override
  String get editNode => 'تعديل عقدة';

  @override
  String get nodeName => 'اسم العقدة';

  @override
  String get nodeUrl => 'رابط العقدة';

  @override
  String get nodeNetwork => 'الشبكة';

  @override
  String get nodeTransport => 'النقل';

  @override
  String get nodeAuth => 'المصادقة';

  @override
  String get authNone => 'لا شيء';

  @override
  String get authBearer => 'رمز Bearer';

  @override
  String get authBasic => 'مصادقة أساسية';

  @override
  String get bearerToken => 'رمز Bearer';

  @override
  String get basicUser => 'اسم المستخدم';

  @override
  String get basicPass => 'كلمة المرور';

  @override
  String get customHeaders => 'رؤوس مخصصة';

  @override
  String get pinnedSpki => 'هاش SPKI مثبت (base64، واحد في السطر)';

  @override
  String get useForReads => 'للقراءة';

  @override
  String get useForBroadcast => 'للبث';

  @override
  String get selectionMode => 'وضع الاختيار';

  @override
  String get selectionManual => 'يدوي';

  @override
  String get selectionAuto => 'أسرع تلقائي';

  @override
  String get selectionRandom => 'تدوير / عشوائي';

  @override
  String get selectionQuorum => 'نصاب';

  @override
  String get testNode => 'اختبار العقدة';

  @override
  String get nodeChecklist => 'قائمة التحقق';

  @override
  String get tokenSources => 'مصادر عقود الرموز';

  @override
  String get addToken => 'إضافة رمز';

  @override
  String get tokenAddress => 'عنوان عقد الرمز';

  @override
  String get tokenSymbol => 'الرمز';

  @override
  String get tokenName => 'الاسم';

  @override
  String get tokenDecimals => 'المنازل العشرية';

  @override
  String get hideToken => 'إخفاء الرمز';

  @override
  String get showToken => 'إظهار الرمز';

  @override
  String get backupQuiz => 'اختبار النسخ الاحتياطي';

  @override
  String get verifyPhrase => 'التحقق من عبارة الاسترداد';

  @override
  String get watchOnly => 'مراقبة فقط';

  @override
  String get importWatchOnly => 'استيراد عنوان للمراقبة';

  @override
  String get enterAddress => 'أدخل العنوان للمراقبة';

  @override
  String get coldMode => 'وضع المحفظة الباردة';

  @override
  String get coldModeHot => 'عادية (محفظة ساخنة)';

  @override
  String get coldModeCold => 'باردة (موقع غير متصل)';

  @override
  String get coldModeOnline => 'متصلة (مرافق مراقبة فقط)';

  @override
  String get exportForOnline => 'تصدير للجهاز المتصل';

  @override
  String get importPairing => 'استيراد بيانات الاقتران';

  @override
  String get coldHygiene => 'نظافة الجهاز البارد';

  @override
  String get airplaneMode => 'وضع الطائرة';

  @override
  String get wifi => 'واي فاي';

  @override
  String get mobileData => 'بيانات الجوال';

  @override
  String get bluetooth => 'بلوتوث';

  @override
  String get nfc => 'NFC';

  @override
  String get networkInterface => 'واجهة الشبكة';

  @override
  String get battery => 'البطارية';

  @override
  String get charging => 'شحن';

  @override
  String get createWallet => 'إنشاء محفظة';

  @override
  String get importWallet => 'استيراد محفظة';

  @override
  String get mnemonic => 'عبارة الاسترداد';

  @override
  String get passphrase => 'عبارة BIP-39 (اختياري)';

  @override
  String get passphraseHint => 'الكلمة 25 اختيارية';

  @override
  String get confirmPhrase => 'تأكيد العبارة';

  @override
  String enterWords(Object end, Object start) {
    return 'أدخل الكلمات $start–$end';
  }

  @override
  String get word => 'كلمة';

  @override
  String get create => 'إنشاء';

  @override
  String get import => 'استيراد';

  @override
  String get unlock => 'فتح القفل';

  @override
  String get lock => 'قفل';

  @override
  String get pin => 'PIN';

  @override
  String get biometric => 'البيومترية';

  @override
  String get changePin => 'تغيير PIN';

  @override
  String get enablePin => 'تفعيل PIN';

  @override
  String get disablePin => 'تعطيل PIN';

  @override
  String get autoLockSeconds => 'قفل تلقائي بعد';

  @override
  String get never => 'أبداً';

  @override
  String get seconds => 'ثواني';

  @override
  String get minutes => 'دقائق';

  @override
  String get eraseAllData => 'مسح جميع البيانات';

  @override
  String get eraseWarning =>
      'سيحذف جميع المحافظ، المفاتيح، التاريخ، السجلات، والإعدادات. الأموال قابلة للاسترداد فقط بعبارة الاسترداد.';

  @override
  String get confirmErase => 'اكتب \'ERASE\' للتأكيد';

  @override
  String get holdToErase => 'اضغط مطولاً للمسح';

  @override
  String get erasing => 'جاري المسح...';

  @override
  String get erased => 'تم مسح جميع البيانات';

  @override
  String get logsSimple => 'بسيط';

  @override
  String get logsExpert => 'خبير';

  @override
  String get logsFilter => 'تصفية';

  @override
  String get logsSearch => 'بحث';

  @override
  String get logsExport => 'تصدير';

  @override
  String get logsClear => 'مسح السجلات';

  @override
  String get logsWarning => 'تصدير السجلات قد يكشف نشاطك. استمر؟';

  @override
  String get logLevelError => 'خطأ';

  @override
  String get logLevelWarn => 'تحذير';

  @override
  String get logLevelInfo => 'معلومات';

  @override
  String get logLevelDebug => 'تصحيح';

  @override
  String get logLevelTrace => 'تتبع';

  @override
  String get logCategoryVault => 'الخزنة';

  @override
  String get logCategoryKeys => 'عمليات المفاتيح';

  @override
  String get logCategoryNetwork => 'الشبكة';

  @override
  String get logCategoryTor => 'Tor';

  @override
  String get logCategoryFees => 'الرسوم';

  @override
  String get logCategoryTx => 'المعاملات';

  @override
  String get logCategoryTokens => 'الرموز';

  @override
  String get logCategorySecurity => 'الأمان';

  @override
  String get journeyMap => 'خريطة الرحلة';

  @override
  String get journeyPhone => 'هاتفي';

  @override
  String get journeyPrivacy => 'طبقة الخصوصية';

  @override
  String get journeyNode => 'العقدة';

  @override
  String get journeyChain => 'الشبكة';

  @override
  String get journeyDone => 'تم';

  @override
  String get stateWaiting => 'انتظار';

  @override
  String get stateWorking => 'جاري العمل';

  @override
  String get stateOk => 'تم';

  @override
  String get stateProblem => 'مشكلة';

  @override
  String get nodeCard => 'العقدة';

  @override
  String get nodeLatency => 'الزمن';

  @override
  String get nodeLatestBlock => 'أحدث كتلة';

  @override
  String get nodeRightChain => 'السلسلة الصحيحة';

  @override
  String get nodeCompare => 'مقارنة أخرى';

  @override
  String get nodeSwitch => 'تغيير العقدة';

  @override
  String get receipt => 'الإيصال';

  @override
  String get receiptStatus => 'الحالة';

  @override
  String get receiptFrom => 'من';

  @override
  String get receiptTo => 'إلى';

  @override
  String get receiptAsset => 'الأصل';

  @override
  String get receiptAmount => 'المبلغ';

  @override
  String get receiptAmountRaw => 'المبلغ الخام';

  @override
  String get receiptNonce => 'النونس';

  @override
  String get receiptGasLimit => 'حد الغاز';

  @override
  String get receiptGasUsed => 'الغاز المستخدم';

  @override
  String get receiptFee => 'الرسوم';

  @override
  String get receiptFeeTier => 'مستوى الرسوم';

  @override
  String get receiptFeeReason => 'سبب الرسوم';

  @override
  String get receiptTxType => 'نوع المعاملة';

  @override
  String get receiptInputData => 'بيانات الإدخال';

  @override
  String get receiptEventLogs => 'سجلات الأحداث';

  @override
  String get receiptBlockHash => 'هاش الكتلة';

  @override
  String get receiptTxIndex => 'فهرس المعاملة';

  @override
  String get receiptBalances => 'الأرصدة قبل / بعد';

  @override
  String get receiptBefore => 'قبل';

  @override
  String get receiptAfter => 'بعد';

  @override
  String get receiptVerified => 'تم التحقق';

  @override
  String get receiptNodeUsed => 'العقدة المستخدمة';

  @override
  String get receiptTransport => 'النقل';

  @override
  String get securityNotice => 'إشعار أمني';

  @override
  String get honestLimits => 'حدود صادقة';

  @override
  String get version => 'الإصدار';

  @override
  String get license => 'الترخيص';

  @override
  String get buildHash => 'هاش البناء';

  @override
  String get sbom => 'SBOM';

  @override
  String get contact => 'اتصال';

  @override
  String get privacyPolicy => 'سياسة الخصوصية';

  @override
  String get threatModel => 'نموذج التهديد';

  @override
  String get architecture => 'الهندسة';

  @override
  String get changelog => 'سجل التغييرات';

  @override
  String get contributing => 'المساهمة';

  @override
  String get ok => 'موافق';

  @override
  String get cancel => 'إلغاء';

  @override
  String get close => 'إغلاق';

  @override
  String get save => 'حفظ';

  @override
  String get delete => 'حذف';

  @override
  String get edit => 'تعديل';

  @override
  String get add => 'إضافة';

  @override
  String get remove => 'إزالة';

  @override
  String get reset => 'إعادة تعيين';

  @override
  String get test => 'اختبار';

  @override
  String get verify => 'تحقق';

  @override
  String get copy => 'نسخ';

  @override
  String get paste => 'لصق';

  @override
  String get scan => 'مسح';

  @override
  String get warning => 'تحذير';

  @override
  String get error => 'خطأ';

  @override
  String get info => 'معلومات';

  @override
  String get loading => 'جاري التحميل...';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get speedUp => 'تسريع';

  @override
  String get cancelTx => 'إلغاء';

  @override
  String get replaceTx => 'استبدال';

  @override
  String get insufficientBnb => 'BNB غير كافٍ للغاز';

  @override
  String get needBnb => 'تحتاج BNB لدفع الغاز. استلم بعضها أولاً.';

  @override
  String get addressPoisoning =>
      'هذا العنوان يشبه جهة اتصال حديثة لكن يختلف. تحقق بعناية.';

  @override
  String get selfContract => 'الإرسال لعنوان عقد الرمز نفسه سيحرق الرموز.';

  @override
  String get zeroAddress => 'الإرسال للعنوان الصفري غير مسموح.';

  @override
  String get newAddress => 'هذا العنوان لم يستخدم من قبل. تحقق بعناية.';

  @override
  String tokenSimulationFailed(Object reason) {
    return 'المحاكاة فشلت: $reason';
  }

  @override
  String get tokenUnknown => 'رمز غير معروف';

  @override
  String get unlimitedApproval =>
      'موافقة غير محدودة — الرمز يمكن أن ينفق كل الرصيد';

  @override
  String get signUnknownData => 'توقيع بيانات غير معروفة (متقدم)';

  @override
  String get enableSignUnknown => 'تمكين توقيع كال داتا غير معروف';

  @override
  String get blindSignWarning =>
      'التوقيع الأعمى خطير. مكن فقط إذا فهمت المخاطر.';

  @override
  String get disclosure => 'إفصاح';

  @override
  String get nodeSees =>
      'العقدة ترى: IP، طريقة RPC، المعلمات. يمكنها استنتاج روابط العناوين.';

  @override
  String get appDoesNotSend =>
      'التطبيق لا يرسل: نموذج الجهاز، نظام التشغيل، نسخة التطبيق، اللغة، الموقع، جهات الاتصال، البذرة، المفاتيح، كلمات المرور.';

  @override
  String get viewRawRequest => 'عرض الطلب الخام';

  @override
  String get copyLog => 'نسخ السجل';

  @override
  String get privacyScreen => 'خصوصية الشبكة';

  @override
  String get directMode => 'HTTPS مباشر';

  @override
  String get torMode => 'Tor (SOCKS5)';

  @override
  String get bridgeMode => 'Tor + جسر';

  @override
  String get proxyMode => 'بروكسي مخصص';

  @override
  String get ispSees => 'مزود الإنترنت يرى:';

  @override
  String get ispNotSees => 'مزود الإنترنت لا يرى:';

  @override
  String get nodeSeesPrivacy => 'عقدة RPC ترى:';

  @override
  String get nodeNotSeesPrivacy => 'عقدة RPC لا ترى:';

  @override
  String get chainSees => 'البلوك تشين يرى:';

  @override
  String get chainNotSees => 'البلوك تشين لا يرى:';

  @override
  String get trafficLightGreen => 'خاص بالكامل';

  @override
  String get trafficLightYellow => 'خاص جزئياً';

  @override
  String get trafficLightRed => 'محظور / فشل';

  @override
  String get bootstrap => 'التمهيد';

  @override
  String get circuit => 'الدائرة';

  @override
  String get hop => 'القفزة';

  @override
  String get bridgeType => 'نوع الجسر';

  @override
  String get killSwitch => 'مفتاح القتل';

  @override
  String get whatCanTheySee => 'ماذا يمكن أن يروا؟';

  @override
  String get yourIsp => 'مزود الإنترنت';

  @override
  String get theNode => 'عقدة RPC';

  @override
  String get everyone => 'الجميع على البلوك تشين';

  @override
  String get sees => 'يرى';

  @override
  String get cantSee => 'لا يرى';

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
