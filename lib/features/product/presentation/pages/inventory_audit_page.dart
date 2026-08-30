import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/data/hive_database.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_constants.dart';
import '../../../../core/utils/excel_export_helper.dart';
import '../../../../core/utils/snackbar_helper.dart';
import '../../../../core/utils/sound_service.dart';
import '../../domain/entities/product.dart';
import '../bloc/product_bloc.dart';

class InventoryAuditPage extends StatefulWidget {
  const InventoryAuditPage({super.key});

  @override
  State<InventoryAuditPage> createState() => _InventoryAuditPageState();
}

class _InventoryAuditPageState extends State<InventoryAuditPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  final Map<String, int> _countedStock = {}; // productId -> counted quantity
  String _selectedFilter = 'all'; // 'all', 'discrepancy', 'matched', 'uncounted'

  @override
  void initState() {
    super.initState();
    _initAuditData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _initAuditData() {
    final products = context.read<ProductBloc>().state.products;
    final savedDraft = HiveDatabase.settingsBox.get('draft_audit_session');
    
    if (savedDraft is Map) {
      for (final p in products) {
        if (savedDraft.containsKey(p.id)) {
          _countedStock[p.id] = (savedDraft[p.id] as num?)?.toInt() ?? p.stock;
        } else {
          _countedStock[p.id] = p.stock;
        }
      }
    } else {
      for (final p in products) {
        _countedStock[p.id] = p.stock;
      }
    }
  }

  void _saveDraftSession() {
    HiveDatabase.settingsBox.put('draft_audit_session', _countedStock);
  }

  void _incrementCount(String productId, int amount) {
    setState(() {
      _countedStock[productId] = (_countedStock[productId] ?? 0) + amount;
      if (_countedStock[productId]! < 0) _countedStock[productId] = 0;
    });
    _saveDraftSession();
    SoundService.playScanBeep();
  }

  void _setCount(String productId, int value) {
    setState(() {
      _countedStock[productId] = value.clamp(0, 999999);
    });
    _saveDraftSession();
  }

  Future<void> _scanBarcodeForAudit() async {
    final barcode = await context.push<String>('/scanner');
    if (barcode == null || barcode.isEmpty || !mounted) return;

    final products = context.read<ProductBloc>().state.products;
    final matching = products.where((p) => p.barcode == barcode.trim()).firstOrNull;

    if (matching != null) {
      _incrementCount(matching.id, 1);
      if (mounted) {
        context.showAppSnackBar(
          '📦 تم جرد: ${matching.name} (العدد الحالي: ${_countedStock[matching.id]})',
          backgroundColor: Colors.teal[800]!,
        );
      }
    } else {
      if (mounted) {
        context.showAppSnackBar('⚠️ السلعة غير مسجلة في المخزون!', backgroundColor: Colors.orange[800]!);
      }
    }
  }

  void _showSetQuantityDialog(Product product) {
    final currentCount = _countedStock[product.id] ?? product.stock;
    final ctrl = TextEditingController(text: currentCount.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.inventory_rounded, color: AppTheme.primaryColor),
            const SizedBox(width: 8),
            Expanded(child: Text('جرد: ${product.name}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('المخزون النظري المسجل: ${product.stock} قطعة', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'العدد الفعلي المجرود على الرف',
                suffixText: 'قطعة',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            // Quick Carton pack buttons (+6, +12, +24)
            Wrap(
              spacing: 6,
              children: [
                ActionChip(label: const Text('+6 (فاردو)'), onPressed: () {
                  final cur = int.tryParse(ctrl.text) ?? 0;
                  ctrl.text = (cur + 6).toString();
                }),
                ActionChip(label: const Text('+12 (دزينة)'), onPressed: () {
                  final cur = int.tryParse(ctrl.text) ?? 0;
                  ctrl.text = (cur + 12).toString();
                }),
                ActionChip(label: const Text('+24 (كرتونة)'), onPressed: () {
                  final cur = int.tryParse(ctrl.text) ?? 0;
                  ctrl.text = (cur + 24).toString();
                }),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
            onPressed: () {
              final val = int.tryParse(ctrl.text.trim()) ?? currentCount;
              _setCount(product.id, val);
              Navigator.pop(ctx);
            },
            child: const Text('تثبيت العدد', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _confirmApplyReconciliation(List<Product> products) {
    int changedCount = 0;
    double totalLossCost = 0.0;
    double totalGainCost = 0.0;

    for (final p in products) {
      final counted = _countedStock[p.id] ?? p.stock;
      final diff = counted - p.stock;
      if (diff != 0) {
        changedCount++;
        if (diff < 0) {
          totalLossCost += (diff.abs() * p.costPrice);
        } else {
          totalGainCost += (diff * p.costPrice);
        }
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.published_with_changes_rounded, color: Colors.green),
            SizedBox(width: 8),
            Text('اعتماد وتسوية المخزون النهائي', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('سيتم تعديل وتحديث أرصدة $changedCount سلعة في قاعدة بيانات المحل فوراً.'),
            const SizedBox(height: 10),
            if (totalLossCost > 0)
              Text('🚨 قيمة العجز والنقص بالتكلفة: -${totalLossCost.toStringAsFixed(0)} ${AppConstants.currencySymbol}',
                  style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
            if (totalGainCost > 0)
              Text('🟢 قيمة الزيادة في المخزون: +${totalGainCost.toStringAsFixed(0)} ${AppConstants.currencySymbol}',
                  style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 10),
            const Text('هل أنت متأكد من تثبيت نتائج هذا الجرد وتصفير الفوارق؟', style: TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700]),
            onPressed: () {
              for (final p in products) {
                final counted = _countedStock[p.id] ?? p.stock;
                if (counted != p.stock) {
                  final updated = Product(
                    id: p.id,
                    name: p.name,
                    barcode: p.barcode,
                    price: p.price,
                    costPrice: p.costPrice,
                    stock: counted,
                  );
                  context.read<ProductBloc>().add(UpdateProduct(updated));
                }
              }
              HiveDatabase.settingsBox.delete('draft_audit_session');
              Navigator.pop(ctx);
              SoundService.playCheckoutSuccess();
              context.showAppSnackBar(
                '✅ تم اعتماد الجرد بنجاح وتسوية أرصدة $changedCount سلعة في المخزون!',
                backgroundColor: Colors.green[800]!,
              );
            },
            child: const Text('تأكيد واعتماد الجرد', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('وحدة الجرد السنوي والدوري الذكية 📋⚖️',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/products');
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.table_chart_outlined, color: Colors.green),
            tooltip: 'تصدير تقرير الجرد كـ Excel',
            onPressed: () {
              final csvData = ExcelExportHelper.exportInventoryAuditToCsv(_countedStock);
              Clipboard.setData(ClipboardData(text: csvData));
              SoundService.playCheckoutSuccess();
              context.showAppSnackBar(
                '📊 تم نسخ بيانات شيت الجرد الرسمي بتنسيق Excel بنجاح!',
                backgroundColor: Colors.green[800]!,
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_scanner, color: AppTheme.primaryColor),
            tooltip: 'مسح باركود للجرد السريع',
            onPressed: _scanBarcodeForAudit,
          ),
        ],
      ),
      body: BlocBuilder<ProductBloc, ProductState>(
        builder: (context, state) {
          final products = state.products;

          // Calculate Total Store Capital & Valuation
          double totalCostCapital = 0.0;
          double totalRetailValue = 0.0;
          int totalItemsCount = 0;
          int discrepancyItemsCount = 0;

          for (final p in products) {
            final counted = _countedStock[p.id] ?? p.stock;
            totalCostCapital += (counted * p.costPrice);
            totalRetailValue += (counted * p.price);
            totalItemsCount += counted;
            if (counted != p.stock) discrepancyItemsCount++;
          }

          final projectedProfit = totalRetailValue - totalCostCapital;

          // Filter Products
          final query = _searchCtrl.text.trim().toLowerCase();
          final filtered = products.where((p) {
            final counted = _countedStock[p.id] ?? p.stock;
            final diff = counted - p.stock;

            if (_selectedFilter == 'discrepancy' && diff >= 0) return false;
            if (_selectedFilter == 'matched' && diff != 0) return false;
            if (_selectedFilter == 'surplus' && diff <= 0) return false;

            if (query.isEmpty) return true;
            return p.name.toLowerCase().contains(query) || p.barcode.contains(query);
          }).toList();

          return Column(
            children: [
              // Top Valuation Summary Card (Store Capital & Projected Profits)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                  ),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 3)),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('رأس مال المحل بالتكلفة (Cost):', style: TextStyle(color: Colors.white70, fontSize: 11)),
                            Text(
                              '${totalCostCapital.toStringAsFixed(0)} ${AppConstants.currencySymbol}',
                              style: const TextStyle(color: Colors.amber, fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        Container(height: 32, width: 1, color: Colors.white24),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('قيمة البضاعة بالبيع (Retail):', style: TextStyle(color: Colors.white70, fontSize: 11)),
                            Text(
                              '${totalRetailValue.toStringAsFixed(0)} ${AppConstants.currencySymbol}',
                              style: const TextStyle(color: Colors.greenAccent, fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white12, height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('📈 الربح الكامن: +${projectedProfit.toStringAsFixed(0)} دج',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                        Text('📊 السلع ذات الفارق: $discrepancyItemsCount سلعة',
                            style: TextStyle(
                              color: discrepancyItemsCount > 0 ? Colors.orangeAccent : Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            )),
                      ],
                    ),
                  ],
                ),
              ),

              // Search & Scanner Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        decoration: InputDecoration(
                          hintText: 'ابحث عن سلعة لمطابقة جردها...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          suffixIcon: _searchCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () => setState(() => _searchCtrl.clear()),
                                )
                              : null,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      icon: const Icon(Icons.camera_alt_outlined, size: 18),
                      label: const Text('مسح جرد', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      onPressed: _scanBarcodeForAudit,
                    ),
                  ],
                ),
              ),

              // Micro-hint for merchant
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 13, color: Colors.teal),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '💡 امسح الباركود بالكاميرا لزيادة العدد فوراً، أو انقر على رقم أي سلعة لتعديله.',
                        style: TextStyle(fontSize: 10.5, color: Colors.teal[800], fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),

              // Filter Chips Row
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _buildFilterChip('الكل (${products.length})', 'all'),
                    const SizedBox(width: 6),
                    _buildFilterChip('🚨 بها عجز ونقص', 'discrepancy'),
                    const SizedBox(width: 6),
                    _buildFilterChip('🟢 متطابقة تماماً', 'matched'),
                    const SizedBox(width: 6),
                    _buildFilterChip('🟡 بها زيادة', 'surplus'),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Products Audit List
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          'لا توجد سلع تطابق الفلتر المحدد',
                          style: TextStyle(color: Colors.grey[500], fontSize: 13),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final p = filtered[index];
                          final counted = _countedStock[p.id] ?? p.stock;
                          final diff = counted - p.stock;

                          Color statusColor = Colors.grey;
                          String diffLabel = 'مطابق (0)';
                          if (diff < 0) {
                            statusColor = Colors.red;
                            diffLabel = 'عجز: $diff (${(diff.abs() * p.costPrice).toStringAsFixed(0)} دج)';
                          } else if (diff > 0) {
                            statusColor = Colors.green;
                            diffLabel = 'زيادة: +$diff';
                          }

                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: diff != 0 ? statusColor.withOpacity(0.5) : Colors.grey[200]!,
                                width: diff != 0 ? 1.5 : 1,
                              ),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2)),
                              ],
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Text('المسجل: ${p.stock}', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: statusColor.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              diffLabel,
                                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle_outline, size: 22, color: Colors.grey),
                                      onPressed: () => _incrementCount(p.id, -1),
                                    ),
                                    InkWell(
                                      onTap: () => _showSetQuantityDialog(p),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryColor.withOpacity(0.08),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                                        ),
                                        child: Text(
                                          '$counted',
                                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.add_circle_outline, size: 22, color: AppTheme.primaryColor),
                                      onPressed: () => _incrementCount(p.id, 1),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),

              // Bottom Apply Reconciliation Button
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, -2))],
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.check_circle_outline, size: 20),
                    label: const Text(
                      'اعتماد الجرد وتسوية المخزون النهائي ⚖️',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    onPressed: () => _confirmApplyReconciliation(products),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterChip(String label, String key) {
    final isSelected = _selectedFilter == key;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      selected: isSelected,
      selectedColor: AppTheme.primaryColor.withOpacity(0.15),
      onSelected: (_) => setState(() => _selectedFilter = key),
    );
  }
}
