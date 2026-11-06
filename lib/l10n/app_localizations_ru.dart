// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'BNB Кошелёк';

  @override
  String get home => 'Главная';

  @override
  String get send => 'Отправить';

  @override
  String get receive => 'Получить';

  @override
  String get settings => 'Настройки';

  @override
  String get inspect => 'Проверить';

  @override
  String get logs => 'Логи';

  @override
  String get about => 'О программе';

  @override
  String get wallet => 'Кошелёк';

  @override
  String get balance => 'Баланс';

  @override
  String get bnbBalance => 'Баланс BNB';

  @override
  String tokenBalance(Object symbol) {
    return 'Баланс $symbol';
  }

  @override
  String get address => 'Адрес';

  @override
  String get copyAddress => 'Копировать адрес';

  @override
  String get copySuccess => 'Скопировано в буфер обмена';

  @override
  String get qrCode => 'QR-код';

  @override
  String get receiveQR => 'QR для получения';

  @override
  String get sendAmount => 'Сумма для отправки';

  @override
  String get sendTo => 'Отправить на';

  @override
  String get recipientAddress => 'Адрес получателя';

  @override
  String get enterAmount => 'Введите сумму';

  @override
  String get max => 'Макс';

  @override
  String get available => 'Доступно';

  @override
  String get fee => 'Комиссия';

  @override
  String get feeTier => 'Уровень комиссии';

  @override
  String get low => 'Низкий';

  @override
  String get medium => 'Средний (рекомендуется)';

  @override
  String get high => 'Высокий';

  @override
  String get custom => 'Свой';

  @override
  String get estimatedTime => 'Оценка времени';

  @override
  String get review => 'Проверка';

  @override
  String get confirm => 'Подтвердить';

  @override
  String get holdToConfirm => 'Удерживайте для подтверждения';

  @override
  String get signing => 'Подписание...';

  @override
  String get broadcasting => 'Рассылка...';

  @override
  String get pending => 'Ожидание';

  @override
  String get success => 'Успех';

  @override
  String get failed => 'Ошибка';

  @override
  String get transactionHash => 'Хэш транзакции';

  @override
  String get blockNumber => 'Номер блока';

  @override
  String get confirmations => 'Подтверждений';

  @override
  String get finalized => 'Финализировано';

  @override
  String get sendAgain => 'Отправить снова';

  @override
  String get addToContacts => 'Добавить в контакты';

  @override
  String get copyHash => 'Копировать хэш';

  @override
  String get copyAll => 'Копировать все детали';

  @override
  String get shareAsText => 'Поделиться текстом';

  @override
  String get exportJson => 'Экспорт JSON';

  @override
  String get exportPng => 'Экспорт PNG';

  @override
  String get openInExplorer => 'Открыть в эксплорере';

  @override
  String get warningExplorer =>
      'Это откроет внешний сайт. Эксплорер увидит ваш IP и транзакцию. Продолжить?';

  @override
  String get settingsNetwork => 'Сеть';

  @override
  String get settingsNodes => 'Узлы';

  @override
  String get settingsTokens => 'Токены';

  @override
  String get settingsSecurity => 'Безопасность';

  @override
  String get settingsAppearance => 'Внешний вид';

  @override
  String get settingsPrivacy => 'Приватность';

  @override
  String get settingsAutoLock => 'Автоблокировка';

  @override
  String get settingsErase => 'Стереть всё';

  @override
  String get settingsAbout => 'О программе';

  @override
  String get settingsLanguage => 'Язык';

  @override
  String get settingsTheme => 'Тема';

  @override
  String get themeSystem => 'Системная';

  @override
  String get themeLight => 'Светлая';

  @override
  String get themeDark => 'Тёмная';

  @override
  String get themeAmoled => 'AMOLED чёрная';

  @override
  String get liteMode => 'Лёгкий режим (без анимаций)';

  @override
  String get reduceMotion => 'Уменьшить анимации (система)';

  @override
  String get torEnabled => 'Tor включён';

  @override
  String get torHost => 'Хост Tor';

  @override
  String get torPort => 'Порт Tor';

  @override
  String get useCustomProxy => 'Использовать свой прокси';

  @override
  String get proxyHost => 'Хост прокси';

  @override
  String get proxyPort => 'Порт прокси';

  @override
  String get proxyUser => 'Пользователь прокси';

  @override
  String get proxyPass => 'Пароль прокси';

  @override
  String get addNode => 'Добавить узел';

  @override
  String get editNode => 'Редактировать узел';

  @override
  String get nodeName => 'Имя узла';

  @override
  String get nodeUrl => 'URL узла';

  @override
  String get nodeNetwork => 'Сеть';

  @override
  String get nodeTransport => 'Транспорт';

  @override
  String get nodeAuth => 'Аутентификация';

  @override
  String get authNone => 'Нет';

  @override
  String get authBearer => 'Bearer токен';

  @override
  String get authBasic => 'Basic Auth';

  @override
  String get bearerToken => 'Bearer токен';

  @override
  String get basicUser => 'Пользователь';

  @override
  String get basicPass => 'Пароль';

  @override
  String get customHeaders => 'Свои заголовки';

  @override
  String get pinnedSpki =>
      'Закреплённые SPKI хеши (base64, по одному в строке)';

  @override
  String get useForReads => 'Для чтения';

  @override
  String get useForBroadcast => 'Для рассылки';

  @override
  String get selectionMode => 'Режим выбора';

  @override
  String get selectionManual => 'Ручной';

  @override
  String get selectionAuto => 'Авто-самый быстрый';

  @override
  String get selectionRandom => 'Round-robin / случайный';

  @override
  String get selectionQuorum => 'Кворум';

  @override
  String get testNode => 'Тест узла';

  @override
  String get nodeChecklist => 'Чек-лист узла';

  @override
  String get tokenSources => 'Источники контрактов токенов';

  @override
  String get addToken => 'Добавить токен';

  @override
  String get tokenAddress => 'Адрес контракта токена';

  @override
  String get tokenSymbol => 'Символ';

  @override
  String get tokenName => 'Название';

  @override
  String get tokenDecimals => 'Десятичные знаки';

  @override
  String get hideToken => 'Скрыть токен';

  @override
  String get showToken => 'Показать токен';

  @override
  String get backupQuiz => 'Тест бэкапа';

  @override
  String get verifyPhrase => 'Проверить сид-фразу';

  @override
  String get watchOnly => 'Только просмотр';

  @override
  String get importWatchOnly => 'Импорт адреса для просмотра';

  @override
  String get enterAddress => 'Введите адрес для просмотра';

  @override
  String get coldMode => 'Режим холодного кошелька';

  @override
  String get coldModeHot => 'Обычный (горячий кошелёк)';

  @override
  String get coldModeCold => 'Холодной (офлайн подписчик)';

  @override
  String get coldModeOnline => 'Онлайн (только просмотр)';

  @override
  String get exportForOnline => 'Экспорт для онлайн устройства';

  @override
  String get importPairing => 'Импорт данных пары';

  @override
  String get coldHygiene => 'Гигиена холодного устройства';

  @override
  String get airplaneMode => 'Режим самолёта';

  @override
  String get wifi => 'Wi-Fi';

  @override
  String get mobileData => 'Мобильный интернет';

  @override
  String get bluetooth => 'Bluetooth';

  @override
  String get nfc => 'NFC';

  @override
  String get networkInterface => 'Сетевой интерфейс';

  @override
  String get battery => 'Батарея';

  @override
  String get charging => 'Зарядка';

  @override
  String get createWallet => 'Создать кошелёк';

  @override
  String get importWallet => 'Импорт кошелька';

  @override
  String get mnemonic => 'Сид-фраза';

  @override
  String get passphrase => 'BIP-39 парольная фраза (опционально)';

  @override
  String get passphraseHint => 'Опциональное 25-е слово';

  @override
  String get confirmPhrase => 'Подтвердить фразу';

  @override
  String enterWords(Object end, Object start) {
    return 'Введите слова $start–$end';
  }

  @override
  String get word => 'Слово';

  @override
  String get create => 'Создать';

  @override
  String get import => 'Импорт';

  @override
  String get unlock => 'Разблокировать';

  @override
  String get lock => 'Заблокировать';

  @override
  String get pin => 'PIN';

  @override
  String get biometric => 'Биометрия';

  @override
  String get changePin => 'Сменить PIN';

  @override
  String get enablePin => 'Включить PIN';

  @override
  String get disablePin => 'Выключить PIN';

  @override
  String get autoLockSeconds => 'Автоблокировка через';

  @override
  String get never => 'Никогда';

  @override
  String get seconds => 'секунд';

  @override
  String get minutes => 'минут';

  @override
  String get eraseAllData => 'Стереть все данные';

  @override
  String get eraseWarning =>
      'Удалит все кошельки, ключи, историю, логи и настройки. Средства можно вернуть только сид-фразой.';

  @override
  String get confirmErase => 'Введите \'ERASE\' для подтверждения';

  @override
  String get holdToErase => 'Удерживайте для стирания';

  @override
  String get erasing => 'Стирание...';

  @override
  String get erased => 'Все данные стерты';

  @override
  String get logsSimple => 'Простой';

  @override
  String get logsExpert => 'Экспертный';

  @override
  String get logsFilter => 'Фильтр';

  @override
  String get logsSearch => 'Поиск';

  @override
  String get logsExport => 'Экспорт';

  @override
  String get logsClear => 'Очистить логи';

  @override
  String get logsWarning =>
      'Экспорт логов может раскрыть вашу активность. Продолжить?';

  @override
  String get logLevelError => 'Ошибка';

  @override
  String get logLevelWarn => 'Предупреждение';

  @override
  String get logLevelInfo => 'Инфо';

  @override
  String get logLevelDebug => 'Отладка';

  @override
  String get logLevelTrace => 'Трассировка';

  @override
  String get logCategoryVault => 'Хранилище';

  @override
  String get logCategoryKeys => 'Операции с ключами';

  @override
  String get logCategoryNetwork => 'Сеть';

  @override
  String get logCategoryTor => 'Tor';

  @override
  String get logCategoryFees => 'Комиссии';

  @override
  String get logCategoryTx => 'Транзакции';

  @override
  String get logCategoryTokens => 'Токены';

  @override
  String get logCategorySecurity => 'Безопасность';

  @override
  String get journeyMap => 'Карта пути';

  @override
  String get journeyPhone => 'Мой телефон';

  @override
  String get journeyPrivacy => 'Слой приватности';

  @override
  String get journeyNode => 'Узел';

  @override
  String get journeyChain => 'BNB Chain';

  @override
  String get journeyDone => 'Готово';

  @override
  String get stateWaiting => 'Ожидание';

  @override
  String get stateWorking => 'Работает';

  @override
  String get stateOk => 'ОК';

  @override
  String get stateProblem => 'Проблема';

  @override
  String get nodeCard => 'Узел';

  @override
  String get nodeLatency => 'Задержка';

  @override
  String get nodeLatestBlock => 'Последний блок';

  @override
  String get nodeRightChain => 'Правильная цепочка';

  @override
  String get nodeCompare => 'Сравнить другой';

  @override
  String get nodeSwitch => 'Сменить узел';

  @override
  String get receipt => 'Чек';

  @override
  String get receiptStatus => 'Статус';

  @override
  String get receiptFrom => 'От';

  @override
  String get receiptTo => 'Кому';

  @override
  String get receiptAsset => 'Актив';

  @override
  String get receiptAmount => 'Сумма';

  @override
  String get receiptAmountRaw => 'Сырая сумма';

  @override
  String get receiptNonce => 'Nonce';

  @override
  String get receiptGasLimit => 'Лимит газа';

  @override
  String get receiptGasUsed => 'Газ использован';

  @override
  String get receiptFee => 'Комиссия';

  @override
  String get receiptFeeTier => 'Уровень комиссии';

  @override
  String get receiptFeeReason => 'Причина комиссии';

  @override
  String get receiptTxType => 'Тип транзакции';

  @override
  String get receiptInputData => 'Входные данные';

  @override
  String get receiptEventLogs => 'Логи событий';

  @override
  String get receiptBlockHash => 'Хэш блока';

  @override
  String get receiptTxIndex => 'Индекс транзакции';

  @override
  String get receiptBalances => 'Балансы до / после';

  @override
  String get receiptBefore => 'До';

  @override
  String get receiptAfter => 'После';

  @override
  String get receiptVerified => 'Проверено';

  @override
  String get receiptNodeUsed => 'Использованный узел';

  @override
  String get receiptTransport => 'Транспорт';

  @override
  String get securityNotice => 'Уведомление о безопасности';

  @override
  String get honestLimits => 'Честные лимиты';

  @override
  String get version => 'Версия';

  @override
  String get license => 'Лицензия';

  @override
  String get buildHash => 'Хэш сборки';

  @override
  String get sbom => 'SBOM';

  @override
  String get contact => 'Контакт';

  @override
  String get privacyPolicy => 'Политика приватности';

  @override
  String get threatModel => 'Модель угроз';

  @override
  String get architecture => 'Архитектура';

  @override
  String get changelog => 'История изменений';

  @override
  String get contributing => 'Участие';

  @override
  String get ok => 'ОК';

  @override
  String get cancel => 'Отмена';

  @override
  String get close => 'Закрыть';

  @override
  String get save => 'Сохранить';

  @override
  String get delete => 'Удалить';

  @override
  String get edit => 'Редактировать';

  @override
  String get add => 'Добавить';

  @override
  String get remove => 'Удалить';

  @override
  String get reset => 'Сброс';

  @override
  String get test => 'Тест';

  @override
  String get verify => 'Проверить';

  @override
  String get copy => 'Копировать';

  @override
  String get paste => 'Вставить';

  @override
  String get scan => 'Сканировать';

  @override
  String get warning => 'Предупреждение';

  @override
  String get error => 'Ошибка';

  @override
  String get info => 'Инфо';

  @override
  String get loading => 'Загрузка...';

  @override
  String get retry => 'Повторить';

  @override
  String get speedUp => 'Ускорить';

  @override
  String get cancelTx => 'Отменить';

  @override
  String get replaceTx => 'Заменить';

  @override
  String get insufficientBnb => 'Недостаточно BNB для газа';

  @override
  String get needBnb => 'Нужен BNB для оплаты газа. Сначала получите.';

  @override
  String get addressPoisoning =>
      'Этот адрес похож на недавний контакт, но отличается. Проверьте внимательно.';

  @override
  String get selfContract =>
      'Отправка на адрес контракта токена сожжёт токены.';

  @override
  String get zeroAddress => 'Отправка на нулевой адрес запрещена.';

  @override
  String get newAddress =>
      'Этот адрес никогда не использовался. Проверьте внимательно.';

  @override
  String tokenSimulationFailed(Object reason) {
    return 'Симуляция не удалась: $reason';
  }

  @override
  String get tokenUnknown => 'Неизвестный токен';

  @override
  String get unlimitedApproval =>
      'Неограниченное одобрение — токен может потратить весь баланс';

  @override
  String get signUnknownData => 'Подпись неизвестных данных (продвинутый)';

  @override
  String get enableSignUnknown => 'Включить подпись неизвестного calldata';

  @override
  String get blindSignWarning =>
      'Слепая подпись опасна. Включайте только если понимаете риски.';

  @override
  String get disclosure => 'Раскрытие';

  @override
  String get nodeSees =>
      'Узел видит: ваш IP, RPC метод и параметры. Может вывести связи адресов.';

  @override
  String get appDoesNotSend =>
      'Приложение НЕ отправляет: модель устройства, ОС, версию приложения, язык, местоположение, контакты, сид, ключи, пароли.';

  @override
  String get viewRawRequest => 'Посмотреть сырой запрос';

  @override
  String get copyLog => 'Копировать лог';

  @override
  String get privacyScreen => 'Приватность сети';

  @override
  String get directMode => 'Прямой HTTPS';

  @override
  String get torMode => 'Tor (SOCKS5)';

  @override
  String get bridgeMode => 'Tor + мост';

  @override
  String get proxyMode => 'Свой прокси';

  @override
  String get ispSees => 'Ваш провайдер видит:';

  @override
  String get ispNotSees => 'Ваш провайдер НЕ видит:';

  @override
  String get nodeSeesPrivacy => 'RPC узел видит:';

  @override
  String get nodeNotSeesPrivacy => 'RPC узел НЕ видит:';

  @override
  String get chainSees => 'Блокчейн видит:';

  @override
  String get chainNotSees => 'Блокчейн НЕ видит:';

  @override
  String get trafficLightGreen => 'Полностью приватно';

  @override
  String get trafficLightYellow => 'Частично приватно';

  @override
  String get trafficLightRed => 'Заблокировано / ошибка';

  @override
  String get bootstrap => 'Бутстрап';

  @override
  String get circuit => 'Цепь';

  @override
  String get hop => 'Хоп';

  @override
  String get bridgeType => 'Тип моста';

  @override
  String get killSwitch => 'Kill switch';

  @override
  String get whatCanTheySee => 'Что они могут видеть?';

  @override
  String get yourIsp => 'Ваш провайдер';

  @override
  String get theNode => 'RPC узел';

  @override
  String get everyone => 'Все в блокчейне';

  @override
  String get sees => 'Видит';

  @override
  String get cantSee => 'Не видит';

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
