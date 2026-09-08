import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/data/hive_database.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/commercial_pdf_generator.dart';
import '../../../../core/utils/snackbar_helper.dart';
import '../../../../core/utils/sound_service.dart';
import '../../../customer/domain/entities/customer.dart';
import '../../../product/domain/entities/product.dart';
import '../../../product/presentation/bloc/product_bloc.dart';
import '../../data/commercial_document_service.dart';
import '../../domain/entities/commercial_document.dart';
import 'receipt_ocr_scanner_dialog.dart';

class DocumentEditorDialog extends StatefulWidget {
  final CommercialDocument? initialDocument;
  final CommercialDocType? defaultType;

  const DocumentEditorDialog({
    super.key,
    this.initialDocument,
    this.defaultType,
  });

  static Future<bool?> show(
    BuildContext context, {
    CommercialDocument? initialDocument,
    CommercialDocType? defaultType,
  }) {
    SoundService.playTabSwitch();
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => DocumentEditorDialog(
        initialDocument: initialDocument,
        defaultType: defaultType,
      ),
    );
  }

  @override
  State<DocumentEditorDialog> createState() => _DocumentEditorDialogState();
}

class _DocumentEditorDialogState extends State<DocumentEditorDialog> {
  late CommercialDocType _selectedType;
  late CommercialDocStatus _selectedStatus;
  late String _documentNumber;
  late DateTime _docDate;
  DateTime? _dueDate;

  // Entity Info Controllers
  final TextEditingController _entityNameCtrl = TextEditingController();
  final TextEditingController _entityPhoneCtrl = TextEditingController();
  final TextEditingController _entityAddressCtrl = TextEditingController();
  final TextEditingController _entityRcCtrl = TextEditingController();
  final TextEditingController _entityNifCtrl = TextEditingController();

  // Financial Controllers
  final TextEditingController _globalDiscountCtrl = TextEditingController(text: '0');
  final TextEditingController _amountPaidCtrl = TextEditingController(text: '0');
  final TextEditingController _previousBalanceCtrl = TextEditingController(text: '0');
  final TextEditingController _notesCtrl = TextEditingController();
  String _paymentMethod = 'كاش';

  // Items List
  final List<CommercialDocItem> _items = [];

  // New Item Input Controllers
  final TextEditingController _searchProductCtrl = TextEditingController();
  final TextEditingController _itemQtyCtrl = TextEditingController(text: '1');
  final TextEditingController _itemPriceCtrl = TextEditingController();
  String _itemUnit = 'حبة';

  @override
  void initState() {
    super.initState();
    if (widget.initialDocument != null) {
      final doc = widget.initialDocument!;
      _selectedType = doc.type;
      _selectedStatus = doc.status;
      _documentNumber = doc.documentNumber;
      _docDate = doc.date;
      _dueDate = doc.dueDate;
      _entityNameCtrl.text = doc.entityName;
      _entityPhoneCtrl.text = doc.entityPhone;
      _entityAddressCtrl.text = doc.entityAddress;
      _entityRcCtrl.text = doc.entityRc;
      _entityNifCtrl.text = doc.entityNif;
      _globalDiscountCtrl.text = doc.globalDiscount.toStringAsFixed(2);
      _amountPaidCtrl.text = doc.amountPaid.toStringAsFixed(2);
      _previousBalanceCtrl.text = doc.previousBalance.toStringAsFixed(2);
      _notesCtrl.text = doc.notes ?? '';
      _paymentMethod = doc.paymentMethod;
      _items.addAll(doc.items);
    } else {
      _selectedType = widget.defaultType ?? CommercialDocType.facture;
      _selectedStatus = CommercialDocStatus.valide;
      _documentNumber = CommercialDocumentService.generateNextDocNumber(_selectedType);
      _docDate = DateTime.now();
    }
  }

  @override
  void dispose() {
    _entityNameCtrl.dispose();
    _entityPhoneCtrl.dispose();
    _entityAddressCtrl.dispose();
    _entityRcCtrl.dispose();
    _entityNifCtrl.dispose();
    _globalDiscountCtrl.dispose();
    _amountPaidCtrl.dispose();
    _previousBalanceCtrl.dispose();
    _notesCtrl.dispose();
    _searchProductCtrl.dispose();
    _itemQtyCtrl.dispose();
    _itemPriceCtrl.dispose();
    super.dispose();
  }

  double get _subtotalHT => _items.fold(0.0, (sum, item) => sum + item.totalHT);
  double get _totalTVA => _items.fold(0.0, (sum, item) => sum + item.totalTVA);
  double get _globalDiscount => double.tryParse(_globalDiscountCtrl.text) ?? 0.0;
  double get _netTotal => (_subtotalHT - _globalDiscount) + _totalTVA;
  double get _previousBalance => double.tryParse(_previousBalanceCtrl.text) ?? 0.0;
  double get _amountPaid => double.tryParse(_amountPaidCtrl.text) ?? 0.0;
  double get _remainingBalance => (_netTotal + _previousBalance) - _amountPaid;

  void _onCustomerSelected(Customer customer) {
    setState(() {
      _entityNameCtrl.text = customer.name;
      _entityPhoneCtrl.text = customer.phoneNumber;
      _entityAddressCtrl.text = customer.address;
      _previousBalanceCtrl.text = customer.currentDebt.toStringAsFixed(2);
    });
  }

  void _onProductSelected(Product product) {
    setState(() {
      _searchProductCtrl.text = product.name;
      _itemPriceCtrl.text = product.price.toStringAsFixed(2);
      _itemUnit = product.isWeighted ? 'كغ' : 'حبة';
    });
  }

  void _addItem() {
    final designation = _searchProductCtrl.text.trim();
    final qty = double.tryParse(_itemQtyCtrl.text.trim()) ?? 1.0;
    final price = double.tryParse(_itemPriceCtrl.text.trim()) ?? 0.0;

    if (designation.isEmpty) {
      SnackbarHelper.showError(context, 'يرجى اختيار أو كتابة تعيين السلعة');
      return;
    }

    setState(() {
      _items.add(
        CommercialDocItem(
          id: const Uuid().v4(),
          productId: '',
          designation: designation,
          quantity: qty,
          unit: _itemUnit,
          unitPrice: price,
        ),
      );
      _searchProductCtrl.clear();
      _itemQtyCtrl.text = '1';
      _itemPriceCtrl.clear();
    });
    SoundService.playScanBeep();
  }

  CommercialDocument _buildCurrentDoc() {
    return CommercialDocument(
      id: widget.initialDocument?.id ?? const Uuid().v4(),
      documentNumber: _documentNumber,
      type: _selectedType,
      status: _selectedStatus,
      date: _docDate,
      dueDate: _dueDate,
      entityName: _entityNameCtrl.text.trim().isEmpty ? 'زبون عابر' : _entityNameCtrl.text.trim(),
      entityPhone: _entityPhoneCtrl.text.trim(),
      entityAddress: _entityAddressCtrl.text.trim(),
      entityRc: _entityRcCtrl.text.trim(),
      entityNif: _entityNifCtrl.text.trim(),
      items: List.from(_items),
      globalDiscount: _globalDiscount,
      amountPaid: _amountPaid,
      previousBalance: _previousBalance,
      paymentMethod: _paymentMethod,
      notes: _notesCtrl.text.trim(),
      isArchived: widget.initialDocument?.isArchived ?? false,
      convertedFromId: widget.initialDocument?.convertedFromId,
      convertedToId: widget.initialDocument?.convertedToId,
    );
  }

  void _scanPaperReceipt() async {
    final result = await ReceiptOcrScannerDialog.show(context);
    if (result != null && result.items.isNotEmpty) {
      setState(() {
        _items.addAll(result.items);
        if (_entityNameCtrl.text.isEmpty && result.entityName.isNotEmpty) {
          _entityNameCtrl.text = result.entityName;
        }
      });
      if (mounted) {
        SnackbarHelper.showSuccess(context, '🎉 تم استيراد ${result.items.length} سلع من الوصل الورقي بنجاح!');
      }
    }
  }

  Future<void> _save() async {
    if (_items.isEmpty) {
      SnackbarHelper.showError(context, 'يرجى إضافة بند واحد على الأقل للوثيقة');
      return;
    }
    final doc = _buildCurrentDoc();
    await CommercialDocumentService.saveDocument(doc);
    SoundService.playSaveSuccess();
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 800;

    return Dialog(
      backgroundColor: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: isDesktop ? 950 : double.infinity,
        height: isDesktop ? 680 : MediaQuery.of(context).size.height * 0.9,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Bar
            Row(
              children: [
                const Icon(Icons.receipt_long_rounded, color: Colors.indigo, size: 28),
                const SizedBox(width: 10),
                Text(
                  widget.initialDocument != null ? 'تعديل وثيقة: $_documentNumber' : 'إنشاء وثيقة تجارية جديدة 📑',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                ),
                const Spacer(),
                // AI / OCR Scan Button
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.document_scanner_rounded, size: 18),
                  label: const Text('مسح وصل ورقي (OCR) 📸', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  onPressed: _scanPaperReceipt,
                ),
                const SizedBox(width: 10),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context, false),
                ),
              ],
            ),
            const Divider(height: 16),

            // Document Controls & Type Selector
            Row(
              children: [
                // Type Dropdown
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<CommercialDocType>(
                    value: _selectedType,
                    decoration: const InputDecoration(
                      labelText: 'نوع الوثيقة',
                      prefixIcon: Icon(Icons.category, color: Colors.indigo),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: CommercialDocType.values.map((t) {
                      return DropdownMenuItem(
                        value: t,
                        child: Text(t.name.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedType = val;
                          if (widget.initialDocument == null) {
                            _documentNumber = CommercialDocumentService.generateNextDocNumber(val);
                          }
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),

                // Doc Number
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    initialValue: _documentNumber,
                    decoration: const InputDecoration(
                      labelText: 'رقم الوثيقة',
                      prefixIcon: Icon(Icons.tag),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (v) => _documentNumber = v.trim(),
                  ),
                ),
                const SizedBox(width: 10),

                // Date Picker Button
                Expanded(
                  flex: 2,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.calendar_month, size: 18),
                    label: Text(DateFormat('yyyy/MM/dd').format(_docDate), style: const TextStyle(fontSize: 12)),
                    onPressed: () async {
                      final p = await showDatePicker(context: context, initialDate: _docDate, firstDate: DateTime(2020), lastDate: DateTime(2035));
                      if (p != null) setState(() => _docDate = p);
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Entity (Client / Fournisseur) Details
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _entityNameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'اسم الزبون / المورد *',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _entityPhoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'الهاتف',
                        prefixIcon: Icon(Icons.phone),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _entityAddressCtrl,
                      decoration: const InputDecoration(
                        labelText: 'العنوان',
                        prefixIcon: Icon(Icons.location_on),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // Quick Add Item Bar
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.indigo.shade50.withOpacity(0.5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.indigo.shade100),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: TextField(
                      controller: _searchProductCtrl,
                      decoration: const InputDecoration(
                        hintText: 'اكتب اسم السلعة أو امسح الباركود...',
                        prefixIcon: Icon(Icons.add_shopping_cart, size: 20),
                        border: OutlineInputBorder(),
                        isDense: true,
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 75,
                    child: TextField(
                      controller: _itemQtyCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'الكمية',
                        border: OutlineInputBorder(),
                        isDense: true,
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 100,
                    child: TextField(
                      controller: _itemPriceCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'السعر (DA)',
                        border: OutlineInputBorder(),
                        isDense: true,
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    icon: const Icon(Icons.add, color: Colors.white, size: 18),
                    label: const Text('إضافة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    onPressed: _addItem,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Items Table
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _items.isEmpty
                    ? const Center(
                        child: Text(
                          'لا توجد بنود بعد. أضف سلعاً من الشريط العلوي 🛒',
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (ctx, idx) {
                          final item = _items[idx];
                          return ListTile(
                            dense: true,
                            leading: CircleAvatar(
                              radius: 12,
                              backgroundColor: Colors.indigo.shade100,
                              child: Text('${idx + 1}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.indigo)),
                            ),
                            title: Text(item.designation, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            subtitle: Text('${item.quantity} ${item.unit} × ${item.unitPrice.toStringAsFixed(2)} DA'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('${item.totalHT.toStringAsFixed(2)} DA', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                                  onPressed: () {
                                    setState(() => _items.removeAt(idx));
                                    SoundService.playDeleteSound();
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ),

            const SizedBox(height: 10),

            // Financial Summary Row
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _globalDiscountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'تخفيض (DA)', border: OutlineInputBorder(), isDense: true),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _previousBalanceCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'رصيد سابق (DA)', border: OutlineInputBorder(), isDense: true),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _amountPaidCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'الدفعة المسددة (DA)', border: OutlineInputBorder(), isDense: true),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade900,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('المجموع: ${_netTotal.toStringAsFixed(2)} DA', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                      Text('الباقي: ${_remainingBalance.toStringAsFixed(2)} DA', style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Action Buttons
            Row(
              children: [
                // Save Button
                Expanded(
                  flex: 3,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.save, color: Colors.white),
                    label: const Text('حفظ الوثيقة 💾', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    onPressed: _save,
                  ),
                ),
                const SizedBox(width: 8),

                // Desktop 1-Click Export
                if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) ...[
                  IconButton.filledTonal(
                    tooltip: 'تصدير إلى سطح المكتب مباشرة',
                    icon: const Icon(Icons.desktop_windows_rounded, color: Colors.indigo),
                    onPressed: () async {
                      if (_items.isEmpty) return;
                      final doc = _buildCurrentDoc();
                      final path = await CommercialPdfGenerator.exportToDesktop(doc);
                      SoundService.playSaveSuccess();
                      if (context.mounted) {
                        context.showAppSnackBar('🖥️ تم حفظ ملف PDF على سطح المكتب بنجاح!\n$path');
                      }
                    },
                  ),
                ],

                // Print Button
                IconButton.filledTonal(
                  tooltip: 'طباعة فورية',
                  icon: const Icon(Icons.print, color: Colors.teal),
                  onPressed: () async {
                    if (_items.isEmpty) return;
                    final doc = _buildCurrentDoc();
                    await CommercialPdfGenerator.printDocument(doc);
                  },
                ),

                // Mobile Share Button
                IconButton.filledTonal(
                  tooltip: 'مشاركة PDF عبر WhatsApp / Telegram',
                  icon: const Icon(Icons.share, color: Colors.green),
                  onPressed: () async {
                    if (_items.isEmpty) return;
                    final doc = _buildCurrentDoc();
                    await CommercialPdfGenerator.sharePdf(doc);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

