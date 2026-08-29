import 'package:intl/intl.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:permission_handler/permission_handler.dart';
import '../data/hive_database.dart';

class EscPos {
  static const List<int> init = [0x1B, 0x40];
  static const List<int> alignCenter = [0x1B, 0x61, 0x01];
  static const List<int> alignLeft = [0x1B, 0x61, 0x00];
  static const List<int> alignRight = [0x1B, 0x61, 0x02];
  static const List<int> boldOn = [0x1B, 0x45, 0x01];
  static const List<int> boldOff = [0x1B, 0x45, 0x00];
  static const List<int> textNormal = [0x1D, 0x21, 0x00];
  static const List<int> textLarge = [0x1D, 0x21, 0x11];
  static const List<int> lineFeed = [0x0A];
}

class PrinterHelper {
  // Singleton
  static final PrinterHelper _instance = PrinterHelper._internal();
  factory PrinterHelper() => _instance;
  PrinterHelper._internal();

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  Future<bool> checkPermission() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    return statuses.values.every((status) => status.isGranted);
  }

  Future<List<BluetoothInfo>> getBondedDevices() async {
    try {
      final List<BluetoothInfo> list =
          await PrintBluetoothThermal.pairedBluetooths;
      return list;
    } catch (e) {
      return [];
    }
  }

  Future<bool> connect(String macAddress) async {
    try {
      final bool result =
          await PrintBluetoothThermal.connect(macPrinterAddress: macAddress);
      _isConnected = result;
      return result;
    } catch (e) {
      _isConnected = false;
      return false;
    }
  }

  Future<bool> disconnect() async {
    try {
      final bool result = await PrintBluetoothThermal.disconnect;
      _isConnected = !result;
      return result;
    } catch (e) {
      return false;
    }
  }

  Future<void> printText(String text) async {
    if (!_isConnected) return;
    final bool connectionStatus = await PrintBluetoothThermal.connectionStatus;
    if (connectionStatus) {
      List<int> bytes = text.codeUnits;
      await PrintBluetoothThermal.writeBytes(bytes);
    }
  }

  Future<void> printReceipt({
    required String shopName,
    required String address1,
    required String address2,
    required String phone,
    required List<Map<String, dynamic>> items, // Name, Qty, Price, Total
    required double total,
    required String footer,
    String? customerName,
    bool isCredit = false,
    double paidAmount = 0.0,
    double previousDebt = 0.0,
    double newDebtTotal = 0.0,
    double discount = 0.0,
  }) async {
    if (!_isConnected) return;

    // Load custom template if exists
    final savedTemplate = HiveDatabase.settingsBox.get('receipt_template');
    String actualShopName = shopName;
    String actualAddress = address1;
    String actualSlogan = address2;
    String actualPhone = phone;
    String actualFooter = footer;
    String actualFiscal = '';
    String actualSocial = '';
    String actualCashier = '';
    String actualThankYou = '';
    String sepLine = '--------------------------------';
    List<String> extraLines = [];

    if (savedTemplate is Map) {
      final map = Map<String, dynamic>.from(savedTemplate);
      if ((map['shopName'] as String?)?.isNotEmpty == true) actualShopName = map['shopName'];
      if (map['showAddress'] == true && (map['address'] as String?)?.isNotEmpty == true) actualAddress = map['address'];
      else if (map['showAddress'] == false) actualAddress = '';

      if (map['showSlogan'] == true && (map['slogan'] as String?)?.isNotEmpty == true) actualSlogan = map['slogan'];
      else if (map['showSlogan'] == false) actualSlogan = '';

      if (map['showPhone'] == true && (map['phone'] as String?)?.isNotEmpty == true) actualPhone = map['phone'];
      else if (map['showPhone'] == false) actualPhone = '';

      if (map['showFiscalInfo'] == true && (map['fiscalInfo'] as String?)?.isNotEmpty == true) actualFiscal = map['fiscalInfo'];
      if (map['showSocialMedia'] == true && (map['socialMedia'] as String?)?.isNotEmpty == true) actualSocial = map['socialMedia'];
      if (map['showCashierName'] == true && (map['cashierName'] as String?)?.isNotEmpty == true) actualCashier = map['cashierName'];
      if (map['showFooterNote'] == true && (map['footerNote'] as String?)?.isNotEmpty == true) actualFooter = map['footerNote'];
      else if (map['showFooterNote'] == false) actualFooter = '';

      if (map['showThankYou'] == true && (map['thankYou'] as String?)?.isNotEmpty == true) actualThankYou = map['thankYou'];

      final style = map['separatorStyle'] ?? 'dashed';
      if (style == 'stars') sepLine = '********************************';
      else if (style == 'double') sepLine = '================================';
      else if (style == 'dots') sepLine = '................................';

      extraLines = List<String>.from(map['customExtraLines'] ?? []);
    }

    List<int> bytes = [];

    // Init
    bytes += EscPos.init;

    // Shop Name (Center, Bold, Large)
    bytes += EscPos.alignCenter;
    bytes += EscPos.boldOn;
    bytes += EscPos.textLarge;
    bytes += _textToBytes(actualShopName);
    bytes += EscPos.lineFeed;

    // Slogan, Address & Phone (Normal, Center)
    bytes += EscPos.textNormal;
    bytes += EscPos.boldOff;
    if (actualSlogan.isNotEmpty) {
      bytes += _textToBytes(actualSlogan);
      bytes += EscPos.lineFeed;
    }
    if (actualAddress.isNotEmpty) {
      bytes += _textToBytes(actualAddress);
      bytes += EscPos.lineFeed;
    }
    if (actualPhone.isNotEmpty) {
      bytes += _textToBytes(actualPhone);
      bytes += EscPos.lineFeed;
    }
    if (actualFiscal.isNotEmpty) {
      bytes += _textToBytes(actualFiscal);
      bytes += EscPos.lineFeed;
    }
    if (actualSocial.isNotEmpty) {
      bytes += _textToBytes(actualSocial);
      bytes += EscPos.lineFeed;
    }

    // Date and Time
    String formattedDate = DateFormat('dd-MM-yyyy hh:mm a').format(DateTime.now());
    bytes += _textToBytes(formattedDate);
    bytes += EscPos.lineFeed;

    if (actualCashier.isNotEmpty) {
      bytes += _textToBytes(actualCashier);
      bytes += EscPos.lineFeed;
    }

    bytes += _textToBytes(sepLine);
    bytes += EscPos.lineFeed;

    // Header (Align Left)
    bytes += EscPos.alignLeft;
    bytes += _textToBytes('Item            Price   Total');
    bytes += EscPos.lineFeed;
    bytes += _textToBytes(sepLine);
    bytes += EscPos.lineFeed;

    // Items
    for (var item in items) {
      String name = item['name'].toString();
      String qty = item['qty'].toString();
      String price = item['price'].toString();
      String totalItem = item['total'].toString();

      String prefix = '${qty}x $name';
      if (prefix.length > 16) prefix = prefix.substring(0, 16);

      String line = prefix.padRight(16) + price.padRight(8) + totalItem;
      bytes += _textToBytes(line);
      bytes += EscPos.lineFeed;
    }

    bytes += _textToBytes(sepLine);
    bytes += EscPos.lineFeed;

    // Total (Align Right)
    bytes += EscPos.alignRight;
    if (discount > 0) {
      bytes += _textToBytes('REMISE: -${discount.toStringAsFixed(2)} DA');
      bytes += EscPos.lineFeed;
    }
    bytes += EscPos.boldOn;
    bytes += _textToBytes('TOTAL: ${total.toStringAsFixed(2)} DA');
    bytes += EscPos.lineFeed;
    bytes += EscPos.boldOff;

    // Credit Section (If sale was on credit)
    if (isCredit && customerName != null) {
      bytes += EscPos.lineFeed;
      bytes += EscPos.alignLeft;
      bytes += _textToBytes('*** COMPTE CREDIT CLIENT ***');
      bytes += EscPos.lineFeed;
      bytes += _textToBytes('Client: $customerName');
      bytes += EscPos.lineFeed;
      if (previousDebt > 0) {
        bytes += _textToBytes('Dette Precedente: ${previousDebt.toStringAsFixed(2)} DA');
        bytes += EscPos.lineFeed;
      }
      bytes += _textToBytes('Achats du Jour: ${total.toStringAsFixed(2)} DA');
      bytes += EscPos.lineFeed;
      if (paidAmount > 0) {
        bytes += _textToBytes('Acompte Paye: ${paidAmount.toStringAsFixed(2)} DA');
        bytes += EscPos.lineFeed;
      }
      bytes += EscPos.boldOn;
      bytes += _textToBytes('SOLDE TOTAL RESTE: ${newDebtTotal.toStringAsFixed(2)} DA');
      bytes += EscPos.boldOff;
      bytes += EscPos.lineFeed;
      bytes += _textToBytes(sepLine);
      bytes += EscPos.lineFeed;
    }

    // Extra Custom Lines
    if (extraLines.isNotEmpty) {
      bytes += EscPos.alignCenter;
      for (final line in extraLines) {
        bytes += _textToBytes(line);
        bytes += EscPos.lineFeed;
      }
      bytes += _textToBytes(sepLine);
      bytes += EscPos.lineFeed;
    }

    // Footer (Center)
    if (actualFooter.isNotEmpty) {
      bytes += EscPos.alignCenter;
      bytes += _textToBytes(actualFooter);
      bytes += EscPos.lineFeed;
    }
    if (actualThankYou.isNotEmpty) {
      bytes += EscPos.alignCenter;
      bytes += _textToBytes(actualThankYou);
      bytes += EscPos.lineFeed;
    }
    bytes += EscPos.lineFeed;
    bytes += EscPos.lineFeed;

    await PrintBluetoothThermal.writeBytes(bytes);
  }

  Future<void> printDebtPaymentReceipt({
    required String shopName,
    required String phone,
    required String customerName,
    required double paymentAmount,
    required double remainingDebt,
    String note = '',
  }) async {
    if (!_isConnected) return;

    List<int> bytes = [];
    bytes += EscPos.init;

    // Header
    bytes += EscPos.alignCenter;
    bytes += EscPos.boldOn;
    bytes += EscPos.textLarge;
    bytes += _textToBytes(shopName);
    bytes += EscPos.lineFeed;
    bytes += EscPos.textNormal;
    bytes += EscPos.boldOff;
    bytes += _textToBytes('*** RECU DE VERSEMENT DETTE ***');
    bytes += EscPos.lineFeed;
    bytes += _textToBytes(DateFormat('dd-MM-yyyy hh:mm a').format(DateTime.now()));
    bytes += EscPos.lineFeed;
    bytes += _textToBytes('--------------------------------');
    bytes += EscPos.lineFeed;

    // Details
    bytes += EscPos.alignLeft;
    bytes += _textToBytes('Client: $customerName');
    bytes += EscPos.lineFeed;
    bytes += EscPos.boldOn;
    bytes += _textToBytes('Montant Verse: ${paymentAmount.toStringAsFixed(2)} DA');
    bytes += EscPos.boldOff;
    bytes += EscPos.lineFeed;
    if (note.isNotEmpty) {
      bytes += _textToBytes('Note: $note');
      bytes += EscPos.lineFeed;
    }
    bytes += _textToBytes('--------------------------------');
    bytes += EscPos.lineFeed;
    bytes += EscPos.boldOn;
    bytes += _textToBytes('NOUVEAU SOLDE DETTE: ${remainingDebt.toStringAsFixed(2)} DA');
    bytes += EscPos.boldOff;
    bytes += EscPos.lineFeed;
    bytes += _textToBytes('--------------------------------');
    bytes += EscPos.lineFeed;

    // Footer
    bytes += EscPos.alignCenter;
    bytes += _textToBytes('Merci pour votre confiance!');
    bytes += EscPos.lineFeed;
    bytes += EscPos.lineFeed;
    bytes += EscPos.lineFeed;

    await PrintBluetoothThermal.writeBytes(bytes);
  }

  List<int> _textToBytes(String text) {
    return List.from(text.codeUnits);
  }
}
