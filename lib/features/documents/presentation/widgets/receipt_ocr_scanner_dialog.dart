import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/invoice_file_reader.dart';
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
  File? _selectedFile;
  String? _selectedFileName;
  String? _selectedFileFormat;
  int _selectedFileSize = 0;

  bool _isProcessing = false;
  String _processingStatus = '';
  final TextEditingController _rawTextCtrl = TextEditingController();
  final List<CommercialDocItem> _parsedItems = [];
  String _entityName = '';
  double _detectedTotal = 0.0;
  late TabController _tabController;

  static const List<String> _allAllowedExtensions = [
    'pdf',
    'xlsx',
    'xls',
    'csv',
    'tsv',
    'docx',
    'doc',
    'txt',
    'png',
    'jpg',
    'jpeg',
    'webp',
  ];

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

  Future<void> _pickFile({List<String>? specificExtensions, String? dialogTitle}) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: specificExtensions ?? _allAllowedExtensions,
        dialogTitle: dialogTitle ?? 'اختر ملف الفاتورة (PDF / Excel / Word / صورة)',
      );

      if (result != null && result.files.isNotEmpty && result.files.first.path != null) {
        final filePath = result.files.first.path!;
        final file = File(filePath);
        await _processFile(file);
      }
    } catch (e) {
      if (mounted) SnackbarHelper.showError(context, 'خطأ أثناء اختيار الملف: $e');
    }
  }

  Future<void> _processFile(File file) async {
    setState(() {
      _selectedFile = file;
      _selectedFileName = file.uri.pathSegments.isNotEmpty ? file.uri.pathSegments.last : 'invoice';
      _selectedFileSize = file.lengthSync();
      _isProcessing = true;
      _processingStatus = 'جاري تحليل وقراءة بيانات الفاتورة... 🔍';
    });

    SoundService.playScanBeep();

    try {
      final res = await InvoiceFileReader.instance.processFile(file);
      if (res != null) {
        _selectedFileFormat = res.formatName;
        _rawTextCtrl.text = res.rawText;
        setState(() {
          _parsedItems.clear();
          _parsedItems.addAll(res.parsedResult.items);
          _entityName = res.parsedResult.entityName;
          _detectedTotal = res.parsedResult.totalAmount;
        });

        if (mounted) {
          if (_parsedItems.isNotEmpty) {
            SnackbarHelper.showSuccess(context, '✅ تم استخراج ${_parsedItems.length} سلع بنجاح! يرجى المعاينة والتأكيد.');
          } else {
            SnackbarHelper.showWarning(context, 'تمت قراءة الملف لكن لم نكتشف سلعاً تلقائياً. يمكنك إضافة السلع أو تعديل النص.');
          }
        }
      } else {
        if (mounted) SnackbarHelper.showError(context, 'تعذر استخراج بيانات من هذا الملف.');
      }
    } catch (e) {
      if (mounted) SnackbarHelper.showError(context, 'خطأ أثناء معالجة الملف: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _reparseFromRawText() {
    final result = ReceiptOcrParser.parseRawText(_rawTextCtrl.text);
    setState(() {
      _parsedItems.clear();
      _parsedItems.addAll(result.items);
      if (_entityName.isEmpty) _entityName = result.entityName;
      _detectedTotal = result.totalAmount;
    });
    SoundService.playCheckoutSuccess();
    SnackbarHelper.showSuccess(context, 'تم إعادة التحليل! تم العثور على ${_parsedItems.length} سلع.');
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
    SoundService.playKeyTap();
  }

  void _removeItem(int index) {
    setState(() {
      _parsedItems.removeAt(index);
    });
    SoundService.playKeyTap();
  }

  void _commitResult() {
    if (_parsedItems.isEmpty) {
      SnackbarHelper.showError(context, 'لا توجد سلع مستخرجة من الفاتورة.');
      return;
    }

    final result = ParsedReceiptResult(
      entityName: _entityName.trim(),
      items: _parsedItems,
      totalAmount: _detectedTotal > 0 ? _detectedTotal : _parsedItems.fold(0.0, (s, i) => s + i.totalHT),
      rawExtractedText: _rawTextCtrl.text,
    );

    SoundService.playSaveSuccess();
    Navigator.pop(context, result);
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isDesktop = screenSize.width >= 750;
    final totalComputed = _parsedItems.fold(0.0, (s, i) => s + i.totalHT);

    return Dialog(
      backgroundColor: Theme.of(context).cardColor,
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: isDesktop ? 880 : double.infinity,
        height: isDesktop ? 680 : screenSize.height * 0.92,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Bar
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.teal.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.file_open_rounded, color: Colors.teal, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'استيراد وتحليل ملف الفاتورة 📂 (PDF / Excel / Word / صور)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      Text(
                        'قراءة بيانات الفواتير الرقمية والورقية مع التحقق والمعاينة قبل الترحيل للمخزون',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'إغلاق',
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // File Selection & Quick Filter Row
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.folder_open_rounded, size: 20),
                          label: const Text(
                            '📂 اختيار ملف الفاتورة من الحاسوب',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          onPressed: () => _pickFile(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        const Text('الصيغ السريعة: ', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 4),
                        _buildFormatChip('📄 PDF', ['pdf'], Colors.red.shade700),
                        const SizedBox(width: 6),
                        _buildFormatChip('📊 Excel / CSV', ['xlsx', 'xls', 'csv', 'tsv'], Colors.green.shade700),
                        const SizedBox(width: 6),
                        _buildFormatChip('🖼️ صورة / سكانير', ['png', 'jpg', 'jpeg', 'webp'], Colors.purple.shade700),
                        const SizedBox(width: 6),
                        _buildFormatChip('📝 Word / نص', ['docx', 'doc', 'txt'], Colors.blue.shade700),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Loaded File Card
            if (_selectedFile != null)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.teal.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.insert_drive_file_outlined, color: Colors.teal, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'الملف المحدد: $_selectedFileName (${_selectedFileFormat ?? ""}) • ${_formatSize(_selectedFileSize)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Color(0xFF0F766E)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    InkWell(
                      onTap: () => _pickFile(),
                      child: const Text('تغيير 🔄', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.teal)),
                    ),
                  ],
                ),
              ),

            // Tabs Header
            Container(
              height: 38,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(10),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: Colors.teal.shade800,
                  borderRadius: BorderRadius.circular(10),
                ),
                labelColor: Colors.white,
                unselectedLabelColor: Colors.black87,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                tabs: [
                  Tab(text: 'السلع المستخرجة للمعاينة (${_parsedItems.length}) 📋'),
                  const Tab(text: 'نص الفاتورة المستخرج 📝'),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Body Area
            Expanded(
              child: _isProcessing
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: Colors.teal.shade700),
                          const SizedBox(height: 16),
                          Text(
                            _processingStatus,
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade800, fontSize: 13),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'جاري استخراج السلع، الكميات وأسعار الشراء تلقائياً',
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildItemsListTab(),
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
                      Row(
                        children: [
                          Text(
                            'مجموع السلع المعاينة: ${totalComputed.toStringAsFixed(2)} دج',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F766E)),
                          ),
                          if (_detectedTotal > 0 && (_detectedTotal - totalComputed).abs() > 0.01) ...[
                            const SizedBox(width: 8),
                            Text(
                              '(المكتشف بالوصل: ${_detectedTotal.toStringAsFixed(2)} دج)',
                              style: const TextStyle(fontSize: 11, color: Colors.deepOrange, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        '${_parsedItems.length} سلع جاهزة للترحيل',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('إلغاء'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.shade800,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                  label: Text(
                    'تأكيد واستيراد السلع (${_parsedItems.length}) ✅',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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

  Widget _buildFormatChip(String label, List<String> extensions, Color color) {
    return InkWell(
      onTap: () => _pickFile(specificExtensions: extensions, dialogTitle: 'اختر ملف $label'),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
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
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inventory_2_outlined, size: 54, color: Colors.grey[400]),
              const SizedBox(height: 12),
              const Text(
                'لم يتم تحميل أو استخراج سلع بعد',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 4),
              const Text(
                'اختر ملف الفاتورة (PDF / Excel / Word / صورة) بالزر أعلاه للبدء بالمعاينة',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11.5, color: Colors.grey),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: _addItemManually,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('إضافة سلعة يدوياً ➕', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Supplier Header & Add Item Button
        Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: _entityName,
                decoration: const InputDecoration(
                  labelText: 'اسم المورد / الشركة 🏢',
                  isDense: true,
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                onChanged: (v) => _entityName = v,
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal.shade100,
                foregroundColor: Colors.teal.shade900,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('إضافة سلعة +', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              onPressed: _addItemManually,
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Table Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            children: [
              Expanded(flex: 4, child: Text('اسم السلعة / التعيين', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
              SizedBox(width: 8),
              Expanded(flex: 2, child: Text('الكمية', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
              SizedBox(width: 8),
              Expanded(flex: 2, child: Text('سعر الشراء (دج)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
              SizedBox(width: 8),
              Expanded(flex: 2, child: Text('المجموع (دج)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
              SizedBox(width: 36),
            ],
          ),
        ),
        const SizedBox(height: 4),

        // Items list
        Expanded(
          child: ListView.separated(
            itemCount: _parsedItems.length,
            separatorBuilder: (_, __) => const SizedBox(height: 4),
            itemBuilder: (context, index) {
              final item = _parsedItems[index];
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    // Item Designation
                    Expanded(
                      flex: 4,
                      child: TextFormField(
                        initialValue: item.designation,
                        decoration: const InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                          hintText: 'اسم السلعة',
                        ),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                        onChanged: (v) {
                          _parsedItems[index] = item.copyWith(designation: v);
                          setState(() {});
                        },
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Quantity
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        initialValue: item.quantity % 1 == 0 ? item.quantity.toInt().toString() : item.quantity.toString(),
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        decoration: const InputDecoration(
                          isDense: true,
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
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
                    const SizedBox(width: 8),

                    // Unit Price
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        initialValue: item.unitPrice % 1 == 0 ? item.unitPrice.toInt().toString() : item.unitPrice.toStringAsFixed(2),
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        decoration: const InputDecoration(
                          isDense: true,
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        ),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                        onChanged: (v) {
                          final p = double.tryParse(v) ?? 0.0;
                          setState(() {
                            _parsedItems[index] = item.copyWith(unitPrice: p);
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Total HT
                    Expanded(
                      flex: 2,
                      child: Text(
                        item.totalHT.toStringAsFixed(2),
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.teal.shade800),
                      ),
                    ),

                    // Delete Item
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                      tooltip: 'حذف السلعة',
                      onPressed: () => _removeItem(index),
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
              'النص الكامل المستخرج من ملف الفاتورة:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('إعادة التحليل الذكي للنص', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              onPressed: _rawTextCtrl.text.trim().isEmpty ? null : _reparseFromRawText,
            ),
          ],
        ),
        const SizedBox(height: 6),
        Expanded(
          child: TextField(
            controller: _rawTextCtrl,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            decoration: InputDecoration(
              hintText: 'سيظهر هنا النص المقروء من ملف الفاتورة، أو يمكنك لصق أي نص جدول مباشرة...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.all(12),
            ),
            style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
          ),
        ),
      ],
    );
  }
}
