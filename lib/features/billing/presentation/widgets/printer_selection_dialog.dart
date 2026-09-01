import 'dart:io';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/printer_helper.dart';
import '../../../../core/utils/sound_service.dart';

class PrinterSelectionDialog extends StatefulWidget {
  final PrinterRole targetRole;
  final bool isSelectionOnly;

  const PrinterSelectionDialog({
    super.key,
    this.targetRole = PrinterRole.thermalReceipt,
    this.isSelectionOnly = false,
  });

  static Future<String?> show(
    BuildContext context, {
    PrinterRole targetRole = PrinterRole.thermalReceipt,
    bool isSelectionOnly = false,
  }) {
    return showDialog<String>(
      context: context,
      builder: (ctx) => PrinterSelectionDialog(
        targetRole: targetRole,
        isSelectionOnly: isSelectionOnly,
      ),
    );
  }

  @override
  State<PrinterSelectionDialog> createState() => _PrinterSelectionDialogState();
}

class _PrinterSelectionDialogState extends State<PrinterSelectionDialog> {
  List<Printer> _printers = [];
  bool _isLoading = true;
  String? _selectedThermalPrinter;
  String? _selectedDocumentPrinter;
  bool _rememberAsDefault = true;

  @override
  void initState() {
    super.initState();
    _selectedThermalPrinter = PrinterHelper.defaultThermalPrinter;
    _selectedDocumentPrinter = PrinterHelper.defaultDocumentPrinter;
    _fetchPrinters();
  }

  Future<void> _fetchPrinters() async {
    setState(() => _isLoading = true);
    final list = await PrinterHelper.getWindowsPrinters();
    if (mounted) {
      setState(() {
        _printers = list;
        _isLoading = false;
        // Auto-fallback if empty
        if (_selectedThermalPrinter == null || _selectedThermalPrinter!.isEmpty) {
          _selectedThermalPrinter = list.where((p) => p.isDefault).firstOrNull?.name ?? (list.isNotEmpty ? list.first.name : null);
        }
        if (_selectedDocumentPrinter == null || _selectedDocumentPrinter!.isEmpty) {
          _selectedDocumentPrinter = list.where((p) => p.isDefault).firstOrNull?.name ?? (list.isNotEmpty ? list.first.name : null);
        }
      });
    }
  }

  Future<void> _saveAndConfirm(String? chosenName) async {
    if (chosenName != null && chosenName.isNotEmpty) {
      if (_rememberAsDefault) {
        if (widget.targetRole == PrinterRole.thermalReceipt) {
          await PrinterHelper.setDefaultThermalPrinter(chosenName);
        } else {
          await PrinterHelper.setDefaultDocumentPrinter(chosenName);
        }
      }
      SoundService.playSaveSuccess();
      if (mounted) Navigator.pop(context, chosenName);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isThermal = widget.targetRole == PrinterRole.thermalReceipt;
    final currentSelection = isThermal ? _selectedThermalPrinter : _selectedDocumentPrinter;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isThermal ? Colors.teal.shade50 : Colors.indigo.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isThermal ? Icons.receipt_long_rounded : Icons.print_rounded,
              color: isThermal ? Colors.teal : Colors.indigo,
              size: 24,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isThermal ? 'اختيار طابعة التوصيل الحرارية (80mm/58mm)' : 'اختيار طابعة الفواتير والوثائق (A4/A5)',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const Text(
                  'التعرف التلقائي على طابعات نظام ويندوز المثبتة',
                  style: TextStyle(color: Colors.grey, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'تحديث الطابعات',
            icon: const Icon(Icons.refresh_rounded, size: 20),
            onPressed: _fetchPrinters,
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: _isLoading
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(30),
                  child: CircularProgressIndicator(),
                ),
              )
            : _printers.isEmpty
                ? Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.print_disabled_rounded, size: 40, color: Colors.amber),
                        const SizedBox(height: 10),
                        const Text(
                          'لم يتم العثور على أي طابعة معرفة في ويندوز!',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'تأكد من توصيل كابل USB أو تشغيل الطابعة وتثبيت برنامج التعريف الخاص بها على هذا الحاسوب.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.black87, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isThermal ? Colors.teal.shade50.withOpacity(0.5) : Colors.indigo.shade50.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isThermal ? Colors.teal.shade100 : Colors.indigo.shade100),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, size: 16, color: isThermal ? Colors.teal : Colors.indigo),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                isThermal
                                    ? 'الطابعة الحرارية تطبع وصولات الكاشير السريعة وعمليات الدفع.'
                                    : 'طابعة الوثائق تطبع الفواتير الرسمية، Devis، ووصولات التسليم A4.',
                                style: TextStyle(fontSize: 11, color: isThermal ? Colors.teal.shade800 : Colors.indigo.shade800),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Printers List
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: _printers.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 6),
                          itemBuilder: (context, i) {
                            final p = _printers[i];
                            final isSelected = p.name == currentSelection;

                            return InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () {
                                setState(() {
                                  if (isThermal) {
                                    _selectedThermalPrinter = p.name;
                                  } else {
                                    _selectedDocumentPrinter = p.name;
                                  }
                                });
                                SoundService.playTabSwitch();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? (isThermal ? Colors.teal.shade50 : Colors.indigo.shade50)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? (isThermal ? Colors.teal : Colors.indigo)
                                        : Colors.grey.shade300,
                                    width: isSelected ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                                      color: isSelected ? (isThermal ? Colors.teal : Colors.indigo) : Colors.grey,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                p.name,
                                                style: TextStyle(
                                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                                  fontSize: 13,
                                                  color: const Color(0xFF0F172A),
                                                ),
                                              ),
                                              if (p.isDefault) ...[
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)),
                                                  child: const Text('افتراضية ويندوز', style: TextStyle(fontSize: 9, color: Colors.black54)),
                                                ),
                                              ],
                                            ],
                                          ),
                                          if (p.url.isNotEmpty)
                                            Text(p.url, style: const TextStyle(color: Colors.grey, fontSize: 10)),
                                        ],
                                      ),
                                    ),
                                    // Test Print Button
                                    IconButton(
                                      tooltip: 'تجربة طباعة',
                                      icon: const Icon(Icons.play_circle_outline, size: 20, color: Colors.grey),
                                      onPressed: () async {
                                        SoundService.playScanBeep();
                                        await PrinterHelper.printTestPage(
                                          p,
                                          role: widget.targetRole,
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Remember as Default Checkbox
                      Row(
                        children: [
                          Checkbox(
                            value: _rememberAsDefault,
                            activeColor: isThermal ? Colors.teal : Colors.indigo,
                            onChanged: (val) => setState(() => _rememberAsDefault = val ?? true),
                          ),
                          Text(
                            isThermal
                              ? 'حفظ هذه الطابعة كطابعة افتراضية لوصولات الكاشير دائماً'
                              : 'حفظ هذه الطابعة كطابعة افتراضية للفواتير والوثائق دائماً',
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: isThermal ? Colors.teal : Colors.indigo,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: currentSelection == null
              ? null
              : () => _saveAndConfirm(currentSelection),
          child: const Text('تأكيد واختيار الطابعة', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

