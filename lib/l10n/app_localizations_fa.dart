// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Persian (`fa`).
class AppLocalizationsFa extends AppLocalizations {
  AppLocalizationsFa([String locale = 'fa']) : super(locale);

  @override
  String get appTitle => 'X Wallet';

  @override
  String get home => 'خانه';

  @override
  String get send => 'ارسال';

  @override
  String get receive => 'دریافت';

  @override
  String get settings => 'تنظیمات';

  @override
  String get inspect => 'بررسی';

  @override
  String get logs => 'لاگ‌ها';

  @override
  String get about => 'درباره';

  @override
  String get wallet => 'کیف پول';

  @override
  String get balance => 'موجودی';

  @override
  String get bnbBalance => 'موجودی BNB';

  @override
  String tokenBalance(Object symbol) {
    return 'موجودی $symbol';
  }

  @override
  String get address => 'آدرس';

  @override
  String get copyAddress => 'کپی آدرس';

  @override
  String get copySuccess => 'در کلیپ‌بورد کپی شد';

  @override
  String get qrCode => 'کد QR';

  @override
  String get receiveQR => 'QR دریافت';

  @override
  String get sendAmount => 'مبلغ ارسال';

  @override
  String get sendTo => 'ارسال به';

  @override
  String get recipientAddress => 'آدرس گیرنده';

  @override
  String get enterAmount => 'مبلغ را وارد کنید';

  @override
  String get max => 'حداکثر';

  @override
  String get available => 'موجود';

  @override
  String get fee => 'کارمزد';

  @override
  String get feeTier => 'سطح کارمزد';

  @override
  String get low => 'کم';

  @override
  String get medium => 'متوسط (پیشنهادی)';

  @override
  String get high => 'زیاد';

  @override
  String get custom => 'سفارشی';

  @override
  String get estimatedTime => 'زمان تخمینی';

  @override
  String get review => 'بازبینی';

  @override
  String get confirm => 'تأیید';

  @override
  String get holdToConfirm => 'برای تأیید نگه دارید';

  @override
  String get signing => 'در حال امضا...';

  @override
  String get broadcasting => 'در حال انتشار...';

  @override
  String get pending => 'در انتظار';

  @override
  String get success => 'موفقیت';

  @override
  String get failed => 'ناموفق';

  @override
  String get transactionHash => 'هش تراکنش';

  @override
  String get blockNumber => 'شماره بلاک';

  @override
  String get confirmations => 'تأییدها';

  @override
  String get finalized => 'نهایی';

  @override
  String get sendAgain => 'ارسال مجدد';

  @override
  String get addToContacts => 'افزودن به مخاطبین';

  @override
  String get copyHash => 'کپی هش';

  @override
  String get copyAll => 'کپی تمام جزئیات';

  @override
  String get shareAsText => 'اشتراک‌گذاری به صورت متن';

  @override
  String get exportJson => 'صادرات JSON';

  @override
  String get exportPng => 'صادرات PNG';

  @override
  String get openInExplorer => 'باز کردن در اکسپلورر';

  @override
  String get warningExplorer =>
      'این یک وب‌سایت خارجی را باز می‌کند. اکسپلورر IP و تراکنش شما را می‌بیند. ادامه دهید؟';

  @override
  String get settingsNetwork => 'شبکه';

  @override
  String get settingsNodes => 'نودها';

  @override
  String get settingsTokens => 'توکن‌ها';

  @override
  String get settingsSecurity => 'امنیت';

  @override
  String get settingsAppearance => 'ظاهر';

  @override
  String get settingsPrivacy => 'حریم خصوصی';

  @override
  String get settingsAutoLock => 'قفل خودکار';

  @override
  String get settingsErase => 'حذف همه چیز';

  @override
  String get settingsAbout => 'درباره';

  @override
  String get settingsLanguage => 'زبان';

  @override
  String get settingsTheme => 'تم';

  @override
  String get themeSystem => 'پیش‌فرض سیستم';

  @override
  String get themeLight => 'روشن';

  @override
  String get themeDark => 'تیره';

  @override
  String get themeAmoled => 'سیاه AMOLED';

  @override
  String get liteMode => 'حالت سبک (بدون انیمیشن)';

  @override
  String get reduceMotion => 'کاهش حرکت (سیستم)';

  @override
  String get torEnabled => 'تور فعال';

  @override
  String get torHost => 'هاست تور';

  @override
  String get torPort => 'پورت تور';

  @override
  String get useCustomProxy => 'استفاده از پروکسی سفارشی';

  @override
  String get proxyHost => 'هاست پروکسی';

  @override
  String get proxyPort => 'پورت پروکسی';

  @override
  String get proxyUser => 'نام کاربری پروکسی';

  @override
  String get proxyPass => 'رمز عبور پروکسی';

  @override
  String get addNode => 'افزودن نود';

  @override
  String get editNode => 'ویرایش نود';

  @override
  String get nodeName => 'نام نود';

  @override
  String get nodeUrl => 'آدرس نود';

  @override
  String get nodeNetwork => 'شبکه';

  @override
  String get nodeTransport => 'ترانسبورت';

  @override
  String get nodeAuth => 'احراز هویت';

  @override
  String get authNone => 'هیچ';

  @override
  String get authBearer => 'توکن Bearer';

  @override
  String get authBasic => 'Basic Auth';

  @override
  String get bearerToken => 'توکن Bearer';

  @override
  String get basicUser => 'نام کاربری';

  @override
  String get basicPass => 'رمز عبور';

  @override
  String get customHeaders => 'هدارهای سفارشی';

  @override
  String get pinnedSpki => 'هش SPKI پین شده (base64، یکی در خط)';

  @override
  String get useForReads => 'استفاده برای خواندن';

  @override
  String get useForBroadcast => 'استفاده برای پخش';

  @override
  String get selectionMode => 'حالت انتخاب';

  @override
  String get selectionManual => 'دستی';

  @override
  String get selectionAuto => 'سریع‌ترین';

  @override
  String get selectionRandom => 'Round-robin / تصادفی';

  @override
  String get selectionQuorum => 'کворم';

  @override
  String get testNode => 'تست نود';

  @override
  String get nodeChecklist => 'چک‌لیست نود';

  @override
  String get tokenSources => 'منابع قراردادها توکن';

  @override
  String get addToken => 'افزودن توکن';

  @override
  String get tokenAddress => 'آدرس قرارداد توکن';

  @override
  String get tokenSymbol => 'نماد';

  @override
  String get tokenName => 'نام';

  @override
  String get tokenDecimals => 'اعشار';

  @override
  String get hideToken => 'مخفی کردن توکن';

  @override
  String get showToken => 'نمایش توکن';

  @override
  String get backupQuiz => 'کوییز بکاپ';

  @override
  String get verifyPhrase => 'تأیید عبارت بازیابی';

  @override
  String get watchOnly => 'فقط نظاره';

  @override
  String get importWatchOnly => 'وارد کردن آدرس نظاره';

  @override
  String get enterAddress => 'آدرس برای نظاره';

  @override
  String get coldMode => 'حالت کیف پول سرد';

  @override
  String get coldModeHot => 'عادی (کیف پول داغ)';

  @override
  String get coldModeCold => 'سرد (امضا کننده آفلاین)';

  @override
  String get coldModeOnline => 'آنلاین (همراه فقط نظاره)';

  @override
  String get exportForOnline => 'صادرات برای دستگاه آنلاین';

  @override
  String get importPairing => 'وارد کردن داده جفت‌سازی';

  @override
  String get coldHygiene => 'بهداشت دستگاه سرد';

  @override
  String get airplaneMode => 'حالت پروازی';

  @override
  String get wifi => 'وای‌فای';

  @override
  String get mobileData => 'دیتای موبایل';

  @override
  String get bluetooth => 'بلوتوث';

  @override
  String get nfc => 'NFC';

  @override
  String get networkInterface => 'اینترفیس شبکه';

  @override
  String get battery => 'باتری';

  @override
  String get charging => 'در حال شارژ';

  @override
  String get createWallet => 'ساخت کیف پول';

  @override
  String get importWallet => 'وارد کردن کیف پول';

  @override
  String get mnemonic => 'عبارت بازیابی';

  @override
  String get passphrase => 'عبارت BIP-39 (اختیاری)';

  @override
  String get passphraseHint => 'کلمه ۲۵ اختیاری';

  @override
  String get confirmPhrase => 'تأیید عبارت';

  @override
  String enterWords(Object end, Object start) {
    return 'کلمات $start–$end را وارد کنید';
  }

  @override
  String get word => 'کلمه';

  @override
  String get create => 'ساخت';

  @override
  String get import => 'وارد کردن';

  @override
  String get unlock => 'باز کردن قفل';

  @override
  String get lock => 'قفل';

  @override
  String get pin => 'پین';

  @override
  String get biometric => 'بیومتریک';

  @override
  String get changePin => 'تغییر پین';

  @override
  String get enablePin => 'فعال کردن پین';

  @override
  String get disablePin => 'غیرفعال کردن پین';

  @override
  String get autoLockSeconds => 'قفل خودکار بعد از';

  @override
  String get never => 'هرگز';

  @override
  String get seconds => 'ثانیه';

  @override
  String get minutes => 'دقیقه';

  @override
  String get eraseAllData => 'حذف تمام داده‌ها';

  @override
  String get eraseWarning =>
      'این تمام کیف پول‌ها، کلیدها، تاریخچه، لاگ‌ها و تنظیمات را حذف می‌کند. وجه‌ها فقط با عبارت بازیابی قابل بازیابی هستند.';

  @override
  String get confirmErase => 'برای تأیید \'ERASE\' تایپ کنید';

  @override
  String get holdToErase => 'برای حذف نگه دارید';

  @override
  String get erasing => 'در حال حذف...';

  @override
  String get erased => 'تمام داده‌ها حذف شد';

  @override
  String get logsSimple => 'ساده';

  @override
  String get logsExpert => 'حرفه‌ای';

  @override
  String get logsFilter => 'فیلتر';

  @override
  String get logsSearch => 'جستجو';

  @override
  String get logsExport => 'صادرات';

  @override
  String get logsClear => 'پاک کردن لاگ‌ها';

  @override
  String get logsWarning =>
      'صادرات لاگ‌ها می‌تواند فعالیت شما را فاش کند. ادامه دهید؟';

  @override
  String get logLevelError => 'خطا';

  @override
  String get logLevelWarn => 'هشدار';

  @override
  String get logLevelInfo => 'اطلاعات';

  @override
  String get logLevelDebug => 'دیباگ';

  @override
  String get logLevelTrace => 'تریس';

  @override
  String get logCategoryVault => 'والت';

  @override
  String get logCategoryKeys => 'عملیات کلید';

  @override
  String get logCategoryNetwork => 'شبکه';

  @override
  String get logCategoryTor => 'تور';

  @override
  String get logCategoryFees => 'کارمزدها';

  @override
  String get logCategoryTx => 'تراکنش‌ها';

  @override
  String get logCategoryTokens => 'توکن‌ها';

  @override
  String get logCategorySecurity => 'امنیت';

  @override
  String get journeyMap => 'نقشه سفر';

  @override
  String get journeyPhone => 'تلفن من';

  @override
  String get journeyPrivacy => 'لایه حریم خصوصی';

  @override
  String get journeyNode => 'نود';

  @override
  String get journeyChain => 'شبکه';

  @override
  String get journeyDone => 'انجام شد';

  @override
  String get stateWaiting => 'در انتظار';

  @override
  String get stateWorking => 'در حال کار';

  @override
  String get stateOk => 'اُکی';

  @override
  String get stateProblem => 'مشکل';

  @override
  String get nodeCard => 'نود';

  @override
  String get nodeLatency => 'تاخیر';

  @override
  String get nodeLatestBlock => 'آخرین بلاک';

  @override
  String get nodeRightChain => 'بلاکچین درست';

  @override
  String get nodeCompare => 'مقایسه دیگری';

  @override
  String get nodeSwitch => 'تغییر نود';

  @override
  String get receipt => 'رسید';

  @override
  String get receiptStatus => 'وضعیت';

  @override
  String get receiptFrom => 'از';

  @override
  String get receiptTo => 'به';

  @override
  String get receiptAsset => 'دارایی';

  @override
  String get receiptAmount => 'مبلغ';

  @override
  String get receiptAmountRaw => 'مبلغ خام';

  @override
  String get receiptNonce => 'نونس';

  @override
  String get receiptGasLimit => 'محدودیت گس';

  @override
  String get receiptGasUsed => 'گس مصرفی';

  @override
  String get receiptFee => 'کارمزد';

  @override
  String get receiptFeeTier => 'سطح کارمزد';

  @override
  String get receiptFeeReason => 'دلیل کارمزد';

  @override
  String get receiptTxType => 'نوع تراکنش';

  @override
  String get receiptInputData => 'داده ورودی';

  @override
  String get receiptEventLogs => 'لاگ‌های رویداد';

  @override
  String get receiptBlockHash => 'هش بلاک';

  @override
  String get receiptTxIndex => 'شاخص تراکنش';

  @override
  String get receiptBalances => 'موجودی قبل / بعد';

  @override
  String get receiptBefore => 'قبل';

  @override
  String get receiptAfter => 'بعد';

  @override
  String get receiptVerified => 'تأیید شده';

  @override
  String get receiptNodeUsed => 'نود استفاده شده';

  @override
  String get receiptTransport => 'ترانسبورت';

  @override
  String get securityNotice => 'اطلاعیه امنیتی';

  @override
  String get honestLimits => 'محدودیت‌های صادقانه';

  @override
  String get version => 'نسخه';

  @override
  String get license => 'لایسنس';

  @override
  String get buildHash => 'هش بیلد';

  @override
  String get sbom => 'SBOM';

  @override
  String get contact => 'تماس';

  @override
  String get privacyPolicy => 'سیاست حریم خصوصی';

  @override
  String get threatModel => 'مدل تهدید';

  @override
  String get architecture => 'معماری';

  @override
  String get changelog => 'تغییرات';

  @override
  String get contributing => 'مشارکت';

  @override
  String get ok => 'تأیید';

  @override
  String get cancel => 'لغو';

  @override
  String get close => 'بستن';

  @override
  String get save => 'ذخیره';

  @override
  String get delete => 'حذف';

  @override
  String get edit => 'ویرایش';

  @override
  String get add => 'افزودن';

  @override
  String get remove => 'حذف';

  @override
  String get reset => 'بازنشانی';

  @override
  String get test => 'تست';

  @override
  String get verify => 'تأیید';

  @override
  String get copy => 'کپی';

  @override
  String get paste => 'چسباندن';

  @override
  String get scan => 'اسکن';

  @override
  String get warning => 'هشدار';

  @override
  String get error => 'خطا';

  @override
  String get info => 'اطلاعات';

  @override
  String get loading => 'در حال بارگذاری...';

  @override
  String get retry => 'تلاش مجدد';

  @override
  String get speedUp => 'اسپیید اپ';

  @override
  String get cancelTx => 'لغو';

  @override
  String get replaceTx => 'جایگزینی';

  @override
  String get insufficientBnb => 'BNB ناکافی برای گس';

  @override
  String get needBnb => 'برای پرداخت گس BNB نیاز دارید. ابتدا بگیرید.';

  @override
  String get addressPoisoning =>
      'این آدرس شبیه یک مخاطب اخیر است اما متفاوت است. با دقت تأیید کنید.';

  @override
  String get selfContract =>
      'ارسال به آدرس قرارداد خود توکن، توکن‌ها را سوختن می‌کند.';

  @override
  String get zeroAddress => 'ارسال به آدرس صفر مجاز نیست.';

  @override
  String get newAddress => 'این آدرس هرگز استفاده نشده است. با دقت تأیید کنید.';

  @override
  String tokenSimulationFailed(Object reason) {
    return 'شبیه‌سازی ناموفق: $reason';
  }

  @override
  String get tokenUnknown => 'توکن ناشناس';

  @override
  String get unlimitedApproval =>
      'تأیید نامحدود — توکن می‌تواند تمام موجودی را خرج کند';

  @override
  String get signUnknownData => 'امضای داده ناشناس (پیشرفته)';

  @override
  String get enableSignUnknown => 'فعال کردن امضای کال‌دیتا ناشناس';

  @override
  String get blindSignWarning =>
      'امضای کورانه خطرناک است. فقط در صورت درک ریسک فعال کنید.';

  @override
  String get disclosure => 'افشا';

  @override
  String get nodeSees =>
      'نود می‌بیند: IP شما، متد RPC و پارامترها. می‌تواند پیوند آدرس‌ها را حدس بزند.';

  @override
  String get appDoesNotSend =>
      'برنامه ارسال نمی‌کند: مدل دستگاه، سیستم‌عامل، نسخه برنامه، زبان، موقعیت، مخاطبین، بذر، کلیدها، رمزها.';

  @override
  String get viewRawRequest => 'مشاهده درخواست خام';

  @override
  String get copyLog => 'کپی لاگ';

  @override
  String get privacyScreen => 'حریم خصوصی شبکه';

  @override
  String get directMode => 'HTTPS مستقیم';

  @override
  String get torMode => 'تور (SOCKS5)';

  @override
  String get bridgeMode => 'تور + پل';

  @override
  String get proxyMode => 'پروکسی سفارشی';

  @override
  String get ispSees => 'ارائه‌دهنده اینترنت می‌بیند:';

  @override
  String get ispNotSees => 'ارائه‌دهنده اینترنت نمی‌بیند:';

  @override
  String get nodeSeesPrivacy => 'نود RPC می‌بیند:';

  @override
  String get nodeNotSeesPrivacy => 'نود RPC نمی‌بیند:';

  @override
  String get chainSees => 'بلاکچین می‌بیند:';

  @override
  String get chainNotSees => 'بلاکچین نمی‌بیند:';

  @override
  String get trafficLightGreen => 'کاملاً خصوصی';

  @override
  String get trafficLightYellow => 'نیمه خصوصی';

  @override
  String get trafficLightRed => 'مسدود / ناموفق';

  @override
  String get bootstrap => 'بوت‌استرپ';

  @override
  String get circuit => 'مدار';

  @override
  String get hop => 'پرش';

  @override
  String get bridgeType => 'نوع پل';

  @override
  String get killSwitch => 'کلید قتل';

  @override
  String get whatCanTheySee => 'آن‌ها چه می‌بینند؟';

  @override
  String get yourIsp => 'ارائه‌دهنده اینترنت شما';

  @override
  String get theNode => 'نود RPC';

  @override
  String get everyone => 'همه در بلاکچین';

  @override
  String get sees => 'می‌بیند';

  @override
  String get cantSee => 'نمی‌بیند';

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
