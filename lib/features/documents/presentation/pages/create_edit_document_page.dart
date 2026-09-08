import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/data/hive_database.dart';
import '../../../../core/utils/snackbar_helper.dart';
import '../../../../core/utils/sound_service.dart';
import '../../../product/domain/entities/product.dart';
import '../../data/document_pdf_generator.dart';
import '../../data/document_service.dart';
import '../../domain/entities/commercial_document.dart';

class CreateEditDocumentPage extends StatefulWidget {
  final CommercialDocument? initialDocument;
  final DocumentType defaultType;

  const CreateEditDocumentPage({
    super.key,
    this.initialDocument,
    this.defaultType = DocumentType.facture,
  });

  @override
  State<CreateEditDocumentPage> createState() => _CreateEditDocumentPageState();
}

class _CreateEditDocumentPageState extends State<CreateEditDocumentPage> {
  late DocumentType _type;
  String _reference = 'جاري التوليد...';
  DateTime _createdAt = DateTime.now();
  DateTime? _dueDate;

  // Client Info
  final TextEditingController _clientNameController = TextEditingController();
  final TextEditingController _clientPhoneController = TextEditingController();
  final TextEditingController _clientAddressController = TextEditingController();
  final TextEditingController _clientRcController = TextEditingController();
  final TextEditingController _clientNifController = TextEditingController();
  final TextEditingController _clientNisController = TextEditingController();
  final TextEditingController _clientAiController = TextEditingController();

  final TextEditingController _notesController = TextEditingController();
  final List<DocumentItem> _items = [];
  double _timbreFiscal = 0.0;
  bool _isDraft = false;

  @override
  void initState() {
    super.initState();
    _type = widget.initialDocument?.type ?? widget.defaultType;
    if (widget.initialDocument != null) {
      final doc = widget.initialDocument!;
      _reference = doc.reference;
      _createdAt = doc.createdAt;
      _dueDate = doc.dueDate;
      _clientNameController.text = doc.clientName;
      _clientPhoneController.text = doc.clientPhone ?? '';
      _clientAddressController.text = doc.clientAddress ?? '';
      _clientRcController.text = doc.clientRc ?? '';
      _clientNifController.text = doc.clientNif ?? '';
      _clientNisController.text = doc.clientNis ?? '';
      _clientAiController.text = doc.clientAi ?? '';
      _notesController.text = doc.notes ?? '';
      _timbreFiscal = doc.timbreFiscal;
      _isDraft = doc.isDraft;
      _items.addAll(doc.items);
    } else {
      _generateRef();
    }
  }

  Future<void> _generateRef() async {
    final ref = await DocumentService.generateNextReference(_type);
    if (mounted) {
      setState(() => _reference = ref);
    }
  }

  @override
  void dispose() {
    _clientNameController.dispose();
    _clientPhoneController.dispose();
    _clientAddressController.dispose();
    _clientRcController.dispose();
    _clientNifController.dispose();
    _clientNisController.dispose();
    _clientAiController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double get _totalHt => _items.fold(0.0, (sum, i) => sum + i.totalHt);
  double get _totalTva => _items.fold(0.0, (sum, i) => sum + i.tvaAmount);
  double get _totalTtc => _totalHt + _totalTva + _timbreFiscal;

  void _showAddProductModal() {
    SoundService.playTabSwitch();
    final allProducts = HiveDatabase.productBox.values.toList();
    final searchCtrl = TextEditingController();
    List<Product> filtered = List.from(allProducts);

    // Multi-selection list
    final Set<String> selectedBarcodes = {};

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.playlist_add_check_rounded, color: Colors.teal, size: 28),
                const SizedBox(width: 8),
                Text('اختيار السلع من المخزون (${selectedBarcodes.length} محددة)', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            content: SizedBox(
              width: 580,
              height: 480,
              child: Column(
                children: [
                  TextField(
                    controller: searchCtrl,
                    decoration: const InputDecoration(
                      hintText: 'بحث باسم المنتج أو الباركود...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (q) {
                      final query = q.trim().toLowerCase();
                      setModalState(() {
                        filtered = allProducts.where((p) => p.name.toLowerCase().contains(query) || p.barcode.contains(query)).toList();
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.select_all, size: 18),
                        label: const Text('تحديد الكل المعروض'),
                        onPressed: () {
                          setModalState(() {
                            for (var p in filtered) {
                              selectedBarcodes.add(p.barcode);
                            }
                          });
                        },
                      ),
                      if (selectedBarcodes.isNotEmpty)
                        TextButton(
                          onPressed: () => setModalState(() => selectedBarcodes.clear()),
                          child: const Text('إلغاء التحديد', style: TextStyle(color: Colors.red)),
                        ),
                    ],
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final prod = filtered[index];
                        final isSelected = selectedBarcodes.contains(prod.barcode);

                        return CheckboxListTile(
                          dense: true,
                          value: isSelected,
                          title: Text(prod.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          subtitle: Text('باركود: ${prod.barcode} • السعر: ${prod.price.toStringAsFixed(2)} د.ج • المخزون: ${prod.stock}'),
                          onChanged: (val) {
                            setModalState(() {
                              if (val == true) {
                                selectedBarcodes.add(prod.barcode);
                              } else {
                                selectedBarcodes.remove(prod.barcode);
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                icon: const Icon(Icons.check, color: Colors.white),
                label: Text('إضافة ${selectedBarcodes.length} سلع للمستند', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                onPressed: () {
                  final addedProducts = allProducts.where((p) => selectedBarcodes.contains(p.barcode)).toList();
                  setState(() {
                    for (var p in addedProducts) {
                      _items.add(DocumentItem(
                        barcode: p.barcode,
                        designation: p.name,
                        quantity: 1.0,
                        unitPriceHt: p.price / 1.19, // Calculate standard HT from TTC price
                        discountPercent: 0.0,
                        tvaPercent: 19.0,
                      ));
                    }
                  });
                  Navigator.pop(ctx);
                  SoundService.playSaveSuccess();
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _showClientPickerModal() {
    SoundService.playTabSwitch();
    final customers = HiveDatabase.customersBox.values.toList();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('اختيار عميل مسجل'),
        content: SizedBox(
          width: 420,
          height: 320,
          child: customers.isEmpty
              ? const Center(child: Text('لا يوجد عملاء مسجلون بعد'))
              : ListView.builder(
                  itemCount: customers.length,
                  itemBuilder: (context, index) {
                    final c = customers[index];
                    return ListTile(
                      leading: const CircleAvatar(backgroundColor: Colors.teal, child: Icon(Icons.person, color: Colors.white)),
                      title: Text(c['name'] ?? 'عميل', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(c['phone'] ?? ''),
                      onTap: () {
                        setState(() {
                          _clientNameController.text = c['name'] ?? '';
                          _clientPhoneController.text = c['phone'] ?? '';
                          _clientAddressController.text = c['address'] ?? '';
                          _clientRcController.text = c['rc'] ?? '';
                          _clientNifController.text = c['nif'] ?? '';
                          _clientNisController.text = c['nis'] ?? '';
                          _clientAiController.text = c['ai'] ?? '';
                        });
                        Navigator.pop(ctx);
                        SoundService.playMemberCardScan();
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
        ],
      ),
    );
  }

  Future<void> _saveAndClose() async {
    if (_clientNameController.text.trim().isEmpty) {
      SnackbarHelper.showWarning(context, 'يرجى إدخال اسم العميل');
      return;
    }

    if (_items.isEmpty) {
      SnackbarHelper.showWarning(context, 'يرجى إضافة سلعة واحدة على الأقل');
      return;
    }

    final doc = CommercialDocument(
      id: widget.initialDocument?.id ?? 'doc_${DateTime.now().millisecondsSinceEpoch}',
      reference: _reference,
      type: _type,
      createdAt: _createdAt,
      dueDate: _dueDate,
      status: _isDraft ? 'brouillon' : 'valide',
      isDraft: _isDraft,
      clientName: _clientNameController.text.trim(),
      clientPhone: _clientPhoneController.text.trim(),
      clientAddress: _clientAddressController.text.trim(),
      clientRc: _clientRcController.text.trim(),
      clientNif: _clientNifController.text.trim(),
      clientNis: _clientNisController.text.trim(),
      clientAi: _clientAiController.text.trim(),
      items: List.from(_items),
      timbreFiscal: _timbreFiscal,
      notes: _notesController.text.trim(),
    );

    await DocumentService.saveDocument(doc);
    SoundService.playSaveSuccess();
    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(widget.initialDocument == null ? 'إنشاء مستند جديد' : 'تعديل مستند: $_reference',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: Colors.teal),
            icon: const Icon(Icons.print_rounded),
            label: const Text('معاينة وطباعة A4'),
            onPressed: () {
              if (_clientNameController.text.isEmpty || _items.isEmpty) {
                SnackbarHelper.showWarning(context, 'يرجى إدخال اسم العميل وإضافة السلع أولاً');
                return;
              }
              final tempDoc = CommercialDocument(
                id: 'temp',
                reference: _reference,
                type: _type,
                createdAt: _createdAt,
                clientName: _clientNameController.text.trim(),
                clientPhone: _clientPhoneController.text.trim(),
                clientAddress: _clientAddressController.text.trim(),
                clientRc: _clientRcController.text.trim(),
                clientNif: _clientNifController.text.trim(),
                clientNis: _clientNisController.text.trim(),
                clientAi: _clientAiController.text.trim(),
                items: List.from(_items),
                timbreFiscal: _timbreFiscal,
                notes: _notesController.text.trim(),
              );
              DocumentPdfGenerator.printDocument(tempDoc);
            },
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, padding: const EdgeInsets.symmetric(horizontal: 18)),
            icon: const Icon(Icons.save, color: Colors.white),
            label: const Text('حفظ المستند', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            onPressed: _saveAndClose,
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Top Document Type & Reference Box
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Document Type Selector
                    Expanded(
                      child: DropdownButtonFormField<DocumentType>(
                        value: _type,
                        decoration: const InputDecoration(
                          labelText: 'نوع المستند',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: DocumentType.values.map((t) {
                          return DropdownMenuItem(value: t, child: Text(t.titleAr));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _type = val);
                            _generateRef();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Reference
                    Expanded(
                      child: TextField(
                        controller: TextEditingController(text: _reference),
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'الرقم التسلسلي (Réf)',
                          border: OutlineInputBorder(),
                          isDense: true,
                          prefixIcon: Icon(Icons.tag),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Date
                    Expanded(
                      child: ListTile(
                        dense: true,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: Colors.grey)),
                        title: const Text('تاريخ المستند', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        subtitle: Text(DateFormat('yyyy/MM/dd').format(_createdAt), style: const TextStyle(fontWeight: FontWeight.bold)),
                        trailing: const Icon(Icons.calendar_today, size: 18, color: Colors.teal),
                        onTap: () async {
                          final d = await showDatePicker(
                            context: context,
                            initialDate: _createdAt,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (d != null) setState(() => _createdAt = d);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Client Info Box
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.person_pin_rounded, color: Colors.teal),
                            SizedBox(width: 8),
                            Text('معلومات العميل والمشتري (Client)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          ],
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.contacts, size: 18),
                          label: const Text('اختيار عميل مسجل'),
                          onPressed: _showClientPickerModal,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _clientNameController,
                            decoration: const InputDecoration(
                              labelText: 'اسم العميل / المؤسسة *',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _clientPhoneController,
                            decoration: const InputDecoration(
                              labelText: 'الهاتف',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _clientAddressController,
                            decoration: const InputDecoration(
                              labelText: 'العنوان',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Algerian Tax fields
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _clientRcController,
                            decoration: const InputDecoration(labelText: 'R.C (السجل التجاري)', border: OutlineInputBorder(), isDense: true),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _clientNifController,
                            decoration: const InputDecoration(labelText: 'N.I.F (التعريف الجبائي)', border: OutlineInputBorder(), isDense: true),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _clientNisController,
                            decoration: const InputDecoration(labelText: 'N.I.S (التعريف الإحصائي)', border: OutlineInputBorder(), isDense: true),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _clientAiController,
                            decoration: const InputDecoration(labelText: 'Art. Imp (المادة الضريبية)', border: OutlineInputBorder(), isDense: true),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Products Table Box
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.shopping_bag_outlined, color: Colors.teal),
                            const SizedBox(width: 8),
                            Text('السلع والمواد (${_items.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          ],
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                          icon: const Icon(Icons.add_shopping_cart, color: Colors.white, size: 18),
                          label: const Text('+ إضافة سلع من المخزون', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          onPressed: _showAddProductModal,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_items.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(32),
                        alignment: Alignment.center,
                        child: const Text('لم تتم إضافة أي سلعة بعد. اضغط على الزر أعلاه لإضافة سلع.', style: TextStyle(color: Colors.grey)),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 4,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(item.designation, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                      Text(item.barcode, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                    ],
                                  ),
                                ),
                                // Quantity
                                SizedBox(
                                  width: 90,
                                  child: TextFormField(
                                    initialValue: item.quantity.toString(),
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(labelText: 'الكمية', border: OutlineInputBorder(), isDense: true),
                                    onChanged: (val) {
                                      final q = double.tryParse(val) ?? 1.0;
                                      setState(() {
                                        _items[index] = DocumentItem(
                                          barcode: item.barcode,
                                          designation: item.designation,
                                          quantity: q,
                                          unitPriceHt: item.unitPriceHt,
                                          discountPercent: item.discountPercent,
                                          tvaPercent: item.tvaPercent,
                                        );
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Price HT
                                SizedBox(
                                  width: 120,
                                  child: TextFormField(
                                    initialValue: item.unitPriceHt.toStringAsFixed(2),
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(labelText: 'سعر HT (د.ج)', border: OutlineInputBorder(), isDense: true),
                                    onChanged: (val) {
                                      final p = double.tryParse(val) ?? 0.0;
                                      setState(() {
                                        _items[index] = DocumentItem(
                                          barcode: item.barcode,
                                          designation: item.designation,
                                          quantity: item.quantity,
                                          unitPriceHt: p,
                                          discountPercent: item.discountPercent,
                                          tvaPercent: item.tvaPercent,
                                        );
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Total TTC
                                SizedBox(
                                  width: 130,
                                  child: Text('${item.totalTtc.toStringAsFixed(2)} د.ج TTC',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.teal)),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                                  onPressed: () {
                                    setState(() => _items.removeAt(index));
                                    SoundService.playDeleteSound();
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Financial Summary & Notes
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _notesController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'ملاحظات وشروط الفاتورة...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),
                    SizedBox(
                      width: 280,
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('المجموع الصافي HT:', style: TextStyle(color: Colors.grey)),
                              Text('${_totalHt.toStringAsFixed(2)} د.ج', style: const TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('مجموع الرسوم TVA:', style: TextStyle(color: Colors.grey)),
                              Text('${_totalTva.toStringAsFixed(2)} د.ج', style: const TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const Divider(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('المجموع الإجمالي TTC:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              Text('${_totalTtc.toStringAsFixed(2)} د.ج',
                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: Colors.teal)),
                            ],
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
    );
  }
}

