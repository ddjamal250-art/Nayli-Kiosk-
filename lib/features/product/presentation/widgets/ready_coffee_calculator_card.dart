import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class CoffeeExtraIngredient {
  String name;
  double packCost;
  int packUnits;

  CoffeeExtraIngredient({
    required this.name,
    this.packCost = 0.0,
    this.packUnits = 1,
  });

  double get unitCost => (packUnits > 0) ? (packCost / packUnits) : 0.0;
}

class ReadyCoffeeData {
  String drinkType; // 'express', 'capsule', 'tea', 'custom'
  String drinkName;
  double basePackCost;
  int baseYieldCount;
  bool includeGobelet;
  double gobeletPackCost;
  int gobeletPackCount;
  bool includeSugar;
  double sugarPackCost;
  int sugarPackCount;
  List<CoffeeExtraIngredient> extras;
  double salePrice;
  bool pinToQuickSale;
  String quickIcon;
  String quickShortCode;

  ReadyCoffeeData({
    this.drinkType = 'express',
    this.drinkName = 'قهوة عادية (Express)',
    this.basePackCost = 1500.0,
    this.baseYieldCount = 50,
    this.includeGobelet = true,
    this.gobeletPackCost = 250.0,
    this.gobeletPackCount = 50,
    this.includeSugar = true,
    this.sugarPackCost = 300.0,
    this.sugarPackCount = 100,
    List<CoffeeExtraIngredient>? extras,
    this.salePrice = 40.0,
    this.pinToQuickSale = true,
    this.quickIcon = '☕',
    this.quickShortCode = 'C1',
  }) : extras = extras ?? [];

  double get baseUnitCost => (baseYieldCount > 0) ? (basePackCost / baseYieldCount) : 0.0;
  double get gobeletUnitCost => (includeGobelet && gobeletPackCount > 0) ? (gobeletPackCost / gobeletPackCount) : 0.0;
  double get sugarUnitCost => (includeSugar && sugarPackCount > 0) ? (sugarPackCost / sugarPackCount) : 0.0;
  double get extrasTotalUnitCost => extras.fold(0.0, (sum, item) => sum + item.unitCost);

  double get totalCupCost => baseUnitCost + gobeletUnitCost + sugarUnitCost + extrasTotalUnitCost;
  double get netProfit => salePrice - totalCupCost;
  double get marginPercent => (salePrice > 0) ? ((netProfit / salePrice) * 100.0) : 0.0;
}

class ReadyCoffeeCalculatorCard extends StatefulWidget {
  final ReadyCoffeeData initialData;
  final ValueChanged<ReadyCoffeeData> onChanged;

  const ReadyCoffeeCalculatorCard({
    super.key,
    required this.initialData,
    required this.onChanged,
  });

  @override
  State<ReadyCoffeeCalculatorCard> createState() => _ReadyCoffeeCalculatorCardState();
}

class _ReadyCoffeeCalculatorCardState extends State<ReadyCoffeeCalculatorCard> {
  late ReadyCoffeeData _data;

  late TextEditingController _basePackCostCtrl;
  late TextEditingController _baseYieldCtrl;
  late TextEditingController _gobeletCostCtrl;
  late TextEditingController _gobeletQtyCtrl;
  late TextEditingController _sugarCostCtrl;
  late TextEditingController _sugarQtyCtrl;
  late TextEditingController _salePriceCtrl;
  late TextEditingController _shortCodeCtrl;

  @override
  void initState() {
    super.initState();
    _data = widget.initialData;
    _basePackCostCtrl = TextEditingController(text: _data.basePackCost > 0 ? _data.basePackCost.toStringAsFixed(0) : '');
    _baseYieldCtrl = TextEditingController(text: _data.baseYieldCount > 0 ? _data.baseYieldCount.toString() : '50');
    _gobeletCostCtrl = TextEditingController(text: _data.gobeletPackCost > 0 ? _data.gobeletPackCost.toStringAsFixed(0) : '250');
    _gobeletQtyCtrl = TextEditingController(text: _data.gobeletPackCount > 0 ? _data.gobeletPackCount.toString() : '50');
    _sugarCostCtrl = TextEditingController(text: _data.sugarPackCost > 0 ? _data.sugarPackCost.toStringAsFixed(0) : '300');
    _sugarQtyCtrl = TextEditingController(text: _data.sugarPackCount > 0 ? _data.sugarPackCount.toString() : '100');
    _salePriceCtrl = TextEditingController(text: _data.salePrice > 0 ? _data.salePrice.toStringAsFixed(0) : '40');
    _shortCodeCtrl = TextEditingController(text: _data.quickShortCode);
  }

  @override
  void dispose() {
    _basePackCostCtrl.dispose();
    _baseYieldCtrl.dispose();
    _gobeletCostCtrl.dispose();
    _gobeletQtyCtrl.dispose();
    _sugarCostCtrl.dispose();
    _sugarQtyCtrl.dispose();
    _salePriceCtrl.dispose();
    _shortCodeCtrl.dispose();
    super.dispose();
  }

  void _notify() {
    widget.onChanged(_data);
    setState(() {});
  }

  void _selectDrinkType(String type) {
    _data.drinkType = type;
    if (type == 'express') {
      _data.drinkName = 'قهوة عادية (Express)';
      _data.quickIcon = '☕';
      _data.quickShortCode = 'C1';
      _data.baseYieldCount = 50;
      _data.salePrice = 40.0;
      _baseYieldCtrl.text = '50';
      _salePriceCtrl.text = '40';
      _shortCodeCtrl.text = 'C1';
    } else if (type == 'capsule') {
      _data.drinkName = 'قهوة كبسولة (Capsule)';
      _data.quickIcon = '🟤';
      _data.quickShortCode = 'C2';
      _data.baseYieldCount = 20;
      _data.salePrice = 60.0;
      _baseYieldCtrl.text = '20';
      _salePriceCtrl.text = '60';
      _shortCodeCtrl.text = 'C2';
    } else if (type == 'tea') {
      _data.drinkName = 'كأس شاي (Thé)';
      _data.quickIcon = '🍵';
      _data.quickShortCode = 'C3';
      _data.baseYieldCount = 80;
      _data.salePrice = 30.0;
      _baseYieldCtrl.text = '80';
      _salePriceCtrl.text = '30';
      _shortCodeCtrl.text = 'C3';
    } else {
      _data.quickIcon = '☕';
      _data.quickShortCode = 'C4';
      _shortCodeCtrl.text = 'C4';
    }
    _notify();
  }

  void _addCustomExtraDialog() {
    final nameCtrl = TextEditingController();
    final costCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '100');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.add_circle, color: Colors.brown),
            SizedBox(width: 8),
            Text('إضافة مادة أو مستلزم إضافي', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'أدخل اسم المادة وسعر تكلفتها والكمية بالعبوة لحساب حصة الكأس تلقائياً:',
              style: TextStyle(fontSize: 11.5, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'اسم المادة',
                hintText: 'مثال: ملاعق تحريك، حليب، نكهات...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: costCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'سعر العبوة (دج)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: qtyCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'الكمية/حبات',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.brown, foregroundColor: Colors.white),
            onPressed: () {
              final name = nameCtrl.text.trim();
              final cost = double.tryParse(costCtrl.text.trim()) ?? 0.0;
              final qty = int.tryParse(qtyCtrl.text.trim()) ?? 1;
              if (name.isNotEmpty && qty > 0) {
                _data.extras.add(CoffeeExtraIngredient(name: name, packCost: cost, packUnits: qty));
                Navigator.pop(ctx);
                _notify();
              }
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final baseCostPerCup = _data.baseUnitCost;
    final gobeletCostPerCup = _data.gobeletUnitCost;
    final sugarCostPerCup = _data.sugarUnitCost;
    final totalCost = _data.totalCupCost;
    final profit = _data.netProfit;
    final margin = _data.marginPercent;
    final isProfitable = profit >= 0;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF7F2),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD7CCC8), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.brown.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.brown.shade700,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('☕', style: TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'حاسبة تكلفة ومكونات القهوة الجاهزة ☕⚡',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF4E342E)),
                    ),
                    Text(
                      'حساب دقيق لتكلفة الكأس الواحد (بن/كبسولة + غوبلي + سكر + إضافات) وهامش الربح قبل البيع',
                      style: TextStyle(fontSize: 11, color: Color(0xFF795548)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24, color: Color(0xFFD7CCC8)),

          // 1. Drink Quick Type Selector
          const Text('1. نوع المشروب الجاهز:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF4E342E))),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildTypeChip('☕ قهوة عادية (Express)', 'express'),
                const SizedBox(width: 8),
                _buildTypeChip('🟤 قهوة كبسولة (Capsule)', 'capsule'),
                const SizedBox(width: 8),
                _buildTypeChip('🍵 كأس شاي (Thé)', 'tea'),
                const SizedBox(width: 8),
                _buildTypeChip('➕ مشروب مخصص', 'custom'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. Base Material Yield Inputs
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE0D7D0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _data.drinkType == 'capsule'
                          ? 'المادة الأساسية: علبة الكبسولات'
                          : (_data.drinkType == 'tea' ? 'المادة الأساسية: علبة الشاي' : 'المادة الأساسية: كيس البن (حبوب/مطحون)'),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF5D4037)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: Colors.brown.shade50, borderRadius: BorderRadius.circular(6)),
                      child: Text(
                        'حصة الكأس: ${baseCostPerCup.toStringAsFixed(2)} دج',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.brown.shade800),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _basePackCostCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: _data.drinkType == 'capsule' ? 'سعر علبة الكبسولات (دج)' : 'سعر كيس البن / العبوة (دج)',
                          hintText: 'مثلاً: 1500',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        ),
                        onChanged: (val) {
                          _data.basePackCost = double.tryParse(val.trim()) ?? 0.0;
                          _notify();
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _baseYieldCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: _data.drinkType == 'capsule' ? 'عدد الكبسولات' : 'عدد الكؤوس المنتجة',
                          hintText: 'مثلاً: 50',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        ),
                        onChanged: (val) {
                          _data.baseYieldCount = int.tryParse(val.trim()) ?? 1;
                          _notify();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 3. Supplies (Gobelets & Sugar)
          const Text('2. مستلزمات التحضير والتقديم للكأس:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF4E342E))),
          const SizedBox(height: 8),

          // Gobelet Row
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE0D7D0)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Checkbox(
                      value: _data.includeGobelet,
                      activeColor: Colors.brown,
                      onChanged: (v) {
                        _data.includeGobelet = v ?? true;
                        _notify();
                      },
                    ),
                    const Text('🥤 الكؤوس / الغوبلي (Gobelets)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    const Spacer(),
                    Text(
                      _data.includeGobelet ? '${gobeletCostPerCup.toStringAsFixed(2)} دج / كأس' : 'معطل',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: _data.includeGobelet ? Colors.teal : Colors.grey),
                    ),
                  ],
                ),
                if (_data.includeGobelet)
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _gobeletCostCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'سعر باكي الغوبلي (دج)',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          ),
                          onChanged: (val) {
                            _data.gobeletPackCost = double.tryParse(val.trim()) ?? 0.0;
                            _notify();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: _gobeletQtyCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'عدد الغوبليات بالباكي',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          ),
                          onChanged: (val) {
                            _data.gobeletPackCount = int.tryParse(val.trim()) ?? 1;
                            _notify();
                          },
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Sugar Row
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE0D7D0)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Checkbox(
                      value: _data.includeSugar,
                      activeColor: Colors.brown,
                      onChanged: (v) {
                        _data.includeSugar = v ?? true;
                        _notify();
                      },
                    ),
                    const Text('🧂 السكر (ساشيات Sachets)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    const Spacer(),
                    Text(
                      _data.includeSugar ? '${sugarCostPerCup.toStringAsFixed(2)} دج / كأس' : 'معطل',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: _data.includeSugar ? Colors.teal : Colors.grey),
                    ),
                  ],
                ),
                if (_data.includeSugar)
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _sugarCostCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'سعر علبة السكر (دج)',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          ),
                          onChanged: (val) {
                            _data.sugarPackCost = double.tryParse(val.trim()) ?? 0.0;
                            _notify();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: _sugarQtyCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'عدد الأكياس بالعلبة',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          ),
                          onChanged: (val) {
                            _data.sugarPackCount = int.tryParse(val.trim()) ?? 1;
                            _notify();
                          },
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // 4. Custom Extra Ingredients
          if (_data.extras.isNotEmpty) ...[
            const Text('مواد إضافية مخصصة:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF5D4037))),
            const SizedBox(height: 6),
            ..._data.extras.asMap().entries.map((entry) {
              final idx = entry.key;
              final item = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, size: 16, color: Colors.brown),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${item.name} (${item.packCost.toStringAsFixed(0)} دج ÷ ${item.packUnits} حبة = ${item.unitCost.toStringAsFixed(2)} دج/كأس)',
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        _data.extras.removeAt(idx);
                        _notify();
                      },
                    ),
                  ],
                ),
              );
            }),
          ],

          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.brown.shade800,
              side: BorderSide(color: Colors.brown.shade300),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: _addCustomExtraDialog,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('+ إضافة مادة أخرى (ملعقة، حليب، نكهة...)', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 16),

          // 5. Live Summary & Profit Margin Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isProfitable
                    ? [const Color(0xFFE8F5E9), const Color(0xFFC8E6C9)]
                    : [const Color(0xFFFFEBEE), const Color(0xFFFFCDD2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isProfitable ? Colors.green.shade400 : Colors.red.shade400, width: 1.5),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('إجمالي تكلفة الكأس قبل البيع:', style: TextStyle(fontSize: 11, color: Colors.black87)),
                        Text(
                          '${totalCost.toStringAsFixed(2)} دج',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFFB71C1C)),
                        ),
                      ],
                    ),
                    Container(
                      width: 130,
                      child: TextFormField(
                        controller: _salePriceCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1B5E20)),
                        decoration: InputDecoration(
                          labelText: 'سعر بيع الكأس',
                          suffixText: 'دج',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                        onChanged: (val) {
                          _data.salePrice = double.tryParse(val.trim()) ?? 0.0;
                          _notify();
                        },
                      ),
                    ),
                  ],
                ),
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(isProfitable ? Icons.trending_up : Icons.trending_down,
                            color: isProfitable ? Colors.green.shade800 : Colors.red.shade800, size: 20),
                        const SizedBox(width: 6),
                        Text(
                          'صافي الربح للكأس: ${profit >= 0 ? "+" : ""}${profit.toStringAsFixed(2)} دج',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: isProfitable ? Colors.green.shade900 : Colors.red.shade900,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isProfitable ? Colors.green.shade800 : Colors.red.shade800,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'هامش الربح: ${margin.toStringAsFixed(1)}%',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 6. Pin to Quick Sale Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.teal.shade200),
            ),
            child: Row(
              children: [
                Checkbox(
                  value: _data.pinToQuickSale,
                  activeColor: Colors.teal,
                  onChanged: (v) {
                    _data.pinToQuickSale = v ?? true;
                    _notify();
                  },
                ),
                const Icon(Icons.flash_on, color: Colors.teal, size: 20),
                const SizedBox(width: 4),
                const Expanded(
                  child: Text(
                    '⚡ تثبيت تلقائي في شريط البيع السريع بالكاسة',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.teal),
                  ),
                ),
                if (_data.pinToQuickSale) ...[
                  DropdownButton<String>(
                    value: _data.quickIcon,
                    underline: const SizedBox(),
                    items: ['☕', '🟤', '🍵', '🥤', '🏷️']
                        .map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 18))))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        _data.quickIcon = v;
                        _notify();
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeChip(String label, String type) {
    final isSelected = _data.drinkType == type;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.brown.shade900)),
      selected: isSelected,
      selectedColor: Colors.brown.shade700,
      backgroundColor: Colors.white,
      side: BorderSide(color: isSelected ? Colors.brown.shade700 : Colors.brown.shade200),
      onSelected: (_) => _selectDrinkType(type),
    );
  }
}
