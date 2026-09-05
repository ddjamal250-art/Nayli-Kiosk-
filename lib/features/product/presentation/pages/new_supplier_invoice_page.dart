import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/data/hive_database.dart';
import '../../../../core/data/master_catalog_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/catalog_crowdsource_helper.dart';
import '../../../../core/utils/category_taxonomy.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../product/domain/entities/product.dart';
import '../../../product/presentation/bloc/product_bloc.dart';

class NewSupplierInvoicePage extends StatefulWidget {
  const NewSupplierInvoicePage({super.key});

  @override
  State<NewSupplierInvoicePage> createState() => _NewSupplierInvoicePageState();
}

class _NewSupplierInvoicePageState extends State<NewSupplierInvoicePage> {
  final _supplierNameController = TextEditingController(text: 'شركة توزيع سفيان');
  final _supplierPhoneController = TextEditingController();
  final _invoiceNumberController = TextEditingController(text: 'FAC-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}');
  final _acompteController = TextEditingController();
  DateTime _invoiceDate = DateTime.now();

  // Payment Mode: 0 = Cash, 1 = Full Credit (Debt), 2 = Acompte + Debt
  int _paymentMode = 0;

  final List<Map<String, dynamic>> _invoiceItems = [];

  // Active Item Entry Form Controllers
  final _barcodeController = TextEditingController();
  final _nameController = TextEditingController();
  final _cartonCountController = TextEditingController(text: '1');
  final _unitsPerCartonController = TextEditingController(text: '24');
  final _cartonCostController = TextEditingController();
  final _unitCostController = TextEditingController();
  final _sellPriceController = TextEditingController();
  final _unitQtyController = TextEditingController(text: '24');

  bool _isCartonMode = true;
  String _activeCategory = 'مشروبات ومياه وعصائر';
  bool _isCategoryUserSelected = false;

  @override
  void initState() {
    super.initState();
    _cartonCostController.addListener(_onCartonCostChanged);
    _unitsPerCartonController.addListener(_onCartonUnitsChanged);
    _cartonCountController.addListener(_onCartonCountChanged);
    _nameController.addListener(() {
      if (!_isCategoryUserSelected && _nameController.text.trim().isNotEmpty) {
        final detected = CategoryTaxonomy.smartDetect(_nameController.text.trim());
        if (mounted && _activeCategory != detected.titleAr) {
          setState(() {
            _activeCategory = detected.titleAr;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _supplierNameController.dispose();
    _supplierPhoneController.dispose();
    _invoiceNumberController.dispose();
    _acompteController.dispose();
    _barcodeController.dispose();
    _nameController.dispose();
    _cartonCountController.dispose();
    _unitsPerCartonController.dispose();
    _cartonCostController.dispose();
    _unitCostController.dispose();
    _sellPriceController.dispose();
    _unitQtyController.dispose();
    super.dispose();
  }

  void _onCartonCostChanged() {
    if (!_isCartonMode) return;
    final perCarton = int.tryParse(_unitsPerCartonController.text.trim()) ?? 0;
    final cartonCost = double.tryParse(_cartonCostController.text.trim()) ?? 0.0;
    if (perCarton > 0 && cartonCost > 0) {
      _unitCostController.text = (cartonCost / perCarton).toStringAsFixed(2);
    }
  }

  void _onCartonUnitsChanged() {
    if (!_isCartonMode) return;
    final cartons = int.tryParse(_cartonCountController.text.trim()) ?? 0;
    final perCarton = int.tryParse(_unitsPerCartonController.text.trim()) ?? 0;
    _unitQtyController.text = (cartons * perCarton).toString();
    _onCartonCostChanged();
  }

  void _onCartonCountChanged() {
    if (!_isCartonMode) return;
    final cartons = int.tryParse(_cartonCountController.text.trim()) ?? 0;
    final perCarton = int.tryParse(_unitsPerCartonController.text.trim()) ?? 0;
    _unitQtyController.text = (cartons * perCarton).toString();
  }

  void _onBarcodeScanned(String barcode) {
    _barcodeController.text = barcode.trim();
    final productState = context.read<ProductBloc>().state;
    final existing = productState.products.where((p) => p.barcode.trim() == barcode.trim()).firstOrNull;

    if (existing != null) {
      _nameController.text = existing.name;
      _unitCostController.text = existing.costPrice.toStringAsFixed(2);
      _sellPriceController.text = existing.price.toStringAsFixed(2);
      _cartonCostController.text = (existing.costPrice * (int.tryParse(_unitsPerCartonController.text) ?? 24)).toStringAsFixed(0);
      _activeCategory = existing.category.isNotEmpty ? existing.category : 'عام';
      _isCategoryUserSelected = true;
      setState(() {});
      return;
    }

    final master = MasterCatalogService.instance.lookup(barcode.trim());
    if (master != null) {
      _nameController.text = master.name;
      _unitCostController.text = master.defaultCost.toStringAsFixed(2);
      _sellPriceController.text = master.defaultPrice.toStringAsFixed(2);
      _cartonCostController.text = (master.defaultCost * (int.tryParse(_unitsPerCartonController.text) ?? 24)).toStringAsFixed(0);
      _activeCategory = master.category.isNotEmpty ? master.category : CategoryTaxonomy.smartDetect(master.name).titleAr;
      _isCategoryUserSelected = true;
      setState(() {});
    }
  }

  void _addItemToInvoice() {
    final barcode = _barcodeController.text.trim();
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى كتابة اسم السلعة أو مسح الباركود'), backgroundColor: Colors.red),
      );
      return;
    }

    final unitCost = double.tryParse(_unitCostController.text.trim()) ?? 0.0;
    final sellPrice = double.tryParse(_sellPriceController.text.trim()) ?? (unitCost * 1.25);
    final cartons = _isCartonMode ? (int.tryParse(_cartonCountController.text.trim()) ?? 1) : 0;
    final perCarton = _isCartonMode ? (int.tryParse(_unitsPerCartonController.text.trim()) ?? 24) : 1;
    final totalUnits = _isCartonMode ? (cartons * perCarton) : (int.tryParse(_unitQtyController.text.trim()) ?? 1);
    final itemTotalCost = _isCartonMode
        ? (cartons * (double.tryParse(_cartonCostController.text.trim()) ?? (unitCost * perCarton)))
        : (totalUnits * unitCost);

    final itemCategory = _activeCategory.isNotEmpty ? _activeCategory : CategoryTaxonomy.smartDetect(name).titleAr;

    setState(() {
      _invoiceItems.add({
        'barcode': barcode.isNotEmpty ? barcode : 'GEN_${DateTime.now().millisecondsSinceEpoch}',
        'name': name,
        'category': itemCategory,
        'isCarton': _isCartonMode,
        'cartons': cartons,
        'perCarton': perCarton,
        'totalUnits': totalUnits,
        'unitCost': unitCost,
        'sellPrice': sellPrice,
        'totalCost': itemTotalCost,
      });

      // Clear input fields for next item
      _barcodeController.clear();
      _nameController.clear();
      _cartonCostController.clear();
      _unitCostController.clear();
      _sellPriceController.clear();
      _isCategoryUserSelected = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ تمت إضافة "$name" للفاتورة ($totalUnits حبة)'),
        backgroundColor: Colors.green,
        duration: const Duration(milliseconds: 1000),
      ),
    );
  }

  double get _totalInvoiceCost {
    return _invoiceItems.fold(0.0, (sum, item) => sum + (item['totalCost'] as double));
  }

  int get _totalUnitsCount {
    return _invoiceItems.fold(0, (sum, item) => sum + (item['totalUnits'] as int));
  }

  Future<void> _submitInvoice() async {
    if (_invoiceItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الفاتورة فارغة! أضف سلعة واحدة على الأقل.'), backgroundColor: Colors.orange),
      );
      return;
    }

    final supplierName = _supplierNameController.text.trim().isEmpty ? 'مورد عام' : _supplierNameController.text.trim();
    final invoiceNum = _invoiceNumberController.text.trim();
    final totalCost = _totalInvoiceCost;

    double paidAmount = 0.0;
    double remainingDebt = 0.0;

    if (_paymentMode == 0) {
      paidAmount = totalCost;
      remainingDebt = 0.0;
    } else if (_paymentMode == 1) {
      paidAmount = 0.0;
      remainingDebt = totalCost;
    } else {
      paidAmount = double.tryParse(_acompteController.text.trim()) ?? 0.0;
      remainingDebt = (totalCost - paidAmount).clamp(0.0, totalCost);
    }

    // 1. Update/Add Products in database
    final productBloc = context.read<ProductBloc>();
    final currentProducts = productBloc.state.products;

    for (final item in _invoiceItems) {
      final barcode = item['barcode'] as String;
      final name = item['name'] as String;
      final qty = item['totalUnits'] as int;
      final unitCost = item['unitCost'] as double;
      final sellPrice = item['sellPrice'] as double;

      final rawCat = item['category'] as String?;
      final category = (rawCat != null && rawCat.isNotEmpty)
          ? rawCat
          : CategoryTaxonomy.smartDetect(name).titleAr;

      final existing = currentProducts.where((p) => p.barcode.trim() == barcode.trim()).firstOrNull;
      if (existing != null) {
        final double effectiveCost;
        if (existing.stock > 0 && existing.costPrice > 0 && unitCost > 0) {
          final totalVal = (existing.stock * existing.costPrice) + (qty * unitCost);
          final totalQty = existing.stock + qty;
          effectiveCost = totalQty > 0 ? (totalVal / totalQty) : unitCost;
        } else {
          effectiveCost = unitCost > 0 ? unitCost : existing.costPrice;
        }
        final p = Product(
          id: existing.id,
          name: name,
          barcode: existing.barcode,
          category: existing.category.isNotEmpty && existing.category != 'عام' ? existing.category : category,
          price: sellPrice > 0 ? sellPrice : existing.price,
          costPrice: effectiveCost,
          stock: existing.stock + qty,
        );
        productBloc.add(UpdateProduct(p));
        CatalogCrowdsourceHelper.silentHarvest(p, category: p.category);
      } else {
        final p = Product(
          id: const Uuid().v4(),
          name: name,
          barcode: barcode,
          category: category,
          price: sellPrice,
          costPrice: unitCost,
          stock: qty,
        );
        productBloc.add(AddProduct(p));
        CatalogCrowdsourceHelper.silentHarvest(p, category: category);
      }
    }

    // 2. Save Supplier Invoice to Hive
    final invoiceId = DateTime.now().millisecondsSinceEpoch.toString();
    await HiveDatabase.supplierInvoicesBox.put(invoiceId, {
      'id': invoiceId,
      'supplierName': supplierName,
      'supplierPhone': _supplierPhoneController.text.trim(),
      'invoiceNumber': invoiceNum,
      'date': _invoiceDate.toIso8601String(),
      'totalCost': totalCost,
      'paidAmount': paidAmount,
      'remainingDebt': remainingDebt,
      'paymentMode': _paymentMode == 0 ? 'cash' : (_paymentMode == 1 ? 'credit' : 'partial'),
      'items': _invoiceItems,
      'itemCount': _invoiceItems.length,
      'totalUnits': _totalUnitsCount,
    });

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ تم حفظ فاتورة المورد وزيادة المخزون بنجاح ($_totalUnitsCount حبة)!'),
        backgroundColor: Colors.green,
        duration: const Duration(milliseconds: 1500),
      ),
    );

    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy/MM/dd');

    return Scaffold(
      appBar: AppBar(
        title: const Text('فاتورة شراء جديدة من مورد 🚚', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 28, color: AppTheme.primaryColor),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Supplier Details Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.business_rounded, color: AppTheme.primaryColor, size: 20),
                      SizedBox(width: 8),
                      Text('بيانات المورد وشركة التوزيع', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _supplierNameController,
                          decoration: const InputDecoration(
                            labelText: 'اسم المورد / الشركة',
                            hintText: 'مثال: سفيان للمشروبات',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _invoiceNumberController,
                          decoration: const InputDecoration(
                            labelText: 'رقم الفاتورة',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _supplierPhoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'هاتف الموزع (اختياري)',
                            prefixIcon: Icon(Icons.phone, size: 16),
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _invoiceDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) setState(() => _invoiceDate = picked);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[400]!),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today, size: 16, color: AppTheme.primaryColor),
                              const SizedBox(width: 6),
                              Text(dateFormat.format(_invoiceDate), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Add Product to Invoice Section
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.04),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('➕ إضافة سلعة للفاتورة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryColor)),
                      IconButton(
                        icon: const Icon(Icons.qr_code_scanner, color: AppTheme.primaryColor),
                        tooltip: 'مسح الباركود بالكاميرا',
                        onPressed: () async {
                          final scanned = await context.push<String>('/scanner');
                          if (scanned != null && scanned.isNotEmpty) {
                            _onBarcodeScanned(scanned);
                          }
                        },
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _barcodeController,
                          decoration: const InputDecoration(
                            labelText: 'الباركود (مسح أو كتابة)',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          ),
                          onSubmitted: _onBarcodeScanned,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'اسم السلعة',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Category Badge & Selector
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              CategoryTaxonomy.resolveDomain(_activeCategory).icon,
                              style: const TextStyle(fontSize: 14),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _activeCategory,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                            if (!_isCategoryUserSelected) ...[
                              const SizedBox(width: 4),
                              Text('(ذكي)', style: TextStyle(fontSize: 9, color: Colors.blue.shade700)),
                            ],
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        tooltip: 'تغيير تصنيف السلعة',
                        icon: const Icon(Icons.arrow_drop_down_circle_outlined, size: 20, color: AppTheme.primaryColor),
                        padding: EdgeInsets.zero,
                        onSelected: (cat) {
                          setState(() {
                            _activeCategory = cat;
                            _isCategoryUserSelected = true;
                          });
                        },
                        itemBuilder: (context) => CategoryTaxonomy.allDomains.map((d) => PopupMenuItem(
                          value: d.titleAr,
                          child: Row(
                            children: [
                              Text(d.icon),
                              const SizedBox(width: 8),
                              Text(d.titleAr, style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                        )).toList(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Mode Selector
                  Row(
                    children: [
                      ChoiceChip(
                        label: const Text('📦 بالكرتونة', style: TextStyle(fontSize: 12)),
                        selected: _isCartonMode,
                        onSelected: (v) => setState(() => _isCartonMode = true),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('🏷️ بالحبة', style: TextStyle(fontSize: 12)),
                        selected: !_isCartonMode,
                        onSelected: (v) => setState(() => _isCartonMode = false),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (_isCartonMode) ...[
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _cartonCountController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'عدد الكراتين',
                              suffixText: 'كرتونة',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: TextField(
                            controller: _unitsPerCartonController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'سعة الكرتونة',
                              suffixText: 'حبة',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: TextField(
                            controller: _cartonCostController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'سعر الكرتونة',
                              suffixText: 'دج',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _unitQtyController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'الكمية المستلمة',
                              suffixText: 'حبة',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: TextField(
                            controller: _unitCostController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'سعر الشراء (التكلفة)',
                              suffixText: 'دج',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),

                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _sellPriceController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'سعر البيع للزبون (دج)',
                            suffixText: 'دج',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                        icon: const Icon(Icons.add, color: Colors.white, size: 18),
                        label: const Text('إدراج بالفاتورة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        onPressed: _addItemToInvoice,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Invoice Items Table
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('قائمة سلع الفاتورة (${_invoiceItems.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Text('المجموع: ${_totalInvoiceCost.toStringAsFixed(0)} دج', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.blue)),
              ],
            ),
            const SizedBox(height: 8),

            if (_invoiceItems.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('لم تتم إضافة أي سلعة للفاتورة بعد.\nامسح الباركود أو اكتب اسم السلعة أعلاه.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _invoiceItems.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (ctx, i) {
                  final item = _invoiceItems[i];
                  return Card(
                    margin: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    child: ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                        child: Text('${i + 1}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                      ),
                      title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        item['isCarton']
                            ? '${item['cartons']} كرتونة × ${item['perCarton']} = ${item['totalUnits']} حبة (تكلفة: ${item['unitCost']} دج | بيع: ${item['sellPrice']} دج)'
                            : '${item['totalUnits']} حبة (تكلفة: ${item['unitCost']} دج | بيع: ${item['sellPrice']} دج)',
                        style: const TextStyle(fontSize: 11),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${(item['totalCost'] as double).toStringAsFixed(0)} دج', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                            onPressed: () => setState(() => _invoiceItems.removeAt(i)),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(height: 16),

            // Payment Mode Section
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('طريقة دفع الفاتورة للمورد:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('💵 كاش كامل', style: TextStyle(fontSize: 11)),
                          selected: _paymentMode == 0,
                          selectedColor: Colors.green.withOpacity(0.2),
                          onSelected: (v) => setState(() => _paymentMode = 0),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('📜 كريدي كامل', style: TextStyle(fontSize: 11)),
                          selected: _paymentMode == 1,
                          selectedColor: Colors.red.withOpacity(0.2),
                          onSelected: (v) => setState(() => _paymentMode = 1),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('⚖️ تسبيق + دين', style: TextStyle(fontSize: 11)),
                          selected: _paymentMode == 2,
                          selectedColor: Colors.orange.withOpacity(0.2),
                          onSelected: (v) => setState(() => _paymentMode = 2),
                        ),
                      ),
                    ],
                  ),
                  if (_paymentMode == 2) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: _acompteController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'المبلغ المدفوع كاش للمورد (دج)',
                        suffixText: 'دج',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Final Submit Button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _submitInvoice,
              child: Text(
                'تأكيد وحفظ الفاتورة وإضافة المخزون (${_totalUnitsCount} حبة) 📦',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
