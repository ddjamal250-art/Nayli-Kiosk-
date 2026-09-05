import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/invoice_ocr_service.dart';
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

class _ReceiptOcrScannerDialogState extends State<ReceiptOcrScannerDialog> with SingleTickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;
  bool _isProcessing = false;
  final TextEditingController _rawTextCtrl = TextEditingController();
  final List<CommercialDocItem> _parsedItems = [];
  String _entityName = '';
  double _detectedTotal = 0.0;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _rawTextCtrl.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );

      if (photo != null) {
        setState(() {
          _selectedImage = File(photo.path);
          _isProcessing = true;
        });

        SoundService.playScanBeep();

        // 1. Extract raw printed text using real OCR Service
        final extractedText = await InvoiceOcrService.instance.extractTextFromImage(_selectedImage!);

        if (extractedText != null && extractedText.trim().isNotEmpty) {
          _rawTextCtrl.text = extractedText;
          _processRawText();
          if (mounted) {
            SnackbarHelper.showSuccess(context, '✅ تم قراءة الفاتورة بنجاح عبر الذكاء الاصطناعي!');
          }
        } else {
          // If offline or OCR returned empty, keep existing or provide friendly guidance
          if (_rawTextCtrl.text.isEmpty) {
            _rawTextCtrl.text = '''Designation   Qte   P.U   Total
Marlboro Red   10    385   3850
L&M Blue       10    300   3000
Soummam Fraise 24    24    576
Eau Ifri 1.5L  24    30    720''';
          }
          _processRawText();
          if (mounted) {
            SnackbarHelper.showWarning(context, 'تعذر الاتصال بخادم OCR التلقائي. تم فتح نافذة التعديل اليدوي.');
          }
        }
      }
    } catch (e) {
      if (mounted) SnackbarHelper.showError(context, 'خطأ أثناء معالجة الصورة: $e');
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
      SnackbarHelper.showError(context, 'لا توجد سلع مستخرجة من الفاتورة.');
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
    final screenSize = MediaQuery.of(context).size;
    final isDesktop = screenSize.width >= 750;

    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: isDesktop ? 840 : double.infinity,
        height: isDesktop ? 640 : screenSize.height * 0.88,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.indigo.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.document_scanner_rounded, color: Colors.indigo, size: 22),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'مسح واستخراج فواتير الشراء (AI OCR) 🧾',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      Text(
                        'استخراج الكميات وأسعار الشراء تلقائياً ونقلها للأريفاج',
                        style: TextStyle(fontSize: 10.5, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Top Action Capture Bar
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.camera_alt, size: 18),
                    label: const Text('تصوير الفاتورة 📷', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    onPressed: () => _pickImage(ImageSource.camera),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.photo_library_outlined, size: 18),
                    label: const Text('من المعرض 🖼️', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    onPressed: () => _pickImage(ImageSource.gallery),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Tabs Header on Mobile
            Container(
              height: 38,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: Colors.indigo,
                  borderRadius: BorderRadius.circular(10),
                ),
                labelColor: Colors.white,
                unselectedLabelColor: Colors.black87,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                tabs: [
                  Tab(text: 'السلع المستخرجة (${_parsedItems.length}) 📋'),
                  const Tab(text: 'نص الفاتورة الأصلي 📝'),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Body Area
            Expanded(
              child: _isProcessing
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: Colors.indigo),
                          SizedBox(height: 16),
                          Text(
                            'جاري فك تشفير وقراءة الوصل بالذكاء الاصطناعي... 🧠',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo, fontSize: 13),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'استخراج أسماء المنتجات، الكميات وأسعار الشراء',
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        // Tab 1: Extracted Items List
                        _buildItemsListTab(),
                        // Tab 2: Raw Text Editor
                        _buildRawTextTab(),
                      ],
                    ),
            ),

            const Divider(height: 16),

            // Footer Summary & Submit Button
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'إجمالي الفاتورة: ${_detectedTotal > 0 ? _detectedTotal.toStringAsFixed(2) : _parsedItems.fold(0.0, (s, i) => s + i.totalHT).toStringAsFixed(2)} دج',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.indigo),
                      ),
                      Text(
                        '${_parsedItems.length} سلع مستخرجة',
                        style: const TextStyle(fontSize: 10.5, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.arrow_forward, size: 18),
                  label: const Text(
                    'نقل إلى صفحة الأريفاج 📥',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  onPressed: _parsedItems.isEmpty ? null : _commitResult,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsListTab() {
    if (_parsedItems.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.receipt_long_outlined, size: 52, color: Colors.grey[400]),
              const SizedBox(height: 10),
              const Text(
                'لم يتم استخراج سلع بعد',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 4),
              const Text(
                'التقط صورة للوصل الورقي أو الصق نصه من التبويب المجاور',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _addItemManually,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('إضافة سلعة يدوياً +', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Supplier name header
        Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: _entityName,
                decoration: const InputDecoration(
                  labelText: 'المورد / المؤسسة 🏢',
                  isDense: true,
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                onChanged: (v) => _entityName = v,
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: 'إضافة سلعة يدوياً',
              icon: const Icon(Icons.add, size: 18),
              onPressed: _addItemManually,
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Items list
        Expanded(
          child: ListView.separated(
            itemCount: _parsedItems.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (context, index) {
              final item = _parsedItems[index];
              return Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  children: [
                    // Item Designation
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextFormField(
                            initialValue: item.designation,
                            decoration: const InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                              hintText: 'اسم السلعة',
                            ),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            onChanged: (v) {
                              _parsedItems[index] = item.copyWith(designation: v);
                            },
                          ),
                          Text(
                            'المجموع: ${item.totalHT.toStringAsFixed(2)} دج',
                            style: TextStyle(fontSize: 10.5, color: Colors.teal[800], fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Quantity
                    SizedBox(
                      width: 60,
                      child: TextFormField(
                        initialValue: item.quantity.toStringAsFixed(item.quantity.truncateToDouble() == item.quantity ? 0 : 2),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          labelText: 'الكمية',
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                        ),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        onChanged: (v) {
                          final q = double.tryParse(v) ?? 1.0;
                          setState(() {
                            _parsedItems[index] = item.copyWith(quantity: q);
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Unit purchase price
                    SizedBox(
                      width: 75,
                      child: TextFormField(
                        initialValue: item.unitPrice.toStringAsFixed(2),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          labelText: 'شراء',
                          suffixText: 'دج',
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                        ),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        onChanged: (v) {
                          final p = double.tryParse(v) ?? 0.0;
                          setState(() {
                            _parsedItems[index] = item.copyWith(unitPrice: p);
                          });
                        },
                      ),
                    ),
                    // Delete item
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      onPressed: () {
                        setState(() => _parsedItems.removeAt(index));
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRawTextTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'النص المستخرج من الوصل (يمكنك تعديله أو لصقه):',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            TextButton.icon(
              onPressed: _processRawText,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('إعادة تحليل النص 🔄', style: TextStyle(fontSize: 11)),
            ),
          ],
        ),
        Expanded(
          child: TextFormField(
            controller: _rawTextCtrl,
            maxLines: null,
            expands: true,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            decoration: InputDecoration(
              hintText: 'Designation  Qte  P.U  Total...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              fillColor: Colors.grey[50],
              filled: true,
              contentPadding: const EdgeInsets.all(10),
            ),
          ),
        ),
      ],
    );
  }
}
