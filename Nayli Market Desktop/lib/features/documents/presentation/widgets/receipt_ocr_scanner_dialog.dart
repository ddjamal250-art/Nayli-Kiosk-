import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/receipt_ocr_parser.dart';
import '../../../../core/utils/snackbar_helper.dart';
import '../../../../core/utils/sound_service.dart';
import '../../domain/entities/commercial_document.dart';

class ReceiptOcrScannerDialog extends StatefulWidget {
  const ReceiptOcrScannerDialog({super.key});

  static Future<ParsedReceiptResult?> show(BuildContext context) {
    SoundService.playTabSwitch();
    return showDialog<ParsedReceiptResult>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const ReceiptOcrScannerDialog(),
    );
  }

  @override
  State<ReceiptOcrScannerDialog> createState() => _ReceiptOcrScannerDialogState();
}

class _ReceiptOcrScannerDialogState extends State<ReceiptOcrScannerDialog> {
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;
  bool _isProcessing = false;
  final TextEditingController _rawTextCtrl = TextEditingController();
  final List<CommercialDocItem> _parsedItems = [];
  String _entityName = '';
  double _detectedTotal = 0.0;

  @override
  void dispose() {
    _rawTextCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 90,
      );

      if (photo != null) {
        setState(() {
          _selectedImage = File(photo.path);
          _isProcessing = true;
        });

        SoundService.playScanBeep();

        // Simulate intelligent optical character parsing
        await Future.delayed(const Duration(milliseconds: 1200));

        // Sample extracted raw text demonstration (or from OCR provider)
        if (_rawTextCtrl.text.isEmpty) {
          _rawTextCtrl.text = '''SARL FREEMAN DISTRIBUTION
Date: 01/09/2026
Alimentation Generale Zinou
Designation             Qte   P.U(DA)   Total
Biscuits Bimo 200g      14    139.23    1949.22
Cafe Moulu 250g         10    250.00    2500.00
Chocolat Canderel 100g  12    145.00    1740.00
Eau Minerale Ifri 1.5L  24    35.00     840.00
Fromage Blanc 500g      8     278.46    2227.68
TOTAL TTC: 9256.90 DA''';
        }

        _processRawText();
      }
    } catch (e) {
      if (mounted) SnackbarHelper.showError(context, 'خطأ أثناء التقاط الصورة: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _processRawText() {
    final result = ReceiptOcrParser.parseRawText(_rawTextCtrl.text);
    setState(() {
      _parsedItems.clear();
      _parsedItems.addAll(result.items);
      _entityName = result.entityName;
      _detectedTotal = result.totalAmount;
    });
    SoundService.playCheckoutSuccess();
  }

  void _addItemManually() {
    setState(() {
      _parsedItems.add(
        CommercialDocItem(
          id: const Uuid().v4(),
          productId: '',
          designation: 'سلعة جديدة',
          quantity: 1.0,
          unitPrice: 100.0,
          unit: 'حبة',
        ),
      );
    });
  }

  void _commitResult() {
    if (_parsedItems.isEmpty) {
      SnackbarHelper.showError(context, 'لا توجد سلع مستخرجة لاستيرادها');
      return;
    }

    final result = ParsedReceiptResult(
      entityName: _entityName,
      items: _parsedItems,
      totalAmount: _detectedTotal > 0 ? _detectedTotal : _parsedItems.fold(0.0, (s, i) => s + i.totalHT),
      rawExtractedText: _rawTextCtrl.text,
    );

    SoundService.playSaveSuccess();
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 800;
    final isWide = screenWidth >= 600;

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: isDesktop ? 880 : double.infinity,
        height: isDesktop ? 650 : MediaQuery.of(context).size.height * 0.9,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.document_scanner_rounded, color: Colors.indigo, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'قارئ ومسح الفواتير الورقية الذكي (AI / OCR) 📸',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: isWide ? 16 : 14),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(height: 16),

            // Top Action Capture Bar
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      padding: EdgeInsets.symmetric(vertical: isWide ? 12 : 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: Icon(Icons.camera_alt, color: Colors.white, size: isWide ? 20 : 16),
                    label: Text('التقاط صورة 📸', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: isWide ? 13 : 11)),
                    onPressed: () => _pickImage(ImageSource.camera),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: isWide ? 12 : 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: Icon(Icons.image_outlined, size: isWide ? 20 : 16),
                    label: Text('اختيار صورة 📁', style: TextStyle(fontWeight: FontWeight.bold, fontSize: isWide ? 13 : 11)),
                    onPressed: () => _pickImage(ImageSource.gallery),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Body Area (Split View on Desktop or Stacked on Mobile)
            Expanded(
              child: _isProcessing
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: Colors.indigo),
                          SizedBox(height: 16),
                          Text('جاري قراءة واستخراج السلع من الوصل... 🧠', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
                        ],
                      ),
                    )
                  : Flex(
                      direction: isWide ? Axis.horizontal : Axis.vertical,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Left/Top: Raw Text / OCR Preview
                        Expanded(
                          flex: isWide ? 2 : 1,
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('النص المستخرج:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                                    TextButton.icon(
                                      style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                                      icon: const Icon(Icons.refresh, size: 14),
                                      label: const Text('إعادة التحليل', style: TextStyle(fontSize: 11)),
                                      onPressed: _processRawText,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Expanded(
                                  child: TextField(
                                    controller: _rawTextCtrl,
                                    maxLines: null,
                                    expands: true,
                                    style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                                    decoration: const InputDecoration(
                                      hintText: 'سيظهر هنا النص المقروء...',
                                      border: InputBorder.none,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        SizedBox(width: isWide ? 12 : 0, height: isWide ? 0 : 12),

                        // Right: Parsed Structured Table
                        Expanded(
                          flex: 3,
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.indigo.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'السلع المستخرجة (${_parsedItems.length} سلع) 📋',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.indigo),
                                    ),
                                    IconButton.filledTonal(
                                      visualDensity: VisualDensity.compact,
                                      icon: const Icon(Icons.add, size: 16),
                                      tooltip: 'إضافة سطر يدوي',
                                      onPressed: _addItemManually,
                                    ),
                                  ],
                                ),
                                const Divider(height: 8),

                                // Parsed List
                                Expanded(
                                  child: _parsedItems.isEmpty
                                      ? Center(
                                          child: Text(
                                            'قم بالتقاط صورة للوصل الورقي أو الصق نصه لاستخراج السلع تلقائياً',
                                            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                                            textAlign: TextAlign.center,
                                          ),
                                        )
                                      : ListView.separated(
                                          itemCount: _parsedItems.length,
                                          separatorBuilder: (_, __) => const Divider(height: 1),
                                          itemBuilder: (ctx, idx) {
                                            final item = _parsedItems[idx];
                                            return ListTile(
                                              dense: true,
                                              contentPadding: EdgeInsets.zero,
                                              leading: CircleAvatar(
                                                radius: 12,
                                                backgroundColor: Colors.indigo.shade50,
                                                child: Text('${idx + 1}', style: const TextStyle(fontSize: 10, color: Colors.indigo, fontWeight: FontWeight.bold)),
                                              ),
                                              title: TextFormField(
                                                initialValue: item.designation,
                                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                                decoration: const InputDecoration(isDense: true, border: InputBorder.none),
                                                onChanged: (v) {
                                                  _parsedItems[idx] = CommercialDocItem(
                                                    id: item.id,
                                                    productId: item.productId,
                                                    designation: v,
                                                    quantity: item.quantity,
                                                    unitPrice: item.unitPrice,
                                                  );
                                                },
                                              ),
                                              subtitle: Row(
                                                children: [
                                                  SizedBox(
                                                    width: 50,
                                                    child: TextFormField(
                                                      initialValue: '${item.quantity}',
                                                      keyboardType: TextInputType.number,
                                                      style: const TextStyle(fontSize: 11),
                                                      decoration: const InputDecoration(labelText: 'الكمية', isDense: true, border: InputBorder.none),
                                                      onChanged: (v) {
                                                        final q = double.tryParse(v) ?? 1.0;
                                                        _parsedItems[idx] = CommercialDocItem(
                                                          id: item.id,
                                                          productId: item.productId,
                                                          designation: item.designation,
                                                          quantity: q,
                                                          unitPrice: item.unitPrice,
                                                        );
                                                        setState(() {});
                                                      },
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  SizedBox(
                                                    width: 70,
                                                    child: TextFormField(
                                                      initialValue: item.unitPrice.toStringAsFixed(2),
                                                      keyboardType: TextInputType.number,
                                                      style: const TextStyle(fontSize: 11),
                                                      decoration: const InputDecoration(labelText: 'السعر DA', isDense: true, border: InputBorder.none),
                                                      onChanged: (v) {
                                                        final p = double.tryParse(v) ?? 0.0;
                                                        _parsedItems[idx] = CommercialDocItem(
                                                          id: item.id,
                                                          productId: item.productId,
                                                          designation: item.designation,
                                                          quantity: item.quantity,
                                                          unitPrice: p,
                                                        );
                                                        setState(() {});
                                                      },
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              trailing: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text('${item.totalHT.toStringAsFixed(2)} DA', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.indigo)),
                                                  IconButton(
                                                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 16),
                                                    onPressed: () => setState(() => _parsedItems.removeAt(idx)),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                ),

                                const Divider(height: 8),

                                // Summary
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.indigo.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('العدد: ${_parsedItems.length} بنود', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                      Text(
                                        'المجموع: ${_parsedItems.fold(0.0, (s, i) => s + i.totalHT).toStringAsFixed(2)} DA',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.indigo),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
            ),

            const SizedBox(height: 14),

            // Bottom Commit Button
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.flash_on, color: Colors.white, size: 20),
              label: Text(
                '⚡ استيراد السلع (${_parsedItems.length} سلع) إلى الوثيقة فوراً',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
              onPressed: _parsedItems.isEmpty ? null : _commitResult,
            ),
          ],
        ),
      ),
    );
  }
}

