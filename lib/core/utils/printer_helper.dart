import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:permission_handler/permission_handler.dart';
import '../data/hive_database.dart';

enum PrinterRole { thermalReceipt, documentA4 }

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

  // -------------------------------------------------------------
  // Windows Desktop Printers Discovery & Management
  // -------------------------------------------------------------
  static Future<List<Printer>> getWindowsPrinters() async {
    try {
      return await Printing.listPrinters();
    } catch (_) {
      return [];
    }
  }

  static String get defaultThermalPrinter =>
      HiveDatabase.settingsBox.get('default_thermal_printer', defaultValue: '') as String;

  static String get defaultDocumentPrinter =>
      HiveDatabase.settingsBox.get('default_document_printer', defaultValue: '') as String;

  static Future<void> setDefaultThermalPrinter(String name) async {
    await HiveDatabase.settingsBox.put('default_thermal_printer', name);
  }

  static Future<void> setDefaultDocumentPrinter(String name) async {
    await HiveDatabase.settingsBox.put('default_document_printer', name);
  }

  static Future<void> openCashDrawer() async {
    try {
      final List<int> drawerCommand = [0x1B, 0x70, 0x00, 0x19, 0xFA];
      await PrintBluetoothThermal.writeBytes(drawerCommand);
    } catch (_) {}
  }

  /// Print test page to verify connection and paper width
  static Future<bool> printTestPage(Printer printer, {PrinterRole role = PrinterRole.thermalReceipt}) async {
    try {
      final doc = pw.Document();
      if (role == PrinterRole.thermalReceipt) {
        doc.addPage(
          pw.Page(
            pageFormat: const PdfPageFormat(72 * PdfPageFormat.mm, 100 * PdfPageFormat.mm, marginAll: 4 * PdfPageFormat.mm),
            build: (pw.Context ctx) {
              return pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text('Nayli Market POS 🇩🇿', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
                  pw.Text('طابعة التوصيل الحرارية (80mm)', style: const pw.TextStyle(fontSize: 9)),
                  pw.Divider(thickness: 0.5),
                  pw.Text('الطابعة: ${printer.name}', style: const pw.TextStyle(fontSize: 8)),
                  pw.Text(DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now()), style: const pw.TextStyle(fontSize: 8)),
                  pw.SizedBox(height: 6),
                  pw.Text('تجربة الطباعة ناجحة 100%!', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                ],
              );
            },
          ),
        );
      } else {
        doc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (pw.Context ctx) {
              return pw.Center(
                child: pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    pw.Text('Nayli Market Solutions - Test Page', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 22)),
                    pw.SizedBox(height: 10),
                    pw.Text('طابعة المستندات والفواتير الرسمية (A4 Laser/Inkjet)', style: const pw.TextStyle(fontSize: 14)),
                    pw.Text('Printer: ${printer.name}', style: const pw.TextStyle(fontSize: 12)),
                    pw.Text(DateFormat('yyyy/MM/dd HH:mm').format(DateTime.now()), style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              );
            },
          ),
        );
      }
      final bytes = await doc.save();
      return await Printing.directPrintPdf(printer: printer, onLayout: (_) => bytes);
    } catch (_) {
      return false;
    }
  }

  /// Print Cashier Sale Receipt for Windows POS
  static Future<bool> printReceiptWindows({
    required String shopName,
    String? address1,
    String? address2,
    String? phone,
    required List<Map<String, dynamic>> items,
    required double total,
    double discount = 0.0,
    bool isCredit = false,
    String? customerName,
    double previousDebt = 0.0,
    double paidAmount = 0.0,
    double newDebtTotal = 0.0,
    String? footer,
    String? specificPrinterName,
  }) async {
    try {
      final doc = pw.Document();
      doc.addPage(
        pw.Page(
          pageFormat: const PdfPageFormat(72 * PdfPageFormat.mm, double.infinity, marginAll: 4 * PdfPageFormat.mm),
          build: (pw.Context ctx) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(shopName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
                if (address1 != null && address1.isNotEmpty) pw.Text(address1, style: const pw.TextStyle(fontSize: 8.5)),
                if (address2 != null && address2.isNotEmpty) pw.Text(address2, style: const pw.TextStyle(fontSize: 8.5)),
                if (phone != null && phone.isNotEmpty) pw.Text('Tel: $phone', style: const pw.TextStyle(fontSize: 8.5)),
                pw.Text(DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()), style: const pw.TextStyle(fontSize: 8)),
                pw.Divider(thickness: 0.5),
                ...items.map((item) {
                  return pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Expanded(
                          child: pw.Text('${item['qty']}x ${item['name']}', style: const pw.TextStyle(fontSize: 8.5)),
                        ),
                        pw.Text('${item['total']} DA', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  );
                }),
                pw.Divider(thickness: 0.5),
                if (discount > 0)
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Remise:', style: const pw.TextStyle(fontSize: 8.5)),
                      pw.Text('-${discount.toStringAsFixed(2)} DA', style: const pw.TextStyle(fontSize: 8.5)),
                    ],
                  ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('TOTAL:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                    pw.Text('${total.toStringAsFixed(2)} DA', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                  ],
                ),
                if (isCredit && customerName != null) ...[
                  pw.Divider(thickness: 0.5),
                  pw.Text('CREDIT CLIENT: $customerName', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5)),
                  if (previousDebt > 0) pw.Text('Dette prec: ${previousDebt.toStringAsFixed(2)} DA', style: const pw.TextStyle(fontSize: 8)),
                  pw.Text('Total du: ${newDebtTotal.toStringAsFixed(2)} DA', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                ],
                pw.SizedBox(height: 8),
                pw.Text((footer != null && footer.isNotEmpty) ? footer : 'Merci pour votre visite!', style: const pw.TextStyle(fontSize: 8)),
              ],
            );
          },
        ),
      );

      final bytes = await doc.save();
      final printers = await Printing.listPrinters();
      final targetName = specificPrinterName ?? defaultThermalPrinter;
      Printer? target;
      if (targetName.isNotEmpty) {
        target = printers.where((p) => p.name == targetName).firstOrNull;
      }
      target ??= printers.where((p) => p.isDefault).firstOrNull ?? (printers.isNotEmpty ? printers.first : null);

      if (target != null) {
        return await Printing.directPrintPdf(printer: target, onLayout: (_) => bytes);
      } else {
        return await Printing.layoutPdf(onLayout: (_) => bytes);
      }
    } catch (_) {
      return false;
    }
  }

  // -------------------------------------------------------------
  // Mobile Bluetooth Thermal Section (Android / iOS)
  // -------------------------------------------------------------
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
      final List<BluetoothInfo> list = await PrintBluetoothThermal.pairedBluetooths;
      return list;
    } catch (e) {
      return [];
    }
  }

  Future<bool> connect(String macAddress) async {
    try {
      final bool result = await PrintBluetoothThermal.connect(macPrinterAddress: macAddress);
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

  /// Print plain text on thermal receipt printer
  Future<void> printText(String text) async {
    try {
      if (Platform.isWindows) {
        final doc = pw.Document();
        doc.addPage(
          pw.Page(
            pageFormat: const PdfPageFormat(72 * PdfPageFormat.mm, double.infinity, marginAll: 4 * PdfPageFormat.mm),
            build: (ctx) => pw.Text(text, style: const pw.TextStyle(fontSize: 10)),
          ),
        );
        final bytes = await doc.save();
        await Printing.layoutPdf(onLayout: (_) => bytes);
      } else {
        await PrintBluetoothThermal.writeString(printText: PrintTextSize(size: 1, text: text));
      }
    } catch (_) {}
  }

  Future<void> printReceipt({
    required String shopName,
    String? address1,
    String? address2,
    required String phone,
    required List<Map<String, dynamic>> items,
    required double total,
    double discount = 0.0,
    bool isCredit = false,
    String? customerName,
    double previousDebt = 0.0,
    double paidAmount = 0.0,
    double newDebtTotal = 0.0,
    String? footer,
    List<String> extraLines = const [],
  }) async {
    // If running on Windows desktop, use native Windows spooler
    if (Platform.isWindows) {
      await printReceiptWindows(
        shopName: shopName,
        address1: address1,
        address2: address2,
        phone: phone,
        items: items,
        total: total,
        discount: discount,
        isCredit: isCredit,
        customerName: customerName,
        previousDebt: previousDebt,
        paidAmount: paidAmount,
        newDebtTotal: newDebtTotal,
        footer: footer,
      );
      return;
    }

    // Android/iOS Bluetooth thermal fallback
    if (!_isConnected) return;

    final box = HiveDatabase.settingsBox;
    final paperSize = box.get('printer_paper_size', defaultValue: '80mm') as String;
    final int lineWidth = paperSize == '58mm' ? 32 : 48;
    final String sepLine = '-' * lineWidth;

    final actualFooter = box.get('receipt_footer', defaultValue: '') as String;
    final actualThankYou = box.get('receipt_thank_you', defaultValue: 'شكراً لزيارتكم • Merci pour votre visite') as String;

    List<int> bytes = [];
    bytes += EscPos.init;

    // Header (Center)
    bytes += EscPos.alignCenter;
    bytes += EscPos.boldOn;
    bytes += EscPos.textLarge;
    bytes += _textToBytes(shopName);
    bytes += EscPos.lineFeed;
    bytes += EscPos.textNormal;
    bytes += EscPos.boldOff;

    if (phone.isNotEmpty) {
      bytes += _textToBytes('Tel: $phone');
      bytes += EscPos.lineFeed;
    }

    bytes += _textToBytes(DateFormat('dd-MM-yyyy hh:mm a').format(DateTime.now()));
    bytes += EscPos.lineFeed;
    bytes += _textToBytes(sepLine);
    bytes += EscPos.lineFeed;

    // Items
    bytes += EscPos.alignLeft;
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

    // Total
    bytes += EscPos.alignRight;
    if (discount > 0) {
      bytes += _textToBytes('REMISE: -${discount.toStringAsFixed(2)} DA');
      bytes += EscPos.lineFeed;
    }
    bytes += EscPos.boldOn;
    bytes += _textToBytes('TOTAL: ${total.toStringAsFixed(2)} DA');
    bytes += EscPos.lineFeed;
    bytes += EscPos.boldOff;

    // Credit Section
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

    // Footer
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

  List<int> _textToBytes(String text) {
    return List.from(text.codeUnits);
  }
}

