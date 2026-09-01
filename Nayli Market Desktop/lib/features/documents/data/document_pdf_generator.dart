import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/data/hive_database.dart';
import '../../../../core/utils/app_constants.dart';
import '../domain/entities/commercial_document.dart';

class DocumentPdfGenerator {
  /// Generate A4 Commercial Document (Facture, Devis, BL, BC, BA)
  static Future<Uint8List> generateA4Document(CommercialDocument doc) async {
    final pdf = pw.Document();

    final shopName = HiveDatabase.settingsBox.get('shop_name', defaultValue: AppConstants.defaultShopName);
    final shopAddress = HiveDatabase.settingsBox.get('shop_address1', defaultValue: 'Alger, Algérie');
    final shopPhone = HiveDatabase.settingsBox.get('shop_phone', defaultValue: '0550 00 00 00');
    final shopEmail = HiveDatabase.settingsBox.get('shop_email', defaultValue: 'contact@naylimarket.dz');
    final shopRc = HiveDatabase.settingsBox.get('shop_rc', defaultValue: '16/00-1234567B22');
    final shopNif = HiveDatabase.settingsBox.get('shop_nif', defaultValue: '002216012345678');
    final shopNis = HiveDatabase.settingsBox.get('shop_nis', defaultValue: '0022160123456780000');
    final shopAi = HiveDatabase.settingsBox.get('shop_ai', defaultValue: '16012345678');
    final shopBank = HiveDatabase.settingsBox.get('shop_bank', defaultValue: 'BNA / CCP: 001234567 Clé 89');

    // Font loading for Arabic & Latin
    final font = await PdfGoogleFonts.cairoRegular();
    final fontBold = await PdfGoogleFonts.cairoBold();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header Block
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Shop Details
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(shopName, style: pw.TextStyle(font: fontBold, fontSize: 20, color: PdfColors.teal800)),
                        pw.SizedBox(height: 4),
                        pw.Text(shopAddress, style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey700)),
                        pw.Text('الهاتف: $shopPhone  |  البريد: $shopEmail', style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey700)),
                        pw.SizedBox(height: 4),
                        pw.Text('R.C: $shopRc   N.I.F: $shopNif', style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey600)),
                        pw.Text('N.I.S: $shopNis   Art. Imp: $shopAi', style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey600)),
                        if (shopBank.isNotEmpty)
                          pw.Text('الحساب: $shopBank', style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey600)),
                      ],
                    ),

                    // Document Badge & Info
                    pw.Container(
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.teal50,
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                        border: pw.Border.all(color: PdfColors.teal300),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(doc.type.titleAr, style: pw.TextStyle(font: fontBold, fontSize: 16, color: PdfColors.teal900)),
                          pw.Text(doc.type.titleFr, style: pw.TextStyle(font: fontBold, fontSize: 12, color: PdfColors.teal700)),
                          pw.SizedBox(height: 6),
                          pw.Text('الرقم: ${doc.reference}', style: pw.TextStyle(font: fontBold, fontSize: 12)),
                          pw.Text('التاريخ: ${DateFormat('yyyy/MM/dd').format(doc.createdAt)}', style: pw.TextStyle(font: font, fontSize: 10)),
                          if (doc.dueDate != null)
                            pw.Text('تاريخ الاستحقاق: ${DateFormat('yyyy/MM/dd').format(doc.dueDate!)}', style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.red700)),
                        ],
                      ),
                    ),
                  ],
                ),

                pw.SizedBox(height: 16),
                pw.Divider(color: PdfColors.teal200, thickness: 1.5),
                pw.SizedBox(height: 10),

                // Client Block
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('العميل / المستفيد (Client):', style: pw.TextStyle(font: fontBold, fontSize: 11, color: PdfColors.grey700)),
                          pw.Text(doc.clientName, style: pw.TextStyle(font: fontBold, fontSize: 14, color: PdfColors.black)),
                          if (doc.clientAddress != null && doc.clientAddress!.isNotEmpty)
                            pw.Text('العنوان: ${doc.clientAddress}', style: pw.TextStyle(font: font, fontSize: 10)),
                          if (doc.clientPhone != null && doc.clientPhone!.isNotEmpty)
                            pw.Text('الهاتف: ${doc.clientPhone}', style: pw.TextStyle(font: font, fontSize: 10)),
                        ],
                      ),
                      if (doc.clientNif != null || doc.clientRc != null)
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            if (doc.clientRc != null && doc.clientRc!.isNotEmpty)
                              pw.Text('R.C: ${doc.clientRc}', style: pw.TextStyle(font: font, fontSize: 9)),
                            if (doc.clientNif != null && doc.clientNif!.isNotEmpty)
                              pw.Text('N.I.F: ${doc.clientNif}', style: pw.TextStyle(font: font, fontSize: 9)),
                            if (doc.clientNis != null && doc.clientNis!.isNotEmpty)
                              pw.Text('N.I.S: ${doc.clientNis}', style: pw.TextStyle(font: font, fontSize: 9)),
                            if (doc.clientAi != null && doc.clientAi!.isNotEmpty)
                              pw.Text('Article: ${doc.clientAi}', style: pw.TextStyle(font: font, fontSize: 9)),
                          ],
                        ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 16),

                // Table of Items
                pw.TableHelper.fromTextArray(
                  context: context,
                  border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                  headerStyle: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.white),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.teal700),
                  cellStyle: pw.TextStyle(font: font, fontSize: 9),
                  cellAlignment: pw.Alignment.centerRight,
                  headers: <String>[
                    'المجموع HT',
                    'الرسم TVA',
                    'تخفيض %',
                    'سعر الوحدة HT',
                    'الكمية',
                    'التعيين والتسمية (Désignation)',
                    'المرجع',
                  ],
                  data: doc.items.map((item) {
                    return [
                      '${item.totalHt.toStringAsFixed(2)} د.ج',
                      '${item.tvaPercent.toStringAsFixed(0)}%',
                      item.discountPercent > 0 ? '${item.discountPercent.toStringAsFixed(0)}%' : '-',
                      '${item.unitPriceHt.toStringAsFixed(2)} د.ج',
                      item.quantity.toStringAsFixed(item.quantity % 1 == 0 ? 0 : 2),
                      item.designation,
                      item.barcode,
                    ];
                  }).toList(),
                ),

                pw.Spacer(),

                // Financial Summary Block & Signature
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    // Notes & Legal Stamp
                    pw.Expanded(
                      flex: 3,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          if (doc.notes != null && doc.notes!.isNotEmpty) ...[
                            pw.Text('ملاحظات وشروط:', style: pw.TextStyle(font: fontBold, fontSize: 10)),
                            pw.Text(doc.notes!, style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey700)),
                            pw.SizedBox(height: 10),
                          ],
                          pw.Container(
                            height: 70,
                            width: 180,
                            decoration: pw.BoxDecoration(
                              border: pw.Border.all(color: PdfColors.grey400, style: pw.BorderStyle.dashed),
                              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                            ),
                            alignment: pw.Alignment.topCenter,
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text('الختم والتوقيع (Cachet et Signature)',
                                style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey600)),
                          ),
                        ],
                      ),
                    ),

                    pw.SizedBox(width: 16),

                    // Totals Table
                    pw.Expanded(
                      flex: 2,
                      child: pw.Container(
                        padding: const pw.EdgeInsets.all(10),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.grey100,
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                          border: pw.Border.all(color: PdfColors.grey300),
                        ),
                        child: pw.Column(
                          children: [
                            _buildPdfTotalRow('المجموع الصافي HT:', '${doc.totalHt.toStringAsFixed(2)} د.ج', font, fontBold),
                            _buildPdfTotalRow('مجموع الرسوم TVA:', '${doc.totalTva.toStringAsFixed(2)} د.ج', font, fontBold),
                            if (doc.timbreFiscal > 0)
                              _buildPdfTotalRow('حق الطابع الجبائي:', '${doc.timbreFiscal.toStringAsFixed(2)} د.ج', font, fontBold),
                            pw.Divider(color: PdfColors.grey400),
                            _buildPdfTotalRow('المجموع الإجمالي TTC:', '${doc.totalTtc.toStringAsFixed(2)} د.ج', fontBold, fontBold, isBig: true),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                pw.SizedBox(height: 8),
                pw.Center(
                  child: pw.Text('تم إنشاء هذا المستند عبر نظام نايل ماركت (Nayli Market POS) • شكراً لثقتكم',
                      style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey500)),
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildPdfTotalRow(String title, String val, pw.Font font, pw.Font fontBold, {bool isBig = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(title, style: pw.TextStyle(font: isBig ? fontBold : font, fontSize: isBig ? 11 : 9)),
          pw.Text(val, style: pw.TextStyle(font: fontBold, fontSize: isBig ? 13 : 9, color: isBig ? PdfColors.teal900 : PdfColors.black)),
        ],
      ),
    );
  }

  /// Print document directly to printer
  static Future<void> printDocument(CommercialDocument doc) async {
    final pdfBytes = await generateA4Document(doc);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: '${doc.reference}.pdf',
    );
  }

  /// Send document via WhatsApp link
  static Future<void> sendViaWhatsApp({
    required CommercialDocument doc,
    required String phoneNumber,
  }) async {
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'\D'), '');
    final formattedPhone = cleanPhone.startsWith('0') ? '213${cleanPhone.substring(1)}' : cleanPhone;
    
    final message = '''
السلام عليكم ورحمة الله،
مرفق تفاصيل ${doc.type.titleAr}:
📌 الرقم: ${doc.reference}
📅 التاريخ: ${DateFormat('yyyy/MM/dd').format(doc.createdAt)}
👤 العميل: ${doc.clientName}
💰 المبلغ الإجمالي TTC: ${doc.totalTtc.toStringAsFixed(2)} د.ج

شكراً لتعاملكم معنا!
''';

    final uri = Uri.parse('https://wa.me/$formattedPhone?text=${Uri.encodeComponent(message)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
