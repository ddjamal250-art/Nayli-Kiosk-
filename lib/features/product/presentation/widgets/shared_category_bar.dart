import 'package:flutter/material.dart';
import '../../../../core/utils/category_taxonomy.dart';
import '../../../../core/data/hive_database.dart';
import '../../../product/domain/entities/product.dart';

class SharedCategoryBar extends StatefulWidget {
  final String selectedCategory;
  final Function(String, String) onCategoryChanged;
  final Widget? leadingAction;

  const SharedCategoryBar({
    Key? key,
    required this.selectedCategory,
    required this.onCategoryChanged,
    this.leadingAction,
  }) : super(key: key);

  @override
  State<SharedCategoryBar> createState() => SharedCategoryBarState();
}

class SharedCategoryBarState extends State<SharedCategoryBar> {
  final Set<String> _dynamicCategories = {};

  @override
  void initState() {
    super.initState();
    _loadCustomCategoriesFromDB();
  }

  void _loadCustomCategoriesFromDB() {
    final box = HiveDatabase.productBox;
    _dynamicCategories.clear();
    for (final product in box.values) {
      final cat = product.category.trim();
      if (cat.isNotEmpty && cat != 'عام') {
        _dynamicCategories.add(cat);
      }
    }
    setState(() {});
  }

  List<Map<String, dynamic>> _getAllCombinedCategories() {
    final List<Map<String, dynamic>> all = [
      {'key': 'all', 'ar': 'الكل', 'icon': '🌍', 'isDynamic': false},
    ];

    void addCat(String key, String arName, String icon, bool isDynamic) {
      if (!all.any((c) => c['key'] == key)) {
        all.add({'key': key, 'ar': arName, 'icon': icon, 'isDynamic': isDynamic});
      }
    }

    for (final cat in _dynamicCategories) {
      final icon = CategoryTaxonomy.getIconForCategory(cat);
      addCat(cat, cat, icon, true);
    }

    for (final cat in CategoryTaxonomy.getDropdownCategories()) {
      final icon = CategoryTaxonomy.getIconForCategory(cat);
      addCat(cat, cat, icon, false);
    }
    return all;
  }

  List<Map<String, dynamic>> _getOrderedVisibleCategories() {
    final all = _getAllCombinedCategories();
    final hidden = CategoryTaxonomy.getHiddenCategories();
    final order = CategoryTaxonomy.getCategoryOrder();

    final visible = all.where((c) {
      final key = c['key'] as String;
      final name = c['ar'] as String;
      return key == 'all' || (!hidden.contains(key) && !hidden.contains(name));
    }).toList();

    visible.sort((a, b) {
      if (a['key'] == 'all') return -1;
      if (b['key'] == 'all') return 1;

      final keyA = a['key'] as String;
      final keyB = b['key'] as String;

      final idxA = order.indexOf(keyA);
      final idxB = order.indexOf(keyB);

      if (idxA != -1 && idxB != -1) return idxA.compareTo(idxB);
      if (idxA != -1) return -1;
      if (idxB != -1) return 1;

      return (a['ar'] as String).compareTo(b['ar'] as String);
    });

    return visible;
  }

  void _showCategorySettingsModal() {
    final allCats = _getAllCombinedCategories();
    showDialog<bool>(
      context: context,
      builder: (ctx) => _CategorySettingsDialog(allCategories: allCats),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }
  
  // Expose reload method for parent if product added
  void reloadCategories() {
    _loadCustomCategoriesFromDB();
  }

  @override
  Widget build(BuildContext context) {
    final cats = _getOrderedVisibleCategories();
    
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: ListView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        scrollDirection: Axis.horizontal,
        children: [
          if (widget.leadingAction != null) widget.leadingAction!,
          if (widget.leadingAction != null) const SizedBox(width: 8),
          
          InkWell(
            onTap: _showCategorySettingsModal,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.category_rounded, size: 16, color: Colors.blue),
                  const SizedBox(width: 4),
                  Text('إعدادات التصنيفات', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 11)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          const SizedBox(height: 24, child: VerticalDivider(width: 1)),
          const SizedBox(width: 8),
          
          ...cats.map((cat) {
            final catName = cat['ar'] as String;
            final iconStr = cat['icon'] as String;
            final keyStr = cat['key'] as String;
            final isSelected = widget.selectedCategory == catName || (widget.selectedCategory == 'الكل' && catName == 'الكل');

            return Padding(
              padding: const EdgeInsets.only(right: 6.0),
              child: InkWell(
                onTap: () {
                  widget.onCategoryChanged(keyStr, catName);
                },
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.teal.shade500 : (Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade100),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? Colors.teal.shade600 : Colors.transparent,
                      width: 1.5,
                    ),
                    boxShadow: isSelected
                        ? [BoxShadow(color: Colors.teal.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 2))]
                        : [],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(iconStr, style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Text(
                        catName,
                        style: TextStyle(
                          color: isSelected ? Colors.white : (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87),
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}

class _CategorySettingsDialog extends StatefulWidget {
  final List<Map<String, dynamic>> allCategories;
  const _CategorySettingsDialog({Key? key, required this.allCategories}) : super(key: key);

  @override
  State<_CategorySettingsDialog> createState() => _CategorySettingsDialogState();
}

class _CategorySettingsDialogState extends State<_CategorySettingsDialog> {
  late List<Map<String, dynamic>> _orderedCategories;
  late Set<String> _hiddenKeys;

  @override
  void initState() {
    super.initState();
    final savedHidden = CategoryTaxonomy.getHiddenCategories().toSet();
    final savedOrder = CategoryTaxonomy.getCategoryOrder();

    final all = List<Map<String, dynamic>>.from(widget.allCategories);
    all.sort((a, b) {
      final keyA = a['key'] as String;
      final keyB = b['key'] as String;
      if (keyA == 'all') return -1;
      if (keyB == 'all') return 1;
      
      final idxA = savedOrder.indexOf(keyA);
      final idxB = savedOrder.indexOf(keyB);
      if (idxA != -1 && idxB != -1) return idxA.compareTo(idxB);
      if (idxA != -1) return -1;
      if (idxB != -1) return 1;
      return (a['ar'] as String).compareTo(b['ar'] as String);
    });

    _orderedCategories = all;
    
    _hiddenKeys = {};
    for (var cat in all) {
      if (savedHidden.contains(cat['key']) || savedHidden.contains(cat['ar'])) {
        _hiddenKeys.add(cat['key']);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.category, color: Colors.blue),
          const SizedBox(width: 8),
          Text('ترتيب وإخفاء التصنيفات'),
        ],
      ),
      content: SizedBox(
        width: 440,
        height: 520,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('اسحب وأفلت التصنيفات لترتيبها، واضغط على أيقونة العين لإخفاء أي تصنيف لا تحتاجه.',
                        style: TextStyle(fontSize: 12, color: Colors.blue.shade800)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ReorderableListView.builder(
                itemCount: _orderedCategories.length,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex -= 1;
                    if (_orderedCategories[oldIndex]['key'] == 'all' || _orderedCategories[newIndex]['key'] == 'all') return;
                    final item = _orderedCategories.removeAt(oldIndex);
                    _orderedCategories.insert(newIndex, item);
                  });
                },
                itemBuilder: (context, index) {
                  final cat = _orderedCategories[index];
                  final isHidden = _hiddenKeys.contains(cat['key']);
                  final isAll = cat['key'] == 'all';
                  return Card(
                    key: ValueKey(cat['key']),
                    margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    color: isHidden ? Colors.grey.shade100 : Colors.white,
                    child: ListTile(
                      leading: Text(cat['icon'] as String, style: const TextStyle(fontSize: 20)),
                      title: Text(cat['ar'] as String,
                          style: TextStyle(fontWeight: FontWeight.bold, color: isHidden ? Colors.grey : Colors.black87)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!isAll)
                            IconButton(
                              icon: Icon(isHidden ? Icons.visibility_off : Icons.visibility,
                                  color: isHidden ? Colors.grey : Colors.teal),
                              onPressed: () {
                                setState(() {
                                  if (isHidden) {
                                    _hiddenKeys.remove(cat['key']);
                                  } else {
                                    _hiddenKeys.add(cat['key']);
                                  }
                                });
                              },
                            ),
                          if (!isAll) const Icon(Icons.drag_indicator, color: Colors.grey),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
          onPressed: () async {
            final orderList = _orderedCategories.map((c) => c['key'] as String).toList();
            await CategoryTaxonomy.saveCategoryOrder(orderList);
            
            final Set<String> toSaveHidden = {};
            for (final cat in _orderedCategories) {
              if (_hiddenKeys.contains(cat['key'])) {
                toSaveHidden.add(cat['key'] as String);
                toSaveHidden.add(cat['ar'] as String);
              }
            }
            await CategoryTaxonomy.saveHiddenCategories(toSaveHidden.toList());
            if (context.mounted) Navigator.pop(context, true);
          },
          child: const Text('حفظ التغييرات', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
