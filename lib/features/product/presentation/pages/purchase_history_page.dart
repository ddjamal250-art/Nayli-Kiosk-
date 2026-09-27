import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/product_bloc.dart';
import '../../domain/entities/product.dart';

/// Full Purchase History page — shows all PurchaseBatch entries across
/// all products, sorted chronologically.
class PurchaseHistoryPage extends StatefulWidget {
  const PurchaseHistoryPage({super.key});

  @override
  State<PurchaseHistoryPage> createState() => _PurchaseHistoryPageState();
}

class _PurchaseHistoryPageState extends State<PurchaseHistoryPage> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('أرشيف المشتريات'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'بحث بالاسم أو المورد...',
                prefixIcon: const Icon(Icons.search, color: Colors.white70),
                filled: true,
                fillColor: Colors.white24,
                hintStyle: const TextStyle(color: Colors.white60),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
              style: const TextStyle(color: Colors.white),
              onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
            ),
          ),
        ),
      ),
      body: BlocBuilder<ProductBloc, ProductState>(
        builder: (context, state) {
          // Flatten all batches across all products
          final List<_BatchEntry> entries = [];
          for (final product in state.products) {
            for (final batch in product.stockBatches) {
              entries.add(_BatchEntry(product: product, batch: batch));
            }
          }

          // Sort newest first
          entries.sort((a, b) {
            return b.batch.dateAdded.compareTo(a.batch.dateAdded);
          });

          // Apply search filter
          final filtered = _searchQuery.isEmpty
              ? entries
              : entries.where((e) {
                  return e.product.name.toLowerCase().contains(_searchQuery) ||
                      (e.batch.supplierName?.toLowerCase().contains(_searchQuery) ?? false);
                }).toList();

          if (filtered.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'لا يوجد أرشيف مشتريات بعد.\nابدأ باستلام سلعة من صفحة الاستلام.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final entry = filtered[index];
              final batch = entry.batch;
              final product = entry.product;

              final dateStr = '${batch.dateAdded.year}-${batch.dateAdded.month.toString().padLeft(2, '0')}-${batch.dateAdded.day.toString().padLeft(2, '0')}';

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: Colors.teal.shade50,
                    child: Icon(Icons.local_shipping, color: Colors.teal.shade700),
                  ),
                  title: Text(
                    product.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (batch.supplierName != null && batch.supplierName!.isNotEmpty)
                        Row(
                          children: [
                            const Icon(Icons.person_outline, size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(batch.supplierName!, style: const TextStyle(fontSize: 13)),
                            if (batch.supplierPhone != null && batch.supplierPhone!.isNotEmpty) ...[
                              const Text(' · ', style: TextStyle(color: Colors.grey)),
                              const Icon(Icons.phone, size: 13, color: Colors.grey),
                              const SizedBox(width: 2),
                              Text(batch.supplierPhone!, style: const TextStyle(fontSize: 13)),
                            ],
                          ],
                        ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 13, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(dateStr, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          const Spacer(),
                          Text(
                            'الكمية: ${batch.remainingQuantity.toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'التكلفة: ${batch.costPrice.toStringAsFixed(2)} د.ج',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.teal),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _BatchEntry {
  final Product product;
  final PurchaseBatch batch;

  _BatchEntry({required this.product, required this.batch});
}
