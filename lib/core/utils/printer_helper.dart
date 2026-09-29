import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  static bool isThermalPrinter(String printerName) {
    final lower = printerName.toLowerCase();
    const thermalKeywords = [
      'pos', 'thermal', 'receipt', 'ticket', '80', '58', 'xp-', 'xprinter',
      'tm-t', 'tm-m', 'star', 'citizen', 'epson tm', 'bixolon', 'zj', 'rp',
      'sp-pos', 'hoin', 'rongta', 'sunmi', 'gprinter', 'black copper', 'vsc',
      'zywell', 'netum', 'munbyn', 'milestone', 'isy'
    ];
    for (final kw in thermalKeywords) {
      if (lower.contains(kw)) return true;
    }
    return false;
  }

  static Printer? findBestThermalPrinter(List<Printer> printers) {
    if (printers.isEmpty) return null;
    
    // 1. Saved preference
    if (defaultThermalPrinter.isNotEmpty) {
      final saved = printers.where((p) => p.name == defaultThermalPrinter).firstOrNull;
      if (saved != null) return saved;
    }

    // 2. Scan printers for thermal keywords
    for (final p in printers) {
      if (isThermalPrinter(p.name)) {
        return p;
      }
    }

    return null;
  }

  static Future<void> openCashDrawer() async {
    try {
      final List<int> drawerCommand = [0x1B, 0x70, 0x00, 0x19, 0xFA];
      await PrintBluetoothThermal.writeBytes(drawerCommand);
    } catch (_) {}
  }

  static Future<pw.ThemeData> getArabicTheme() async {
    final fontReg = await rootBundle.load('assets/fonts/Tajawal-Regular.ttf');
    final fontBld = await rootBundle.load('assets/fonts/Tajawal-Bold.ttf');
    final ttfReg = pw.Font.ttf(fontReg);
    final ttfBld = pw.Font.ttf(fontBld);
    return pw.ThemeData.withFont(
      base: ttfReg,
      bold: ttfBld,
      italic: ttfReg,
      boldItalic: ttfBld,
    );
  }

  /// Print test page to verify connection and paper width
  static Future<bool> printTestPage(Printer printer, {PrinterRole role = PrinterRole.thermalReceipt}) async {
    try {
      final theme = await getArabicTheme();
      final doc = pw.Document();
      if (role == PrinterRole.thermalReceipt) {
        doc.addPage(
          pw.Page(
            pageFormat: const PdfPageFormat(80 * PdfPageFormat.mm, 100 * PdfPageFormat.mm, marginAll: 6 * PdfPageFormat.mm),
            theme: theme,
            build: (pw.Context ctx) {
              return pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text('Nayli Kiosk POS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
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
            theme: theme,
            build: (pw.Context ctx) {
              return pw.Center(
                child: pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    pw.Text('Nayli Kiosk Solutions - Test Page', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 22)),
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

  /// Sanitize text by stripping Unicode emojis that lack glyphs in standard TrueType fonts
  static String cleanEmojisForPdf(String text) {
    if (text.isEmpty) return text;
    return text
        .replaceAll('✨', '')
        .replaceAll('📍', '')
        .replaceAll('📞', '')
        .replaceAll('📱', '')
        .replaceAll('🛒', '')
        .replaceAll('🇩🇿', '')
        .replaceAll('🧾', '')
        .replaceAll('💾', '')
        .replaceAll('➕', '')
        .replaceAll('🎛️', '')
        .replaceAll('✍️', '')
        .replaceAll('✅', '')
        .replaceAll('⚠️', '')
        .replaceAll('❌', '')
        .replaceAll(RegExp(r'[\u{1F300}-\u{1F9FF}]|[\u{2600}-\u{26FF}]|[\u{2700}-\u{27BF}]|[\u{FE00}-\u{FE0F}]|[\u{1F000}-\u{1F02F}]|[\u{1F0A0}-\u{1F0FF}]', unicode: true), '')
        .trim();
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
    double coffeeAndTeaTotal = 0.0,
    bool isCredit = false,
    String? customerName,
    double previousDebt = 0.0,
    double paidAmount = 0.0,
    double newDebtTotal = 0.0,
    String? footer,
    String? specificPrinterName,
    String? invoiceId,
  }) async {
    try {
      final theme = await getArabicTheme();
      
      final box = HiveDatabase.settingsBox;
      final savedTemplate = box.get('receipt_template');
      Map<String, dynamic> tmpl = {};
      if (savedTemplate is Map) {
        tmpl = Map<String, dynamic>.from(savedTemplate);
      }
      
      final shopBox = HiveDatabase.shopBox;
      final defaultShopName = shopBox.isNotEmpty ? shopBox.values.first.name : 'متجر الأناقة والمواد الغذائية';
      final defaultPhone = shopBox.isNotEmpty ? shopBox.values.first.phoneNumber : '0550 12 34 56';
      final defaultAddress = shopBox.isNotEmpty ? shopBox.values.first.addressLine1 : 'حي 500 مسكن، الجلفة';

      final String finalShopName = cleanEmojisForPdf(tmpl['shopName']?.toString() ?? (shopName.isNotEmpty ? shopName : defaultShopName));
      final bool showSlogan = tmpl['showSlogan'] == true;
      final String slogan = cleanEmojisForPdf(tmpl['slogan']?.toString() ?? (address2 ?? 'مرحباً بكم في متجرنا'));
      final bool showAddress = tmpl['showAddress'] != false;
      final String address = cleanEmojisForPdf(tmpl['address']?.toString() ?? (address1 ?? defaultAddress));
      final bool showPhone = tmpl['showPhone'] != false;
      final String phoneStr = cleanEmojisForPdf(tmpl['phone']?.toString() ?? (phone ?? defaultPhone));
      final bool showFiscalInfo = tmpl['showFiscalInfo'] == true;
      final String fiscalInfo = cleanEmojisForPdf(tmpl['fiscalInfo']?.toString() ?? '');
      final bool showCashierName = tmpl['showCashierName'] != false;
      final String cashierName = cleanEmojisForPdf(tmpl['cashierName']?.toString() ?? 'الكاشير: سليم');
      final bool showSocialMedia = tmpl['showSocialMedia'] == true;
      final String socialMedia = cleanEmojisForPdf(tmpl['socialMedia']?.toString() ?? '');
      final bool showFooterNote = tmpl['showFooterNote'] != false;
      final String footerNote = cleanEmojisForPdf(tmpl['footerNote']?.toString() ?? (footer ?? 'السلعة المباعة لا ترد ولا تستبدل بعد 48 ساعة'));
      final bool showThankYou = tmpl['showThankYou'] != false;
      final String thankYou = cleanEmojisForPdf(tmpl['thankYou']?.toString() ?? 'شكراً لزيارتكم ونتشرف بخدمتكم دائماً');
      final bool showBarcodeAtBottom = tmpl['showBarcodeAtBottom'] != false;
      final String separatorStyle = tmpl['separatorStyle']?.toString() ?? 'dashed';
      final String headerAlignment = tmpl['headerAlignment']?.toString() ?? 'center';
      final List<String> customExtraLines = (tmpl['customExtraLines'] is Iterable)
          ? List<String>.from((tmpl['customExtraLines'] as Iterable).map((e) => cleanEmojisForPdf(e.toString())).where((s) => s.isNotEmpty))
          : [];

      final String displayInvoiceNumber = (invoiceId != null && invoiceId.isNotEmpty)
          ? (invoiceId.startsWith('FAC-') ? invoiceId : 'FAC-${invoiceId.length > 5 ? invoiceId.substring(invoiceId.length - 5) : invoiceId}')
          : 'FAC-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

      String getSeparatorText() {
        if (separatorStyle == 'stars') return '********************************';
        if (separatorStyle == 'double') return '================================';
        if (separatorStyle == 'dots') return '................................';
        return '--------------------------------';
      }
      
      final sep = pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
        child: pw.Center(
          child: pw.Text(getSeparatorText(), style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700), maxLines: 1),
        ),
      );

      final pw.CrossAxisAlignment crossAlign = headerAlignment == 'left'
          ? pw.CrossAxisAlignment.start
          : (headerAlignment == 'right' ? pw.CrossAxisAlignment.end : pw.CrossAxisAlignment.center);
      final pw.TextAlign headerTextAlign = headerAlignment == 'left'
          ? pw.TextAlign.left
          : (headerAlignment == 'right' ? pw.TextAlign.right : pw.TextAlign.center);

      final paperSize = box.get('printer_paper_size', defaultValue: '80mm') as String;
      final double rollWidthMm = paperSize == '58mm' ? 58.0 : 80.0;
      final double horizontalMarginMm = paperSize == '58mm' ? 4.0 : 6.0;

      // Defensive calculation: if total is 0 and items exist, re-sum from items so receipt never shows 0.00
      double effectiveTotal = total;
      if (effectiveTotal <= 0 && items.isNotEmpty) {
        effectiveTotal = items.fold<double>(0.0, (sum, i) => sum + ((i['total'] as num?)?.toDouble() ?? 0.0)) - discount;
        if (effectiveTotal < 0) effectiveTotal = 0.0;
      }

      // Calculate approximate height dynamically to prevent clipping or excessive blank feed
      double baseHeight = 155.0;
      if (showSlogan && slogan.isNotEmpty) baseHeight += 8.0;
      if (showAddress && address.isNotEmpty) baseHeight += 7.0;
      if (showPhone && phoneStr.isNotEmpty) baseHeight += 7.0;
      if (showFiscalInfo && fiscalInfo.isNotEmpty) baseHeight += 7.0;
      if (showSocialMedia && socialMedia.isNotEmpty) baseHeight += 7.0;
      if (showCashierName && cashierName.isNotEmpty) baseHeight += 7.0;
      if (discount > 0) baseHeight += 7.0;
      if (paidAmount > 0) baseHeight += 14.0;
      if (isCredit) baseHeight += 35.0;
      if (customExtraLines.isNotEmpty) baseHeight += (customExtraLines.length * 7.0);
      if (showFooterNote && footerNote.isNotEmpty) baseHeight += 12.0;
      if (showThankYou && thankYou.isNotEmpty) baseHeight += 12.0;
      if (showBarcodeAtBottom) baseHeight += 30.0;

      final double heightEstimate = (baseHeight + (items.length * 8.0)).clamp(160.0, 9999.0);

      final pageFormat = PdfPageFormat(
        rollWidthMm * PdfPageFormat.mm,
        heightEstimate * PdfPageFormat.mm,
        marginLeft: horizontalMarginMm * PdfPageFormat.mm,
        marginRight: horizontalMarginMm * PdfPageFormat.mm,
        marginTop: 6 * PdfPageFormat.mm,
        marginBottom: 10 * PdfPageFormat.mm,
      );
      
      final doc = pw.Document();
      doc.addPage(
        pw.Page(
          pageFormat: pageFormat,
          theme: theme,
          build: (pw.Context ctx) {
            return pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Column(
                crossAxisAlignment: crossAlign,
                children: [
                  // Store Header
                  pw.Text(
                    finalShopName.isEmpty ? 'اسم المحل' : finalShopName,
                    textAlign: headerTextAlign,
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13.5),
                  ),
                  if (showSlogan && slogan.isNotEmpty) ...[
                    pw.SizedBox(height: 2),
                    pw.Text(slogan, textAlign: headerTextAlign, style: const pw.TextStyle(fontSize: 9.0)),
                  ],
                  if (showAddress && address.isNotEmpty) ...[
                    pw.SizedBox(height: 1.5),
                    pw.Text(address, textAlign: headerTextAlign, style: const pw.TextStyle(fontSize: 8)),
                  ],
                  if (showPhone && phoneStr.isNotEmpty) ...[
                    pw.SizedBox(height: 1.5),
                    pw.Text(phoneStr, textAlign: headerTextAlign, style: const pw.TextStyle(fontSize: 8)),
                  ],
                  if (showFiscalInfo && fiscalInfo.isNotEmpty) ...[
                    pw.SizedBox(height: 1.5),
                    pw.Text(fiscalInfo, textAlign: headerTextAlign, style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
                  ],
                  if (showSocialMedia && socialMedia.isNotEmpty) ...[
                    pw.SizedBox(height: 1.5),
                    pw.Text(socialMedia, textAlign: headerTextAlign, style: const pw.TextStyle(fontSize: 8)),
                  ],
                  
                  sep,
                  
                  // Invoice ID and Date
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('وصل رقم: #$displayInvoiceNumber', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                      pw.Text(DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()), style: const pw.TextStyle(fontSize: 8)),
                    ],
                  ),
                  if (showCashierName && cashierName.isNotEmpty) ...[
                    pw.SizedBox(height: 1.5),
                    pw.Align(
                      alignment: pw.Alignment.centerRight,
                      child: pw.Text(cashierName, style: const pw.TextStyle(fontSize: 8)),
                    ),
                  ],
                  
                  sep,
                  
                  // Table Header
                  pw.Row(
                    children: [
                      pw.Expanded(
                        flex: 5,
                        child: pw.Text('السلعة', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Text('الكمية', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Expanded(
                        flex: 3,
                        child: pw.Text('السعر', textAlign: pw.TextAlign.left, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 2),

                  // Table Items Loop
                  ...items.map((item) {
                    final rawName = item['name']?.toString() ?? 'منتج';
                    final cleanName = cleanEmojisForPdf(rawName);

                    final dynamic rawQty = item['qty'];
                    final dynamic rawWeight = item['weightKg'];
                    String qtyStr = '1';
                    if (rawWeight != null && rawWeight is num && rawWeight > 0) {
                      qtyStr = '${rawWeight.toStringAsFixed(3)}كغ';
                    } else if (rawQty is num) {
                      if (rawQty == rawQty.roundToDouble()) {
                        qtyStr = rawQty.toInt().toString();
                      } else {
                        qtyStr = rawQty.toStringAsFixed(2);
                      }
                    } else if (rawQty != null) {
                      qtyStr = rawQty.toString();
                    }

                    final double itemTotal = (item['total'] as num?)?.toDouble() ?? 0.0;
                    final String totalStr = '${itemTotal.toStringAsFixed(2)} دج';

                    return pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
                      child: pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Expanded(
                            flex: 5,
                            child: pw.Text(cleanName, style: const pw.TextStyle(fontSize: 8)),
                          ),
                          pw.Expanded(
                            flex: 2,
                            child: pw.Text(qtyStr, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 8)),
                          ),
                          pw.Expanded(
                            flex: 3,
                            child: pw.Text(totalStr, textAlign: pw.TextAlign.left, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                          ),
                        ],
                      ),
                    );
                  }),
                  
                  sep,
                  
                  // Total & Discounts
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('المجموع الإجمالي (Total):', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      pw.Text('${effectiveTotal.toStringAsFixed(2)} دج', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                    ],
                  ),

                  if (discount > 0) ...[
                    pw.SizedBox(height: 1.5),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('التخفيض:', style: const pw.TextStyle(fontSize: 8)),
                        pw.Text('-${discount.toStringAsFixed(2)} دج', style: const pw.TextStyle(fontSize: 8)),
                      ],
                    ),
                  ],

                  if (paidAmount > 0) ...[
                    pw.SizedBox(height: 1.5),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('المبلغ المدفوع (Espèce):', style: const pw.TextStyle(fontSize: 8)),
                        pw.Text('${paidAmount.toStringAsFixed(2)} دج', style: const pw.TextStyle(fontSize: 8)),
                      ],
                    ),
                  ],

                  if (paidAmount > effectiveTotal) ...[
                    pw.SizedBox(height: 1.5),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('المبلغ المتبقي (Rendu):', style: const pw.TextStyle(fontSize: 8)),
                        pw.Text('${(paidAmount - effectiveTotal).toStringAsFixed(2)} دج', style: const pw.TextStyle(fontSize: 8)),
                      ],
                    ),
                  ],
                  
                  // Credit Block
                  if (isCredit && customerName != null && customerName.isNotEmpty) ...[
                    sep,
                    pw.Align(
                      alignment: pw.Alignment.centerRight,
                      child: pw.Text('حساب كريدي الزبون: $customerName', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5)),
                    ),
                    if (previousDebt > 0) ...[
                      pw.SizedBox(height: 1),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('الديون السابقة:', style: const pw.TextStyle(fontSize: 8)),
                          pw.Text('${previousDebt.toStringAsFixed(2)} دج', style: const pw.TextStyle(fontSize: 8)),
                        ],
                      ),
                    ],
                    pw.SizedBox(height: 1),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('مشتريات اليوم:', style: const pw.TextStyle(fontSize: 8)),
                        pw.Text('${effectiveTotal.toStringAsFixed(2)} دج', style: const pw.TextStyle(fontSize: 8)),
                      ],
                    ),
                    if (paidAmount > 0) ...[
                      pw.SizedBox(height: 1),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('الدفعة المسددة:', style: const pw.TextStyle(fontSize: 8)),
                          pw.Text('${paidAmount.toStringAsFixed(2)} دج', style: const pw.TextStyle(fontSize: 8)),
                        ],
                      ),
                    ],
                    pw.SizedBox(height: 1),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('إجمالي الديون المتبقية:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                        pw.Text('${newDebtTotal.toStringAsFixed(2)} دج', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                      ],
                    ),
                  ],

                  // Custom Extra Lines
                  if (customExtraLines.isNotEmpty) ...[
                    sep,
                    ...customExtraLines.map((line) => pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 1),
                      child: pw.Center(
                        child: pw.Text(line, textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                      ),
                    )),
                  ],
                  
                  // Footer Note & Thank You
                  if (showFooterNote && footerNote.isNotEmpty) ...[
                    pw.SizedBox(height: 3),
                    pw.Center(
                      child: pw.Text(footerNote, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 8)),
                    ),
                  ],

                  if (showThankYou && thankYou.isNotEmpty) ...[
                    pw.SizedBox(height: 3),
                    pw.Center(
                      child: pw.Text(thankYou, textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                    ),
                  ],

                  // Barcode / QR Code
                  if (showBarcodeAtBottom) ...[
                    pw.SizedBox(height: 5),
                    pw.Center(
                      child: pw.BarcodeWidget(
                        barcode: pw.Barcode.qrCode(),
                        data: displayInvoiceNumber,
                        width: 44,
                        height: 44,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Center(
                      child: pw.Text('* $displayInvoiceNumber *', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
                    ),
                  ],
                  pw.SizedBox(height: 6),
                ],
              ),
            );
          },
        ),
      );

      final bytes = await doc.save();
      final printers = await Printing.listPrinters();
      
      Printer? target;
      if (specificPrinterName != null && specificPrinterName.isNotEmpty) {
        target = printers.where((p) => p.name == specificPrinterName).firstOrNull;
      }
      target ??= findBestThermalPrinter(printers);

      if (target != null) {
        return await Printing.directPrintPdf(printer: target, onLayout: (_) => bytes, usePrinterSettings: true);
      } else {
        return await Printing.layoutPdf(onLayout: (_) => bytes, name: 'Nayli_Receipt_$displayInvoiceNumber');
      }
    } catch (e) {
      debugPrint('Print Error: $e');
      return false;
    }
  }

  // -------------------------------------------------------------
  // Mobile Bluetooth Thermal Section (Android / iOS)
  // -------------------------------------------------------------
  Future<bool> checkPermission() async {
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) return false;
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
      if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) return [];
      final List<BluetoothInfo> list = await PrintBluetoothThermal.pairedBluetooths;
      return list;
    } catch (e) {
      return [];
    }
  }

  Future<bool> connect(String macAddress) async {
    try {
      if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) return false;
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
      if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        _isConnected = false;
        return true;
      }
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
    String? specificPrinterName,
    String? invoiceId,
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
        specificPrinterName: specificPrinterName,
        invoiceId: invoiceId,
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

