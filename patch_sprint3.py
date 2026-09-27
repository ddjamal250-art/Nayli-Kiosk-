import sys

file_path = 'd:/repos/Nayli Market -custom-/lib/features/product/presentation/pages/edit_product_page.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

target = '''            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _saveProduct,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: AppTheme.primaryColor,
              ),
              child: const Text('??? ?????????', style: TextStyle(fontSize: 18, color: Colors.white)),
            ),'''

new_target = '''            const SizedBox(height: 32),
            _buildSupplierArchive(),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _saveProduct,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: AppTheme.primaryColor,
              ),
              child: const Text('??? ?????????', style: TextStyle(fontSize: 18, color: Colors.white)),
            ),'''

content = content.replace(target, new_target)

func_target = '''  void _saveProduct() {'''
new_func = '''  Widget _buildSupplierArchive() {
    final batches = widget.product.stockBatches.reversed.toList();
    if (batches.isEmpty) return const SizedBox.shrink();

    return _SectionCard(
      title: '????? ???????? ?????? ????????',
      icon: Icons.history,
      children: [
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: batches.length,
          separatorBuilder: (_, __) => const Divider(),
          itemBuilder: (context, index) {
            final batch = batches[index];
            final dateStr = batch.dateAdded != null 
                ? "\-\-\" 
                : '????? ??? ?????';
            
            final supplierName = batch.supplierName ?? '??? ????';
            final supplierPhone = batch.supplierPhone ?? '';
            
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('??????: \', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(
                '?????? ????????: \\\n???????: \ ?.?\\n???????: \' + 
                (supplierPhone.isNotEmpty ? '\\n???? ??????: \' : ''),
              ),
              leading: const CircleAvatar(
                backgroundColor: Colors.teal,
                child: Icon(Icons.local_shipping, color: Colors.white, size: 20),
              ),
            );
          },
        ),
      ],
    );
  }

  void _saveProduct() {'''

content = content.replace(func_target, new_func)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
print('Sprint 3 Phase 1 applied')
