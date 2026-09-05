import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/data/hive_database.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/printer_helper.dart';

class ShoppingListPage extends StatefulWidget {
  const ShoppingListPage({super.key});

  @override
  State<ShoppingListPage> createState() => _ShoppingListPageState();
}

class _ShoppingListPageState extends State<ShoppingListPage> {
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  void _loadItems() {
    final box = HiveDatabase.shoppingListBox;
    final List<Map<String, dynamic>> list = [];
    for (var key in box.keys) {
      final val = box.get(key);
      if (val is Map) {
        list.add(Map<String, dynamic>.from(val));
      }
    }
    setState(() {
      _items = list;
    });
  }

  void _removeItem(String id) {
    HiveDatabase.shoppingListBox.delete(id);
    _loadItems();
  }

  void _updateQuantity(String id, int qty) {
    if (qty <= 0) {
      _removeItem(id);
      return;
    }
    final item = HiveDatabase.shoppingListBox.get(id);
    if (item is Map) {
      item['qtyToBuy'] = qty;
      HiveDatabase.shoppingListBox.put(id, item);
      _loadItems();
    }
  }

  Future<void> _printList() async {
    if (_items.isEmpty) return;
    final printer = PrinterHelper();
    
    // Fallback simple printing if needed or real printing
    try {
      if (!printer.isConnected) {
        final savedMac = HiveDatabase.settingsBox.get('printer_mac');
        if (savedMac != null) {
          await printer.connect(savedMac);
        }
      }
      
      if (printer.isConnected) {
        final printItems = _items.map((e) => {
          'name': e['name'],
          'qty': e['qtyToBuy'],
          'price': '-',
          'total': '-',
        }).toList();

        await printer.printReceipt(
          shopName: 'قائمة النواقص (التسوق)',
          address1: 'تاريخ: ${DateTime.now().toString().split('.')[0]}',
          address2: '',
          phone: '',
          items: printItems,
          total: 0.0,
          footer: '-------------------------',
        );
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت الطباعة بنجاح')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الطابعة غير متصلة')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('قائمة النواقص (التسوق)', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.print, color: AppTheme.primaryColor),
            tooltip: 'طباعة القائمة',
            onPressed: _printList,
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep, color: Colors.red),
            tooltip: 'إفراغ القائمة',
            onPressed: () {
              HiveDatabase.shoppingListBox.clear();
              _loadItems();
            },
          ),
        ],
      ),
      body: _items.isEmpty
          ? const Center(child: Text('قائمة النواقص فارغة، لا يوجد منتجات بحاجة للشراء.'))
          : ListView.builder(
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.orange,
                      child: Icon(Icons.shopping_cart, color: Colors.white),
                    ),
                    title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('المخزون الحالي: ${item['currentStock']}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                          onPressed: () => _updateQuantity(item['id'], item['qtyToBuy'] - 1),
                        ),
                        Text('${item['qtyToBuy']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                          onPressed: () => _updateQuantity(item['id'], item['qtyToBuy'] + 1),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
