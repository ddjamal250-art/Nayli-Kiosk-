import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../features/product/domain/entities/product.dart';
import '../data/hive_database.dart';
import '../../features/shop/data/models/shop_model.dart';
import 'app_constants.dart';

enum ShelfLabelSize {
  standard50x30,
  compact40x30,
  mini38x25,
  roll80mm,
  sheetA4_24,
  sheetA4_40,
  custom,
}

extension ShelfLabelSizeExtension on ShelfLabelSize {
  String get displayName {
    switch (this) {
      case ShelfLabelSize.standard50x30:
        return '50 × 30 مم (معيار السوبرماركت)';
      case ShelfLabelSize.compact40x30:
        return '40 × 30 مم (لاصقة مدمجة)';
      case ShelfLabelSize.mini38x25:
        return '38 × 25 مم (علب صغيرة)';
      case ShelfLabelSize.roll80mm:
        return 'رول حراري متصل (80 مم)';
      case ShelfLabelSize.sheetA4_24:
        return 'ورقة A4 مقسمة (24 ملصق - 3×8)';
      case ShelfLabelSize.sheetA4_40:
        return 'ورقة A4 مقسمة (40 ملصق - 4×10)';
      case ShelfLabelSize.custom:
        return 'مخصص بأبعاد يدوية (Custom)';
    }
  }

  bool get isSheetA4 => this == ShelfLabelSize.sheetA4_24 || this == ShelfLabelSize.sheetA4_40;

  PdfPageFormat get pageFormat {
    switch (this) {
      case ShelfLabelSize.standard50x30:
        return const PdfPageFormat(
          50 * PdfPageFormat.mm,
          30 * PdfPageFormat.mm,
          marginLeft: 1.5 * PdfPageFormat.mm,
          marginRight: 1.5 * PdfPageFormat.mm,
          marginTop: 1.0 * PdfPageFormat.mm,
          marginBottom: 1.0 * PdfPageFormat.mm,
        );
      case ShelfLabelSize.compact40x30:
        return const PdfPageFormat(
          40 * PdfPageFormat.mm,
          30 * PdfPageFormat.mm,
          marginLeft: 1.2 * PdfPageFormat.mm,
          marginRight: 1.2 * PdfPageFormat.mm,
          marginTop: 1.0 * PdfPageFormat.mm,
          marginBottom: 1.0 * PdfPageFormat.mm,
        );
      case ShelfLabelSize.mini38x25:
        return const PdfPageFormat(
          38 * PdfPageFormat.mm,
          25 * PdfPageFormat.mm,
          marginLeft: 1.0 * PdfPageFormat.mm,
          marginRight: 1.0 * PdfPageFormat.mm,
          marginTop: 1.0 * PdfPageFormat.mm,
          marginBottom: 1.0 * PdfPageFormat.mm,
        );
      case ShelfLabelSize.roll80mm:
        return const PdfPageFormat(
          76 * PdfPageFormat.mm,
          45 * PdfPageFormat.mm,
          marginAll: 2.0 * PdfPageFormat.mm,
        );
      case ShelfLabelSize.sheetA4_24:
      case ShelfLabelSize.sheetA4_40:
        return PdfPageFormat.a4;
      case ShelfLabelSize.custom:
        return const PdfPageFormat(
          50 * PdfPageFormat.mm,
          30 * PdfPageFormat.mm,
          marginAll: 1.5 * PdfPageFormat.mm,
        );
    }
  }
}

enum ShelfLabelTemplate {
  shelfTag,
  productSticker,
  scaleWeight,
}

extension ShelfLabelTemplateExtension on ShelfLabelTemplate {
  String get displayName {
    switch (this) {
      case ShelfLabelTemplate.shelfTag:
        return 'بطاقة الرف الكلاسيكية (السعر الضخم)';
      case ShelfLabelTemplate.productSticker:
        return 'لاصقة السلعة والباركود (منتجات بدون كود)';
      case ShelfLabelTemplate.scaleWeight:
        return 'ملصق الميزان الذكي (سعر الكغ والوزن)';
    }
  }
}

class ShelfLabelConfig {
  final ShelfLabelSize size;
  final ShelfLabelTemplate template;
  final bool includeShopName;
  final bool includeDate;
  final bool includeBarcode;
  final bool showHriDigits;
  final double barcodeHeight;
  final String currencySymbol;
  final String shopName;
  final double customWidthMm;
  final double customHeightMm;
  final double customMarginMm;

  const ShelfLabelConfig({
    this.size = ShelfLabelSize.standard50x30,
    this.template = ShelfLabelTemplate.shelfTag,
    this.includeShopName = true,
    this.includeDate = true,
    this.includeBarcode = true,
    this.showHriDigits = true,
    this.barcodeHeight = 12.0,
    this.currencySymbol = 'دج',
    this.shopName = 'سوبرماركت النايلي',
    this.customWidthMm = 50.0,
    this.customHeightMm = 30.0,
    this.customMarginMm = 1.5,
  });

  PdfPageFormat get effectivePageFormat {
    if (size == ShelfLabelSize.custom) {
      return PdfPageFormat(
        customWidthMm * PdfPageFormat.mm,
        customHeightMm * PdfPageFormat.mm,
        marginLeft: customMarginMm * PdfPageFormat.mm,
        marginRight: customMarginMm * PdfPageFormat.mm,
        marginTop: (customMarginMm * 0.8) * PdfPageFormat.mm,
        marginBottom: (customMarginMm * 0.8) * PdfPageFormat.mm,
      );
    }
    return size.pageFormat;
  }

  ShelfLabelConfig copyWith({
    ShelfLabelSize? size,
    ShelfLabelTemplate? template,
    bool? includeShopName,
    bool? includeDate,
    bool? includeBarcode,
    bool? showHriDigits,
    double? barcodeHeight,
    String? currencySymbol,
    String? shopName,
    double? customWidthMm,
    double? customHeightMm,
    double? customMarginMm,
  }) {
    return ShelfLabelConfig(
      size: size ?? this.size,
      template: template ?? this.template,
      includeShopName: includeShopName ?? this.includeShopName,
      includeDate: includeDate ?? this.includeDate,
      includeBarcode: includeBarcode ?? this.includeBarcode,
      showHriDigits: showHriDigits ?? this.showHriDigits,
      barcodeHeight: barcodeHeight ?? this.barcodeHeight,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      shopName: shopName ?? this.shopName,
      customWidthMm: customWidthMm ?? this.customWidthMm,
      customHeightMm: customHeightMm ?? this.customHeightMm,
      customMarginMm: customMarginMm ?? this.customMarginMm,
    );
  }
}

class ShelfLabelGenerator {
  static String getEffectiveShopName() {
    String name = AppConstants.defaultShopName;
    final shopBox = HiveDatabase.shopBox;
    if (shopBox.isNotEmpty) {
      final ShopModel? shop = shopBox.getAt(0);
      if (shop != null && shop.name.isNotEmpty) {
        name = shop.name;
      }
    }
    return cleanEmojisForPdf(name);
  }

  /// Sanitize text by stripping emojis that lack glyphs in standard TrueType fonts
  static String cleanEmojisForPdf(String text) {
    if (text.isEmpty) return text;
    return text
        .replaceAll('⚖️', '')
        .replaceAll('✨', '')
        .replaceAll('🏷️', '')
        .replaceAll('📦', '')
        .replaceAll('🛒', '')
        .replaceAll('🇩🇿', '')
        .replaceAll('✅', '')
        .replaceAll('⚠️', '')
        .replaceAll('❌', '')
        .replaceAll(RegExp(r'[\u{1F300}-\u{1F9FF}]|[\u{2600}-\u{26FF}]|[\u{2700}-\u{27BF}]|[\u{FE00}-\u{FE0F}]|[\u{1F000}-\u{1F02F}]|[\u{1F0A0}-\u{1F0FF}]', unicode: true), '')
        .trim();
  }

  /// Strip invalid characters so barcode encoders never throw
  static String sanitizeBarcodeData(String code) {
    return code.replaceAll(RegExp(r'[^\x20-\x7E]'), '').trim();
  }

  static bool isValidEan13(String code) {
    if (code.length != 13 || !RegExp(r'^\d{13}$').hasMatch(code)) return false;
    int sum = 0;
    for (int i = 0; i < 12; i++) {
      final d = int.parse(code[i]);
      sum += (i % 2 == 0) ? d : d * 3;
    }
    final check = (10 - (sum % 10)) % 10;
    return check == int.parse(code[12]);
  }

  static bool isValidEan8(String code) {
    if (code.length != 8 || !RegExp(r'^\d{8}$').hasMatch(code)) return false;
    int sum = 0;
    for (int i = 0; i < 7; i++) {
      final d = int.parse(code[i]);
      sum += (i % 2 == 0) ? d * 3 : d;
    }
    final check = (10 - (sum % 10)) % 10;
    return check == int.parse(code[7]);
  }

  static pw.Barcode getBarcodeAlgorithm(String code) {
    final clean = sanitizeBarcodeData(code);
    if (isValidEan13(clean)) {
      try {
        return pw.Barcode.ean13();
      } catch (_) {
        return pw.Barcode.code128();
      }
    }
    if (isValidEan8(clean)) {
      try {
        return pw.Barcode.ean8();
      } catch (_) {
        return pw.Barcode.code128();
      }
    }
    return pw.Barcode.code128();
  }

  static Future<Uint8List> generateLabelsPdf({
    required List<MapEntry<Product, int>> itemsWithCopies,
    required ShelfLabelConfig config,
  }) async {
    final doc = pw.Document();

    final fontRegData = await rootBundle.load('assets/fonts/Tajawal-Regular.ttf');
    final fontBldData = await rootBundle.load('assets/fonts/Tajawal-Bold.ttf');
    final fontRegular = pw.Font.ttf(fontRegData);
    final fontBold = pw.Font.ttf(fontBldData);
    final theme = pw.ThemeData.withFont(
      base: fontRegular,
      bold: fontBold,
      italic: fontRegular,
      boldItalic: fontBold,
    );

    // Expand items by copy count
    final List<Product> flatProducts = [];
    for (final entry in itemsWithCopies) {
      for (int i = 0; i < entry.value; i++) {
        flatProducts.add(entry.key);
      }
    }

    if (flatProducts.isEmpty) {
      return doc.save();
    }

    if (config.size.isSheetA4) {
      // Generate A4 Sheet (24 or 40 grid)
      _generateA4Sheet(doc, flatProducts, config, theme, fontRegular, fontBold);
    } else {
      // Individual Roll Labels (Page per label) using dynamic effective page format
      final format = config.effectivePageFormat;
      for (final p in flatProducts) {
        doc.addPage(
          pw.Page(
            pageFormat: format,
            theme: theme,
            build: (ctx) => _buildSingleLabelContent(p, config, fontRegular, fontBold),
          ),
        );
      }
    }

    return doc.save();
  }

  static void _generateA4Sheet(
    pw.Document doc,
    List<Product> products,
    ShelfLabelConfig config,
    pw.ThemeData theme,
    pw.Font fontRegular,
    pw.Font fontBold,
  ) {
    final is24 = config.size == ShelfLabelSize.sheetA4_24;
    final cols = is24 ? 3 : 4;
    final rows = is24 ? 8 : 10;
    final perPage = cols * rows;

    for (int i = 0; i < products.length; i += perPage) {
      final chunk = products.skip(i).take(perPage).toList();

      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(horizontal: 10 * PdfPageFormat.mm, vertical: 12 * PdfPageFormat.mm),
          theme: theme,
          build: (ctx) {
            return pw.GridView(
              crossAxisCount: cols,
              childAspectRatio: is24 ? (70 / 37) : (48 / 25),
              crossAxisSpacing: 3 * PdfPageFormat.mm,
              mainAxisSpacing: 3 * PdfPageFormat.mm,
              children: chunk.map((p) {
                return pw.Container(
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                    borderRadius: pw.BorderRadius.circular(3),
                  ),
                  padding: const pw.EdgeInsets.all(2 * PdfPageFormat.mm),
                  child: _buildSingleLabelContent(p, config, fontRegular, fontBold, compact: true),
                );
              }).toList(),
            );
          },
        ),
      );
    }
  }

  static pw.Widget _buildSingleLabelContent(
    Product p,
    ShelfLabelConfig config,
    pw.Font fontRegular,
    pw.Font fontBold, {
    bool compact = false,
  }) {
    final dateStr = DateFormat('dd/MM/yyyy').format(DateTime.now());
    final isMini = config.size == ShelfLabelSize.mini38x25 ||
        (config.size == ShelfLabelSize.custom && config.customHeightMm <= 26.0) ||
        compact;
    final cleanBarcode = sanitizeBarcodeData(p.barcode);
    final hasBarcode = config.includeBarcode && cleanBarcode.isNotEmpty;
    final priceStr = p.price.toStringAsFixed(0);

    switch (config.template) {
      case ShelfLabelTemplate.shelfTag:
        return pw.Directionality(textDirection: pw.TextDirection.rtl, child: _buildShelfTagTemplate(p, config, fontBold, fontRegular, dateStr, isMini, hasBarcode, cleanBarcode, priceStr));
      case ShelfLabelTemplate.productSticker:
        return pw.Directionality(textDirection: pw.TextDirection.rtl, child: _buildProductStickerTemplate(p, config, fontBold, fontRegular, dateStr, isMini, hasBarcode, cleanBarcode, priceStr));
      case ShelfLabelTemplate.scaleWeight:
        return pw.Directionality(textDirection: pw.TextDirection.rtl, child: _buildScaleWeightTemplate(p, config, fontBold, fontRegular, dateStr, isMini, hasBarcode, cleanBarcode, priceStr));
    }
  }

  static pw.Widget _buildShelfTagTemplate(
    Product p,
    ShelfLabelConfig config,
    pw.Font fontBold,
    pw.Font fontRegular,
    String dateStr,
    bool isMini,
    bool hasBarcode,
    String cleanBarcode,
    String priceStr,
  ) {
    final cleanName = cleanEmojisForPdf(p.name);
    final cleanShop = cleanEmojisForPdf(config.shopName);
    final double barcodeH = config.size == ShelfLabelSize.custom
        ? (config.customHeightMm * 0.28).clamp(7.0, 24.0)
        : (isMini ? 9.0 : config.barcodeHeight);

    return pw.Directionality(
      textDirection: pw.TextDirection.rtl,
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          // Header: Shop Name & Unit
          if (config.includeShopName)
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  cleanShop,
                  style: pw.TextStyle(fontSize: isMini ? 6 : 7.5, font: fontBold, color: PdfColors.grey700),
                ),
                pw.Text(
                  p.isWeighted ? 'بالكيلوغرام' : 'بالقطعة',
                  style: pw.TextStyle(fontSize: isMini ? 5.5 : 6.5, font: fontRegular, color: PdfColors.grey600),
                ),
              ],
            ),

          // Product Name
          pw.Text(
            cleanName,
            style: pw.TextStyle(fontSize: isMini ? 8 : 9.5, font: fontBold),
            maxLines: 1,
            overflow: pw.TextOverflow.clip,
            textAlign: pw.TextAlign.center,
          ),

          // Huge Price
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                priceStr,
                style: pw.TextStyle(fontSize: isMini ? 15 : 20, font: fontBold, color: PdfColors.black),
              ),
              pw.SizedBox(width: 3),
              pw.Text(
                config.currencySymbol,
                style: pw.TextStyle(fontSize: isMini ? 7.5 : 9.5, font: fontBold, color: PdfColors.black),
              ),
            ],
          ),

          // Barcode (Real 1D Vector Barcode)
          if (hasBarcode)
            pw.Container(
              height: barcodeH,
              child: pw.BarcodeWidget(
                barcode: getBarcodeAlgorithm(cleanBarcode),
                data: cleanBarcode,
                drawText: config.showHriDigits && !isMini,
                color: PdfColors.black,
                textStyle: pw.TextStyle(fontSize: 6, font: fontRegular),
              ),
            ),

          // Footer: Date
          if (config.includeDate)
            pw.Align(
              alignment: pw.Alignment.centerLeft,
              child: pw.Text(
                dateStr,
                style: pw.TextStyle(fontSize: 5, font: fontRegular, color: PdfColors.grey600),
              ),
            ),
        ],
      ),
    );
  }

  static pw.Widget _buildProductStickerTemplate(
    Product p,
    ShelfLabelConfig config,
    pw.Font fontBold,
    pw.Font fontRegular,
    String dateStr,
    bool isMini,
    bool hasBarcode,
    String cleanBarcode,
    String priceStr,
  ) {
    final cleanName = cleanEmojisForPdf(p.name);

    return pw.Directionality(
      textDirection: pw.TextDirection.rtl,
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          // Top: Product Name
          pw.Text(
            cleanName,
            style: pw.TextStyle(fontSize: isMini ? 7.5 : 9, font: fontBold),
            maxLines: 1,
            overflow: pw.TextOverflow.clip,
            textAlign: pw.TextAlign.center,
          ),

          // Center: Large Prominent Barcode
          if (hasBarcode)
            pw.Expanded(
              child: pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
                child: pw.BarcodeWidget(
                  barcode: getBarcodeAlgorithm(cleanBarcode),
                  data: cleanBarcode,
                  drawText: config.showHriDigits,
                  color: PdfColors.black,
                  textStyle: pw.TextStyle(fontSize: 6.5, font: fontRegular),
                ),
              ),
            ),

          // Bottom Bar: Price & Date
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              if (config.includeDate)
                pw.Text(dateStr, style: pw.TextStyle(fontSize: 5.5, font: fontRegular, color: PdfColors.grey600))
              else
                pw.SizedBox(),
              pw.Row(
                children: [
                  pw.Text(
                    priceStr,
                    style: pw.TextStyle(fontSize: isMini ? 10 : 12, font: fontBold),
                  ),
                  pw.SizedBox(width: 2),
                  pw.Text(config.currencySymbol, style: pw.TextStyle(fontSize: 7, font: fontBold)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildScaleWeightTemplate(
    Product p,
    ShelfLabelConfig config,
    pw.Font fontBold,
    pw.Font fontRegular,
    String dateStr,
    bool isMini,
    bool hasBarcode,
    String cleanBarcode,
    String priceStr,
  ) {
    final cleanName = cleanEmojisForPdf(p.name);
    final cleanShop = cleanEmojisForPdf(config.shopName);
    final double barcodeH = config.size == ShelfLabelSize.custom
        ? (config.customHeightMm * 0.28).clamp(7.0, 24.0)
        : (isMini ? 9.0 : config.barcodeHeight);

    return pw.Directionality(
      textDirection: pw.TextDirection.rtl,
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          if (config.includeShopName)
            pw.Text(
              '[ميزان] $cleanShop',
              style: pw.TextStyle(fontSize: isMini ? 6 : 7.5, font: fontBold, color: PdfColors.teal800),
            ),

          pw.Text(
            cleanName,
            style: pw.TextStyle(fontSize: isMini ? 8 : 10, font: fontBold),
            maxLines: 1,
            overflow: pw.TextOverflow.clip,
            textAlign: pw.TextAlign.center,
          ),

          // Price per Kg
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Text(
              'السعر: $priceStr ${config.currencySymbol} / كغ',
              style: pw.TextStyle(fontSize: isMini ? 10 : 12.5, font: fontBold, color: PdfColors.black),
            ),
          ),

          // Barcode
          if (hasBarcode)
            pw.Container(
              height: barcodeH,
              child: pw.BarcodeWidget(
                barcode: getBarcodeAlgorithm(cleanBarcode),
                data: cleanBarcode,
                drawText: config.showHriDigits,
                color: PdfColors.black,
                textStyle: pw.TextStyle(fontSize: 6, font: fontRegular),
              ),
            ),

          // Date & Scale notice
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('طازج يوميا', style: pw.TextStyle(fontSize: 5.5, font: fontRegular, color: PdfColors.teal700)),
              if (config.includeDate)
                pw.Text(dateStr, style: pw.TextStyle(fontSize: 5.5, font: fontRegular, color: PdfColors.grey600)),
            ],
          ),
        ],
      ),
    );
  }

  /// Generates native ESC/POS thermal printer commands for 80mm/58mm rolls
  static List<int> generateEscPosBytes({
    required List<MapEntry<Product, int>> itemsWithCopies,
    required ShelfLabelConfig config,
  }) {
    final List<int> bytes = [];

    for (final entry in itemsWithCopies) {
      final p = entry.key;
      final count = entry.value;

      for (int c = 0; c < count; c++) {
        bytes.addAll([27, 64]); // Init
        bytes.addAll([27, 97, 1]); // Center

        if (config.includeShopName) {
          bytes.addAll([27, 33, 0]); // Normal
          bytes.addAll('${config.shopName}\n'.codeUnits);
        }

        bytes.addAll([27, 33, 16]); // Double height
        bytes.addAll('${p.name}\n'.codeUnits);

        bytes.addAll([27, 33, 48]); // Huge Double width + Double height
        bytes.addAll('${p.price.toStringAsFixed(0)} DZD\n'.codeUnits);

        if (config.includeBarcode && p.barcode.trim().isNotEmpty) {
          final cleanBarcode = p.barcode.trim();
          bytes.addAll([29, 104, (config.barcodeHeight * 3).toInt().clamp(30, 90)]); // GS h (barcode height)
          bytes.addAll([29, 119, 2]); // GS w (barcode width)
          bytes.addAll([29, 72, config.showHriDigits ? 2 : 0]); // GS H (HRI position below)
          bytes.addAll([29, 107, 73, cleanBarcode.length]); // GS k (Code 128)
          bytes.addAll(cleanBarcode.codeUnits);
          bytes.addAll([10]); // Line feed
        }

        if (config.includeDate) {
          bytes.addAll([27, 33, 0]);
          bytes.addAll('Date: ${DateFormat("yyyy/MM/dd").format(DateTime.now())}\n'.codeUnits);
        }

        bytes.addAll('--------------------------------\n\n'.codeUnits);
      }
    }

    bytes.addAll([29, 86, 66, 0]); // Cut paper
    return bytes;
  }
}
