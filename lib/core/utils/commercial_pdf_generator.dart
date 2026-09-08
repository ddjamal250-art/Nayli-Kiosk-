import 'dart:io';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../data/hive_database.dart';
import '../../features/shop/data/models/shop_model.dart';
import '../../features/documents/domain/entities/commercial_document.dart';

class CommercialPdfGenerator {
  /// Generate the PDF Document Byte Data
  static Future<Uint8List> generatePdfData(CommercialDocument doc) async {
    final pdf = pw.Document();

    // Load Arabic font via PdfGoogleFonts
    pw.Font ttf;
    try {
      ttf = await PdfGoogleFonts.cairoRegular();
    } catch (_) {
      try {
        ttf = await PdfGoogleFonts.amiriRegular();
      } catch (_) {
        ttf = pw.Font.helvetica();
      }
    }

    // Get Shop details
    String shopName = 'سوبرماركت البركة';
    String shopPhone = '0661xxxxxx';
    String shopAddress = 'الجلفة، الجزائر';
    String shopRc = '17/00-1234567';
    String shopNif = '001712345678901';
    String shopNis = '00171234567';
    String shopArt = '17011234567';
    String footerText = 'شكراً لتعاملكم معنا • مرحباً بكم دائماً';

    final shopBox = HiveDatabase.shopBox;
    if (shopBox.isNotEmpty) {
      final ShopModel? shop = shopBox.getAt(0);
      if (shop != null) {
        if (shop.name.isNotEmpty) shopName = shop.name;
        if (shop.phoneNumber.isNotEmpty) shopPhone = shop.phoneNumber;
        if (shop.addressLine1.isNotEmpty) shopAddress = shop.addressLine1;
        if (shop.footerText.isNotEmpty) footerText = shop.footerText;
      }
    }

    final settings = HiveDatabase.settingsBox;
    shopRc = settings.get('shop_rc', defaultValue: shopRc) as String;
    shopNif = settings.get('shop_nif', defaultValue: shopNif) as String;
    shopNis = settings.get('shop_nis', defaultValue: shopNis) as String;
    shopArt = settings.get('shop_art', defaultValue: shopArt) as String;

    final dateFormat = DateFormat('yyyy/MM/dd');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: ttf, bold: ttf),
        textDirection: pw.TextDirection.rtl,
        margin: const pw.EdgeInsets.all(28),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // Header (En-tête)
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Shop Info
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(shopName, style: pw.TextStyle(font: ttf, fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                      pw.SizedBox(height: 3),
                      pw.Text('العنوان: $shopAddress', style: pw.TextStyle(font: ttf, fontSize: 9.5, color: PdfColors.grey800)),
                      pw.Text('الهاتف: $shopPhone', style: pw.TextStyle(font: ttf, fontSize: 9.5, color: PdfColors.grey800)),
                      pw.Text('RC: $shopRc • NIF: $shopNif', style: pw.TextStyle(font: ttf, fontSize: 8.5, color: PdfColors.grey700)),
                      pw.Text('NIS: $shopNis • ART: $shopArt', style: pw.TextStyle(font: ttf, fontSize: 8.5, color: PdfColors.grey700)),
                    ],
                  ),

                  // Document Badge
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.indigo50,
                      borderRadius: pw.BorderRadius.circular(8),
                      border: pw.Border.all(color: PdfColors.indigo300),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          doc.typeLabelAr,
                          style: pw.TextStyle(font: ttf, fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'رقم: ${doc.documentNumber}',
                          style: pw.TextStyle(font: ttf, fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
                        ),
                        pw.Text(
                          'التاريخ: ${dateFormat.format(doc.date)}',
                          style: pw.TextStyle(font: ttf, fontSize: 9, color: PdfColors.grey800),
                        ),
                        if (doc.dueDate != null)
                          pw.Text(
                            'تاريخ الاستحقاق: ${dateFormat.format(doc.dueDate!)}',
                            style: pw.TextStyle(font: ttf, fontSize: 9, color: PdfColors.red800),
                          ),
                      ],
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 14),
              pw.Divider(color: PdfColors.grey400, thickness: 0.8),
              pw.SizedBox(height: 10),

              // Client / Supplier Info Box
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(color: PdfColors.grey300),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('العميل / المشتري:', style: pw.TextStyle(font: ttf, fontSize: 9, color: PdfColors.grey700)),
                        pw.Text(doc.entityName, style: pw.TextStyle(font: ttf, fontSize: 12, fontWeight: pw.FontWeight.bold)),
                        if (doc.entityAddress.isNotEmpty)
                          pw.Text('العنوان: ${doc.entityAddress}', style: pw.TextStyle(font: ttf, fontSize: 9)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        if (doc.entityPhone.isNotEmpty)
                          pw.Text('الهاتف: ${doc.entityPhone}', style: pw.TextStyle(font: ttf, fontSize: 9.5)),
                        if (doc.entityRc.isNotEmpty)
                          pw.Text('RC: ${doc.entityRc}', style: pw.TextStyle(font: ttf, fontSize: 8.5)),
                        if (doc.entityNif.isNotEmpty)
                          pw.Text('NIF: ${doc.entityNif}', style: pw.TextStyle(font: ttf, fontSize: 8.5)),
                      ],
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 14),

              // Items Table
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                columnWidths: {
                  0: const pw.FlexColumnWidth(1.2), // Total
                  1: const pw.FlexColumnWidth(1.1), // Unit Price
                  2: const pw.FlexColumnWidth(0.8), // Unit
                  3: const pw.FlexColumnWidth(0.8), // Qty
                  4: const pw.FlexColumnWidth(3.0), // Designation
                  5: const pw.FlexColumnWidth(0.5), // #
                },
                children: [
                  // Table Header
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.indigo900),
                    children: [
                      _buildHeaderCell('المجموع (DA)', ttf),
                      _buildHeaderCell('سعر الوحدة (DA)', ttf),
                      _buildHeaderCell('الوحدة', ttf),
                      _buildHeaderCell('الكمية', ttf),
                      _buildHeaderCell('تعيين السلعة (Désignation)', ttf),
                      _buildHeaderCell('#', ttf),
                    ],
                  ),
                  // Table Rows
                  ...doc.items.asMap().entries.map((entry) {
                    final index = entry.key + 1;
                    final item = entry.value;
                    final isEven = index % 2 == 0;
                    return pw.TableRow(
                      decoration: pw.BoxDecoration(color: isEven ? PdfColors.grey50 : PdfColors.white),
                      children: [
                        _buildCell(item.totalHT.toStringAsFixed(2), ttf, align: pw.TextAlign.left),
                        _buildCell(item.unitPrice.toStringAsFixed(2), ttf, align: pw.TextAlign.left),
                        _buildCell(item.unit, ttf),
                        _buildCell(item.quantity.toString(), ttf),
                        _buildCell(item.designation, ttf, align: pw.TextAlign.right),
                        _buildCell('$index', ttf),
                      ],
                    );
                  }),
                ],
              ),

              pw.SizedBox(height: 14),

              // Financial Summary & Signature Section
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Signature & Legal Notice Box
                  pw.Expanded(
                    flex: 3,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Container(
                          height: 70,
                          padding: const pw.EdgeInsets.all(8),
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(color: PdfColors.grey300),
                            borderRadius: pw.BorderRadius.circular(6),
                          ),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text('خاتم وتوقيع المؤسسة / الزبون:', style: pw.TextStyle(font: ttf, fontSize: 8.5, color: PdfColors.grey700)),
                              pw.Align(alignment: pw.Alignment.bottomLeft, child: pw.Text('Signature & Cachet', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey500))),
                            ],
                          ),
                        ),
                        pw.SizedBox(height: 6),
                        if (doc.notes != null && doc.notes!.isNotEmpty)
                          pw.Text('ملاحظة: ${doc.notes}', style: pw.TextStyle(font: ttf, fontSize: 8.5, color: PdfColors.grey800)),
                      ],
                    ),
                  ),

                  pw.SizedBox(width: 14),

                  // Financial Totals Table
                  pw.Expanded(
                    flex: 2,
                    child: pw.Table(
                      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                      children: [
                        _buildSummaryRow('المجموع الصافي قبل الضريبة:', '${doc.subtotalHT.toStringAsFixed(2)} DA', ttf),
                        if (doc.globalDiscount > 0)
                          _buildSummaryRow('الخصم التجاري:', '-${doc.globalDiscount.toStringAsFixed(2)} DA', ttf, isDiscount: true),
                        if (doc.totalTVA > 0)
                          _buildSummaryRow('الرسم على القيمة المضافة:', '${doc.totalTVA.toStringAsFixed(2)} DA', ttf),
                        _buildSummaryRow('المبلغ الإجمالي للدفع:', '${doc.netTotal.toStringAsFixed(2)} DA', ttf, isBold: true),
                        if (doc.previousBalance > 0)
                          _buildSummaryRow('الرصيد والديون السابقة:', '+${doc.previousBalance.toStringAsFixed(2)} DA', ttf),
                        _buildSummaryRow('الدفعة المسددة نقداً:', '${doc.amountPaid.toStringAsFixed(2)} DA', ttf, isPayment: true),
                        _buildSummaryRow('المبلغ المتبقي غير المسدد:', '${doc.remainingBalance.toStringAsFixed(2)} DA', ttf, isBold: true, isHighlight: true),
                      ],
                    ),
                  ),
                ],
              ),

              pw.Spacer(),

              // Footer
              pw.Divider(color: PdfColors.grey300, thickness: 0.5),
              pw.Center(
                child: pw.Text(
                  footerText,
                  style: pw.TextStyle(font: ttf, fontSize: 8.5, color: PdfColors.grey600),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildHeaderCell(String text, pw.Font font) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: pw.Text(
        text,
        style: pw.TextStyle(font: font, fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  static pw.Widget _buildCell(String text, pw.Font font, {pw.TextAlign align = pw.TextAlign.center}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      child: pw.Text(
        text,
        style: pw.TextStyle(font: font, fontSize: 8.5),
        textAlign: align,
      ),
    );
  }

  static pw.TableRow _buildSummaryRow(String label, String value, pw.Font font, {bool isBold = false, bool isHighlight = false, bool isDiscount = false, bool isPayment = false}) {
    return pw.TableRow(
      decoration: pw.BoxDecoration(
        color: isHighlight
            ? PdfColors.indigo50
            : (isPayment ? PdfColors.green50 : PdfColors.white),
      ),
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(4),
          child: pw.Text(
            value,
            style: pw.TextStyle(
              font: font,
              fontSize: isBold ? 9.5 : 8.5,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: isHighlight ? PdfColors.indigo900 : (isDiscount ? PdfColors.red800 : (isPayment ? PdfColors.green900 : PdfColors.black)),
            ),
            textAlign: pw.TextAlign.left,
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(4),
          child: pw.Text(
            label,
            style: pw.TextStyle(
              font: font,
              fontSize: isBold ? 9.5 : 8.5,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
            textAlign: pw.TextAlign.right,
          ),
        ),
      ],
    );
  }

  /// 1. Export PDF directly to Windows Desktop
  static Future<String> exportToDesktop(CommercialDocument doc) async {
    final pdfBytes = await generatePdfData(doc);
    final userProfile = Platform.environment['USERPROFILE'] ?? 'C:\\Users\\Admin';
    final desktopDir = Directory('$userProfile\\Desktop');

    final cleanDocNum = doc.documentNumber.replaceAll('/', '-');
    final cleanEntity = doc.entityName.replaceAll(' ', '_');
    final fileName = '${cleanDocNum}_$cleanEntity.pdf';
    final filePath = '${desktopDir.path}\\$fileName';

    final file = File(filePath);
    await file.writeAsBytes(pdfBytes);
    return filePath;
  }

  /// 2. Export PDF to Mobile Downloads / Documents Storage
  static Future<String> exportToMobileStorage(CommercialDocument doc) async {
    final pdfBytes = await generatePdfData(doc);
    Directory? baseDir;
    try {
      baseDir = await getDownloadsDirectory();
    } catch (_) {}
    baseDir ??= await getApplicationDocumentsDirectory();

    final cleanDocNum = doc.documentNumber.replaceAll('/', '-');
    final cleanEntity = doc.entityName.replaceAll(' ', '_');
    final fileName = '${cleanDocNum}_$cleanEntity.pdf';
    final filePath = '${baseDir.path}/$fileName';

    final file = File(filePath);
    await file.writeAsBytes(pdfBytes);
    return filePath;
  }

  /// 3. Share PDF directly to WhatsApp / Telegram / Email
  static Future<void> sharePdf(CommercialDocument doc) async {
    final filePath = await exportToMobileStorage(doc);
    await Share.shareXFiles(
      [XFile(filePath)],
      text: '${doc.typeLabelAr} رقم ${doc.documentNumber} - ${doc.entityName}',
    );
  }

  /// 4. Print Document Directly
  static Future<void> printDocument(CommercialDocument doc) async {
    final pdfBytes = await generatePdfData(doc);
    await Printing.layoutPdf(
      onLayout: (format) async => pdfBytes,
      name: '${doc.documentNumber}_${doc.entityName}',
    );
  }
}

