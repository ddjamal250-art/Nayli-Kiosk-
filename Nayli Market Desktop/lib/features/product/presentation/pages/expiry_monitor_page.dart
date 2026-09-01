import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_constants.dart';
import '../../../../core/utils/expiry_tracker_service.dart';
import '../../../../core/utils/snackbar_helper.dart';
import '../../../../core/utils/sound_service.dart';
import '../bloc/product_bloc.dart';
import '../../domain/entities/product.dart';

class ExpiryMonitorPage extends StatefulWidget {
  const ExpiryMonitorPage({super.key});

  @override
  State<ExpiryMonitorPage> createState() => _ExpiryMonitorPageState();
}

class _ExpiryMonitorPageState extends State<ExpiryMonitorPage> {
  ExpiryStatus? _filterStatus;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final products = context.watch<ProductBloc>().state.products;
    final allExpiryItems = ExpiryTrackerService.getExpiringProducts(productsList: products);

    final filtered = allExpiryItems.where((item) {
      if (_filterStatus != null && item.status != _filterStatus) return false;
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final name = item.product.name.toLowerCase();
        final bar = item.product.barcode.toLowerCase();
        return name.contains(query) || bar.contains(query);
      }
      return true;
    }).toList();

    final expiredCount = allExpiryItems.where((i) => i.status == ExpiryStatus.expired).length;
    final criticalCount = allExpiryItems.where((i) => i.status == ExpiryStatus.critical7Days).length;
    final warningCount = allExpiryItems.where((i) => i.status == ExpiryStatus.warning30Days).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('مراقبة صلاحية السلع والتوالف ⏳', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.send_rounded, color: Colors.indigo),
            tooltip: 'إرسال ملخص الصلاحية إلى التلغرام',
            onPressed: () async {
              SoundService.playClick();
              final ok = await ExpiryTrackerService.sendExpiryAlertToTelegram();
              if (mounted) {
                if (ok) {
                  SnackbarHelper.showSuccess(context, '✈️ تم إرسال تقرير الصلاحية إلى بوت التلغرام بنجاح!');
                } else {
                  SnackbarHelper.showWarning(context, 'يرجى ربط بوت التلغرام أولاً من الإعدادات أو لا توجد سلع قاربت الصلاحية.');
                }
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Stat Overview Cards
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: Row(
              children: [
                _buildStatBadge('منتهية الصلاحية ❌', expiredCount, Colors.red, ExpiryStatus.expired),
                const SizedBox(width: 8),
                _buildStatBadge('حرجة (<= 7 أيام) ⚠️', criticalCount, Colors.deepOrange, ExpiryStatus.critical7Days),
                const SizedBox(width: 8),
                _buildStatBadge('قريبة (<= 30 يوم) ⏳', warningCount, Colors.amber.shade800, ExpiryStatus.warning30Days),
              ],
            ),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'ابحث باسم المنتج أو الباركود...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),

          // Filter bar
          if (_filterStatus != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Text('الفلتر النشط: ${_getStatusLabel(_filterStatus!)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  TextButton(
                    onPressed: () => setState(() => _filterStatus = null),
                    child: const Text('إلغاء الفلتر', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),

          // List of items
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.verified_rounded, size: 60, color: Colors.green.shade300),
                        const SizedBox(height: 12),
                        const Text(
                          'لا توجد سلع منتهية الصلاحية مطابقة للبحث!',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'كافة منتجات المتجر صالحة وسليمة أو لم يُحدد تاريخ صلاحيتها بعد.',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) {
                      final item = filtered[i];
                      final p = item.product;
                      return Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 1,
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              // Status color bar
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: _getStatusColor(item.status).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: Icon(
                                    item.status == ExpiryStatus.expired
                                        ? Icons.dangerous_rounded
                                        : (item.status == ExpiryStatus.critical7Days ? Icons.warning_rounded : Icons.hourglass_bottom_rounded),
                                    color: _getStatusColor(item.status),
                                    size: 26,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      p.name,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Text('باركود: ${p.barcode}', style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.grey)),
                                        const SizedBox(width: 10),
                                        Text('المخزون: ${p.stock}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.indigo)),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'تاريخ النهاية: ${DateFormat('dd/MM/yyyy').format(item.expiryDate)} (${item.daysRemaining <= 0 ? "منتهية الصلاحية!" : "متبقي ${item.daysRemaining} يوم"})',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: _getStatusColor(item.status),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Quick Actions
                              Column(
                                children: [
                                  OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    onPressed: () {
                                      // Suggest discount
                                      SnackbarHelper.showInfo(context, 'يمكنك تعديل سعر السلعة لتخفيضه من شاشة المنتجات.');
                                    },
                                    child: const Text('تخفيض 🏷️', style: TextStyle(fontSize: 11)),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${p.price.toStringAsFixed(0)} ${AppConstants.currencySymbol}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.green),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBadge(String title, int count, Color color, ExpiryStatus status) {
    final isSelected = _filterStatus == status;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _filterStatus = isSelected ? null : status),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.15) : color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? color : color.withOpacity(0.3), width: isSelected ? 1.5 : 1),
          ),
          child: Column(
            children: [
              Text(count.toString(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color)),
              const SizedBox(height: 2),
              Text(title, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color), textAlign: TextAlign.center, maxLines: 1),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(ExpiryStatus status) {
    switch (status) {
      case ExpiryStatus.expired:
        return Colors.red;
      case ExpiryStatus.critical7Days:
        return Colors.deepOrange;
      case ExpiryStatus.warning30Days:
        return Colors.amber.shade800;
      case ExpiryStatus.safe:
        return Colors.green;
    }
  }

  String _getStatusLabel(ExpiryStatus status) {
    switch (status) {
      case ExpiryStatus.expired:
        return 'منتهية الصلاحية ❌';
      case ExpiryStatus.critical7Days:
        return 'حرجة (<= 7 أيام) ⚠️';
      case ExpiryStatus.warning30Days:
        return 'قريبة (<= 30 يوم) ⏳';
      case ExpiryStatus.safe:
        return 'سليمة ✅';
    }
  }
}
