// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'BNB Wallet';

  @override
  String get home => 'Inicio';

  @override
  String get send => 'Enviar';

  @override
  String get receive => 'Recibir';

  @override
  String get settings => 'Ajustes';

  @override
  String get inspect => 'Inspeccionar';

  @override
  String get logs => 'Registros';

  @override
  String get about => 'Acerca de';

  @override
  String get wallet => 'Monedero';

  @override
  String get balance => 'Saldo';

  @override
  String get bnbBalance => 'Saldo BNB';

  @override
  String tokenBalance(Object symbol) {
    return 'Saldo $symbol';
  }

  @override
  String get address => 'Dirección';

  @override
  String get copyAddress => 'Copiar dirección';

  @override
  String get copySuccess => 'Copiado al portapapeles';

  @override
  String get qrCode => 'Código QR';

  @override
  String get receiveQR => 'QR para recibir';

  @override
  String get sendAmount => 'Cantidad a enviar';

  @override
  String get sendTo => 'Enviar a';

  @override
  String get recipientAddress => 'Dirección del destinatario';

  @override
  String get enterAmount => 'Introduce la cantidad';

  @override
  String get max => 'Máx';

  @override
  String get available => 'Disponible';

  @override
  String get fee => 'Comisión';

  @override
  String get feeTier => 'Nivel de comisión';

  @override
  String get low => 'Baja';

  @override
  String get medium => 'Media (recomendada)';

  @override
  String get high => 'Alta';

  @override
  String get custom => 'Personalizada';

  @override
  String get estimatedTime => 'Tiempo estimado';

  @override
  String get review => 'Revisar';

  @override
  String get confirm => 'Confirmar';

  @override
  String get holdToConfirm => 'Mantén para confirmar';

  @override
  String get signing => 'Firmando...';

  @override
  String get broadcasting => 'Transmitiendo...';

  @override
  String get pending => 'Pendiente';

  @override
  String get success => 'Éxito';

  @override
  String get failed => 'Fallido';

  @override
  String get transactionHash => 'Hash de transacción';

  @override
  String get blockNumber => 'Número de bloque';

  @override
  String get confirmations => 'Confirmaciones';

  @override
  String get finalized => 'Finalizada';

  @override
  String get sendAgain => 'Enviar de nuevo';

  @override
  String get addToContacts => 'Añadir a contactos';

  @override
  String get copyHash => 'Copiar hash';

  @override
  String get copyAll => 'Copiar todos los detalles';

  @override
  String get shareAsText => 'Compartir como texto';

  @override
  String get exportJson => 'Exportar JSON';

  @override
  String get exportPng => 'Exportar PNG';

  @override
  String get openInExplorer => 'Abrir en explorador';

  @override
  String get warningExplorer => 'Esto abre un sitio web externo. El explorador verá tu IP y la transacción. ¿Continuar?';

  @override
  String get settingsNetwork => 'Red';

  @override
  String get settingsNodes => 'Nodos';

  @override
  String get settingsTokens => 'Tokens';

  @override
  String get settingsSecurity => 'Seguridad';

  @override
  String get settingsAppearance => 'Apariencia';

  @override
  String get settingsPrivacy => 'Privacidad';

  @override
  String get settingsAutoLock => 'Bloqueo automático';

  @override
  String get settingsErase => 'Borrar todo';

  @override
  String get settingsAbout => 'Acerca de';

  @override
  String get settingsLanguage => 'Idioma';

  @override
  String get settingsTheme => 'Tema';

  @override
  String get themeSystem => 'Sistema';

  @override
  String get themeLight => 'Claro';

  @override
  String get themeDark => 'Oscuro';

  @override
  String get themeAmoled => 'AMOLED negro';

  @override
  String get liteMode => 'Modo ligero (sin animaciones)';

  @override
  String get reduceMotion => 'Reducir movimiento (sistema)';

  @override
  String get torEnabled => 'Tor activado';

  @override
  String get torHost => 'Host Tor';

  @override
  String get torPort => 'Puerto Tor';

  @override
  String get useCustomProxy => 'Usar proxy personalizado';

  @override
  String get proxyHost => 'Host proxy';

  @override
  String get proxyPort => 'Puerto proxy';

  @override
  String get proxyUser => 'Usuario proxy';

  @override
  String get proxyPass => 'Contraseña proxy';

  @override
  String get addNode => 'Añadir nodo';

  @override
  String get editNode => 'Editar nodo';

  @override
  String get nodeName => 'Nombre del nodo';

  @override
  String get nodeUrl => 'URL del nodo';

  @override
  String get nodeNetwork => 'Red';

  @override
  String get nodeTransport => 'Transporte';

  @override
  String get nodeAuth => 'Autenticación';

  @override
  String get authNone => 'Ninguna';

  @override
  String get authBearer => 'Token Bearer';

  @override
  String get authBasic => 'Auth básica';

  @override
  String get bearerToken => 'Token Bearer';

  @override
  String get basicUser => 'Usuario';

  @override
  String get basicPass => 'Contraseña';

  @override
  String get customHeaders => 'Cabeceras personalizadas';

  @override
  String get pinnedSpki => 'Hashes SPKI fijados (base64, uno por línea)';

  @override
  String get useForReads => 'Para lecturas';

  @override
  String get useForBroadcast => 'Para emisión';

  @override
  String get selectionMode => 'Modo de selección';

  @override
  String get selectionManual => 'Manual';

  @override
  String get selectionAuto => 'Auto-rápido';

  @override
  String get selectionRandom => 'Round-robin / aleatorio';

  @override
  String get selectionQuorum => 'Quórum';

  @override
  String get testNode => 'Probar nodo';

  @override
  String get nodeChecklist => 'Lista de verificación';

  @override
  String get tokenSources => 'Fuentes de contratos de tokens';

  @override
  String get addToken => 'Añadir token';

  @override
  String get tokenAddress => 'Dirección del contrato del token';

  @override
  String get tokenSymbol => 'Símbolo';

  @override
  String get tokenName => 'Nombre';

  @override
  String get tokenDecimals => 'Decimales';

  @override
  String get hideToken => 'Ocultar token';

  @override
  String get showToken => 'Mostrar token';

  @override
  String get backupQuiz => 'Cuestionario de respaldo';

  @override
  String get verifyPhrase => 'Verificar frase de recuperación';

  @override
  String get watchOnly => 'Solo lectura';

  @override
  String get importWatchOnly => 'Importar dirección de solo lectura';

  @override
  String get enterAddress => 'Introduce dirección para vigilar';

  @override
  String get coldMode => 'Modo monedero frío';

  @override
  String get coldModeHot => 'Normal (monedero caliente)';

  @override
  String get coldModeCold => 'Frío (firmador offline)';

  @override
  String get coldModeOnline => 'Online (compañero solo lectura)';

  @override
  String get exportForOnline => 'Exportar para dispositivo online';

  @override
  String get importPairing => 'Importar datos de emparejamiento';

  @override
  String get coldHygiene => 'Higiene del dispositivo frío';

  @override
  String get airplaneMode => 'Modo avión';

  @override
  String get wifi => 'Wi-Fi';

  @override
  String get mobileData => 'Datos móviles';

  @override
  String get bluetooth => 'Bluetooth';

  @override
  String get nfc => 'NFC';

  @override
  String get networkInterface => 'Interfaz de red';

  @override
  String get battery => 'Batería';

  @override
  String get charging => 'Cargando';

  @override
  String get createWallet => 'Crear monedero';

  @override
  String get importWallet => 'Importar monedero';

  @override
  String get mnemonic => 'Frase de recuperación';

  @override
  String get passphrase => 'Passphrase BIP-39 (opcional)';

  @override
  String get passphraseHint => '25ª palabra opcional';

  @override
  String get confirmPhrase => 'Confirmar frase';

  @override
  String enterWords(Object end, Object start) {
    return 'Introduce palabras $start–$end';
  }

  @override
  String get word => 'Palabra';

  @override
  String get create => 'Crear';

  @override
  String get import => 'Importar';

  @override
  String get unlock => 'Desbloquear';

  @override
  String get lock => 'Bloquear';

  @override
  String get pin => 'PIN';

  @override
  String get biometric => 'Biométrico';

  @override
  String get changePin => 'Cambiar PIN';

  @override
  String get enablePin => 'Activar PIN';

  @override
  String get disablePin => 'Desactivar PIN';

  @override
  String get autoLockSeconds => 'Bloqueo automático tras';

  @override
  String get never => 'Nunca';

  @override
  String get seconds => 'segundos';

  @override
  String get minutes => 'minutos';

  @override
  String get eraseAllData => 'Borrar todos los datos';

  @override
  String get eraseWarning => 'Eliminará todos los monederos, claves, historial, logs y ajustes. Los fondos solo se recuperan con la frase de recuperación.';

  @override
  String get confirmErase => 'Escribe \'ERASE\' para confirmar';

  @override
  String get holdToErase => 'Mantén para borrar';

  @override
  String get erasing => 'Borrando...';

  @override
  String get erased => 'Todos los datos borrados';

  @override
  String get logsSimple => 'Simple';

  @override
  String get logsExpert => 'Experto';

  @override
  String get logsFilter => 'Filtrar';

  @override
  String get logsSearch => 'Buscar';

  @override
  String get logsExport => 'Exportar';

  @override
  String get logsClear => 'Limpiar logs';

  @override
  String get logsWarning => 'Exportar logs puede revelar tu actividad. ¿Continuar?';

  @override
  String get logLevelError => 'Error';

  @override
  String get logLevelWarn => 'Advertencia';

  @override
  String get logLevelInfo => 'Info';

  @override
  String get logLevelDebug => 'Depuración';

  @override
  String get logLevelTrace => 'Traza';

  @override
  String get logCategoryVault => 'Bóveda';

  @override
  String get logCategoryKeys => 'Operaciones de claves';

  @override
  String get logCategoryNetwork => 'Red';

  @override
  String get logCategoryTor => 'Tor';

  @override
  String get logCategoryFees => 'Comisiones';

  @override
  String get logCategoryTx => 'Transacciones';

  @override
  String get logCategoryTokens => 'Tokens';

  @override
  String get logCategorySecurity => 'Seguridad';

  @override
  String get journeyMap => 'Mapa de viaje';

  @override
  String get journeyPhone => 'Mi teléfono';

  @override
  String get journeyPrivacy => 'Capa de privacidad';

  @override
  String get journeyNode => 'Nodo';

  @override
  String get journeyChain => 'Cadena BNB';

  @override
  String get journeyDone => 'Hecho';

  @override
  String get stateWaiting => 'Esperando';

  @override
  String get stateWorking => 'Trabajando';

  @override
  String get stateOk => 'OK';

  @override
  String get stateProblem => 'Problema';

  @override
  String get nodeCard => 'Nodo';

  @override
  String get nodeLatency => 'Latencia';

  @override
  String get nodeLatestBlock => 'Último bloque';

  @override
  String get nodeRightChain => 'Cadena correcta';

  @override
  String get nodeCompare => 'Comparar otro';

  @override
  String get nodeSwitch => 'Cambiar nodo';

  @override
  String get receipt => 'Recibo';

  @override
  String get receiptStatus => 'Estado';

  @override
  String get receiptFrom => 'De';

  @override
  String get receiptTo => 'A';

  @override
  String get receiptAsset => 'Activo';

  @override
  String get receiptAmount => 'Cantidad';

  @override
  String get receiptAmountRaw => 'Cantidad cruda';

  @override
  String get receiptNonce => 'Nonce';

  @override
  String get receiptGasLimit => 'Límite de gas';

  @override
  String get receiptGasUsed => 'Gas usado';

  @override
  String get receiptFee => 'Comisión';

  @override
  String get receiptFeeTier => 'Nivel de comisión';

  @override
  String get receiptFeeReason => 'Razón de comisión';

  @override
  String get receiptTxType => 'Tipo de tx';

  @override
  String get receiptInputData => 'Datos de entrada';

  @override
  String get receiptEventLogs => 'Logs de eventos';

  @override
  String get receiptBlockHash => 'Hash de bloque';

  @override
  String get receiptTxIndex => 'Índice de tx';

  @override
  String get receiptBalances => 'Saldos antes / después';

  @override
  String get receiptBefore => 'Antes';

  @override
  String get receiptAfter => 'Después';

  @override
  String get receiptVerified => 'Verificado';

  @override
  String get receiptNodeUsed => 'Nodo usado';

  @override
  String get receiptTransport => 'Transporte';

  @override
  String get securityNotice => 'Aviso de seguridad';

  @override
  String get honestLimits => 'Límites honestos';

  @override
  String get version => 'Versión';

  @override
  String get license => 'Licencia';

  @override
  String get buildHash => 'Hash de compilación';

  @override
  String get sbom => 'SBOM';

  @override
  String get contact => 'Contacto';

  @override
  String get privacyPolicy => 'Política de privacidad';

  @override
  String get threatModel => 'Modelo de amenazas';

  @override
  String get architecture => 'Arquitectura';

  @override
  String get changelog => 'Registro de cambios';

  @override
  String get contributing => 'Contribuir';

  @override
  String get ok => 'OK';

  @override
  String get cancel => 'Cancelar';

  @override
  String get close => 'Cerrar';

  @override
  String get save => 'Guardar';

  @override
  String get delete => 'Eliminar';

  @override
  String get edit => 'Editar';

  @override
  String get add => 'Añadir';

  @override
  String get remove => 'Quitar';

  @override
  String get reset => 'Restablecer';

  @override
  String get test => 'Probar';

  @override
  String get verify => 'Verificar';

  @override
  String get copy => 'Copiar';

  @override
  String get paste => 'Pegar';

  @override
  String get scan => 'Escanear';

  @override
  String get warning => 'Advertencia';

  @override
  String get error => 'Error';

  @override
  String get info => 'Info';

  @override
  String get loading => 'Cargando...';

  @override
  String get retry => 'Reintentar';

  @override
  String get speedUp => 'Acelerar';

  @override
  String get cancelTx => 'Cancelar';

  @override
  String get replaceTx => 'Reemplazar';

  @override
  String get insufficientBnb => 'BNB insuficiente para gas';

  @override
  String get needBnb => 'Necesitas BNB para pagar gas. Recibe algo primero.';

  @override
  String get addressPoisoning => 'Esta dirección se parece a un contacto reciente pero difiere. Verifica con cuidado.';

  @override
  String get selfContract => 'Enviar a la dirección del contrato del token quemará tokens.';

  @override
  String get zeroAddress => 'No se permite enviar a la dirección cero.';

  @override
  String get newAddress => 'Esta dirección nunca se ha usado. Verifica con cuidado.';

  @override
  String tokenSimulationFailed(Object reason) {
    return 'Simulación fallida: $reason';
  }

  @override
  String get tokenUnknown => 'Token desconocido';

  @override
  String get unlimitedApproval => 'Aprobación ilimitada — el token puede gastar todo tu saldo';

  @override
  String get signUnknownData => 'Firmar datos desconocidos (avanzado)';

  @override
  String get enableSignUnknown => 'Activar firma de calldata desconocida';

  @override
  String get blindSignWarning => 'Firma ciega es peligrosa. Solo activa si entiendes los riesgos.';

  @override
  String get disclosure => 'Divulgación';

  @override
  String get nodeSees => 'El nodo ve: tu IP, el método RPC y parámetros. Puede inferir vínculos de direcciones.';

  @override
  String get appDoesNotSend => 'La app NO envía: modelo de dispositivo, SO, versión de app, idioma, ubicación, contactos, semilla, claves, contraseñas.';

  @override
  String get viewRawRequest => 'Ver petición cruda';

  @override
  String get copyLog => 'Copiar log';

  @override
  String get privacyScreen => 'Privacidad de red';

  @override
  String get directMode => 'HTTPS directo';

  @override
  String get torMode => 'Tor (SOCKS5)';

  @override
  String get bridgeMode => 'Tor + puente';

  @override
  String get proxyMode => 'Proxy personalizado';

  @override
  String get ispSees => 'Tu ISP ve:';

  @override
  String get ispNotSees => 'Tu ISP NO ve:';

  @override
  String get nodeSeesPrivacy => 'El nodo RPC ve:';

  @override
  String get nodeNotSeesPrivacy => 'El nodo RPC NO ve:';

  @override
  String get chainSees => 'La cadena ve:';

  @override
  String get chainNotSees => 'La cadena NO ve:';

  @override
  String get trafficLightGreen => 'Totalmente privado';

  @override
  String get trafficLightYellow => 'Parcialmente privado';

  @override
  String get trafficLightRed => 'Bloqueado / fallo';

  @override
  String get bootstrap => 'Arranque';

  @override
  String get circuit => 'Circuito';

  @override
  String get hop => 'Salto';

  @override
  String get bridgeType => 'Tipo de puente';

  @override
  String get killSwitch => 'Interruptor de corte';

  @override
  String get whatCanTheySee => '¿Qué pueden ver?';

  @override
  String get yourIsp => 'Tu ISP';

  @override
  String get theNode => 'El nodo RPC';

  @override
  String get everyone => 'Todos en la blockchain';

  @override
  String get sees => 'Ve';

  @override
  String get cantSee => 'No ve';

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
