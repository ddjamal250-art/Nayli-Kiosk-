import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/utils/snackbar_helper.dart';
import '../../../../core/utils/sound_service.dart';
import '../../../product/domain/entities/product.dart';
import '../bloc/billing_bloc.dart';

class KioskTobaccoModal extends StatefulWidget {
  final Product product;
  final bool isWholesale;

  const KioskTobaccoModal({
    super.key,
    required this.product,
    this.isWholesale = false,
  });

  static Future<void> show(
    BuildContext context,
    Product product, {
    bool isWholesale = false,
  }) {
    SoundService.playTabSwitch();
    return showDialog(
      context: context,
      builder: (ctx) => KioskTobaccoModal(
        product: product,
        isWholesale: isWholesale,
      ),
    );
  }

  @override
  State<KioskTobaccoModal> createState() => _KioskTobaccoModalState();
}

class _KioskTobaccoModalState extends State<KioskTobaccoModal> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Tobacco State
  int _cigaretteCount = 1;
  int _packQty = 1;
  int _cartonQty = 1;
  bool _isWholesale = false;
  final TextEditingController _customCigaretteCtrl = TextEditingController(text: '1');

  // Meter State
  double _meterLength = 1.0;
  final TextEditingController _meterCtrl = TextEditingController(text: '1.0');

  // ML State
  double _mlVolume = 30.0;
  final TextEditingController _mlCtrl = TextEditingController(text: '30');

  @override
  void initState() {
    super.initState();
    _isWholesale = widget.isWholesale;
    final p = widget.product;
    int tabCount = 3;
    if (p.unitType == 'meter' || p.unitType == 'ml') {
      tabCount = 1;
    }
    _tabController = TabController(length: tabCount, vsync: this);

    _customCigaretteCtrl.addListener(() {
      final val = int.tryParse(_customCigaretteCtrl.text.trim()) ?? 1;
      if (val != _cigaretteCount) {
        setState(() => _cigaretteCount = val.clamp(1, 200));
      }
    });

    _meterCtrl.addListener(() {
      final val = double.tryParse(_meterCtrl.text.trim()) ?? 1.0;
      if (val != _meterLength) {
        setState(() => _meterLength = val.clamp(0.1, 1000.0));
      }
    });

    _mlCtrl.addListener(() {
      final val = double.tryParse(_mlCtrl.text.trim()) ?? 30.0;
      if (val != _mlVolume) {
        setState(() => _mlVolume = val.clamp(1.0, 5000.0));
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _customCigaretteCtrl.dispose();
    _meterCtrl.dispose();
    _mlCtrl.dispose();
    super.dispose();
  }

  // --- Tobacco calculations ---
  double get _singlePiecePrice {
    final p = widget.product;
    if (p.singlePiecePrice > 0) return p.singlePiecePrice;
    final pieces = p.piecesPerPack > 0 ? p.piecesPerPack : 20;
    return (p.price / pieces).ceilToDouble();
  }

  double get _singlePieceCost {
    final p = widget.product;
    final pieces = p.piecesPerPack > 0 ? p.piecesPerPack : 20;
    return p.costPrice / pieces;
  }

  double get _packPrice {
    final p = widget.product;
    if (_isWholesale) {
      if (p.wholesalePackPrice > 0) return p.wholesalePackPrice;
      if (p.wholesalePrice > 0) return p.wholesalePrice;
    }
    return p.price;
  }

  double get _cartonPrice {
    final p = widget.product;
    final multiplier = p.packsPerCarton > 0 ? p.packsPerCarton : 10;
    if (_isWholesale) {
      if (p.wholesaleCartonPrice > 0) return p.wholesaleCartonPrice;
      if (p.cartonPrice > 0) return p.cartonPrice;
    }
    if (p.cartonPrice > 0) return p.cartonPrice;
    return _packPrice * multiplier;
  }

  double get _cartonCost {
    final p = widget.product;
    final multiplier = p.packsPerCarton > 0 ? p.packsPerCarton : 10;
    if (p.cartonCostPrice > 0) return p.cartonCostPrice;
    return p.costPrice * multiplier;
  }

  // --- Add Actions ---
  void _addPackToCart() {
    final p = widget.product;
    context.read<BillingBloc>().add(AddProductToCartEvent(
      p,
      unitLevel: 'pack',
      quantity: _packQty,
      customPrice: _isWholesale ? _packPrice : null,
    ));

    SoundService.playScanBeep();
    Navigator.pop(context);
    SnackbarHelper.showSuccess(context, '✅ $_packQty ${context.tr("pack")} "${p.name}" ' + (_isWholesale ? context.tr('wholesale_badge') : '') + ' ' + context.tr('added_to_cart'));
  }

  void _addCartonToCart() {
    final p = widget.product;
    context.read<BillingBloc>().add(AddProductToCartEvent(
      p,
      unitLevel: 'carton',
      quantity: _cartonQty,
      customPrice: _isWholesale ? _cartonPrice : null,
    ));

    SoundService.playScanBeep();
    Navigator.pop(context);
    SnackbarHelper.showSuccess(context, '📦 $_cartonQty ${context.tr("carton")} "${p.name}" ' + (_isWholesale ? context.tr('wholesale_badge') : '') + ' ' + context.tr('added_to_cart'));
  }

  void _addCigarettesToCart() {
    final p = widget.product;
    context.read<BillingBloc>().add(AddProductToCartEvent(
      p,
      unitLevel: 'piece',
      quantity: _cigaretteCount,
    ));

    SoundService.playScanBeep();
    Navigator.pop(context);
    SnackbarHelper.showSuccess(context, '🚬 $_cigaretteCount ${context.tr("cigarettes")} "${p.name}" ' + context.tr('added_to_cart'));
  }

  void _addMeterToCart() {
    final p = widget.product;
    final totalPrice = (_meterLength * p.price).roundToDouble();
    final totalCost = (_meterLength * p.costPrice);

    final itemProduct = Product(
      id: '${p.id}_meter_${DateTime.now().millisecondsSinceEpoch}',
      name: '${p.name} (${_meterLength.toStringAsFixed(1)} متر)',
      barcode: p.barcode,
      price: totalPrice,
      costPrice: totalCost,
      stock: p.stock,
      category: p.category,
      unitType: 'meter',
    );

    context.read<BillingBloc>().add(AddProductToCartEvent(itemProduct));
    SoundService.playScanBeep();
    Navigator.pop(context);
    SnackbarHelper.showSuccess(context, '📏 ${_meterLength.toStringAsFixed(1)} ${context.tr("meter")} "${p.name}" ' + context.tr('added_to_cart'));
  }

  void _addMlToCart() {
    final p = widget.product;
    final totalPrice = ((_mlVolume / 100.0) * p.price).roundToDouble();
    final totalCost = ((_mlVolume / 100.0) * p.costPrice);

    final itemProduct = Product(
      id: '${p.id}_ml_${DateTime.now().millisecondsSinceEpoch}',
      name: '${p.name} (${_mlVolume.toStringAsFixed(0)} مل)',
      barcode: p.barcode,
      price: totalPrice > 0 ? totalPrice : p.price,
      costPrice: totalCost,
      stock: p.stock,
      category: p.category,
      unitType: 'ml',
    );

    context.read<BillingBloc>().add(AddProductToCartEvent(itemProduct));
    SoundService.playScanBeep();
    Navigator.pop(context);
    SnackbarHelper.showSuccess(context, '💧 ${_mlVolume.toStringAsFixed(0)} ${context.tr("ml")} "${p.name}" ' + context.tr('added_to_cart'));
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final isTobacco = p.isTobacco || p.category.contains('تبغ') || p.singlePiecePrice > 0 || p.cartonPrice > 0;

    return Dialog(
      backgroundColor: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: 480,
        constraints: const BoxConstraints(maxHeight: 560),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isTobacco ? Colors.amber.shade100 : Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isTobacco ? '🚬' : (p.unitType == 'meter' ? '📏' : '💧'),
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (widget.isWholesale)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              margin: const EdgeInsets.only(left: 6),
                              decoration: BoxDecoration(color: Colors.indigo, borderRadius: BorderRadius.circular(6)),
                              child: Text(context.tr('wholesale_badge'), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                          Text('${context.tr("barcode")}: ${p.barcode} • ${context.tr("stock")}: ${p.stock}', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Wholesale vs Retail Mode Switcher
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        setState(() => _isWholesale = false);
                        SoundService.playTabSwitch();
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: !_isWholesale ? Colors.amber.shade700 : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.storefront_outlined, size: 15, color: !_isWholesale ? Colors.white : Colors.black87),
                            const SizedBox(width: 5),
                            Text(
                              context.tr('retail_detail'),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: !_isWholesale ? FontWeight.bold : FontWeight.normal,
                                color: !_isWholesale ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        setState(() => _isWholesale = true);
                        SoundService.playTabSwitch();
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: _isWholesale ? Colors.indigo : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inventory_2_outlined, size: 15, color: _isWholesale ? Colors.white : Colors.black87),
                            const SizedBox(width: 5),
                            Text(
                              context.tr('wholesale_gros'),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: _isWholesale ? FontWeight.bold : FontWeight.normal,
                                color: _isWholesale ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Tab bar for tobacco: [ باكي | كرطوشة | بالسيجارة ]
            if (isTobacco) ...[
              Container(
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: Colors.amber.shade800,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.black87,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  tabs: [
                    Tab(text: context.tr('pack_box_tab')),
                    Tab(text: context.tr('carton_10_tab')),
                    Tab(text: context.tr('single_piece_tab')),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildPackTab(),
                    _buildCartonTab(),
                    _buildCigaretteTab(),
                  ],
                ),
              ),
            ] else if (p.unitType == 'meter') ...[
              Flexible(child: _buildMeterTab()),
            ] else if (p.unitType == 'ml') ...[
              Flexible(child: _buildMlTab()),
            ] else ...[
              Flexible(child: _buildPackTab()),
            ],
          ],
        ),
      ),
    );
  }

  // --- TAB 1: Pack Tab ---
  Widget _buildPackTab() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.amber.shade200),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.tr('pack_price_label'), style: const TextStyle(fontSize: 12, color: Colors.black54)),
                  const SizedBox(height: 4),
                  Text(context.tr('regular_sale'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ],
              ),
              Text(
                '${_packPrice.toStringAsFixed(0)} ' + context.tr('currency_symbol'),
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 24, color: Colors.amber.shade900),
              ),
            ],
          ),
        ),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton.filledTonal(
              icon: const Icon(Icons.remove),
              onPressed: _packQty > 1 ? () => setState(() => _packQty--) : null,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text('$_packQty ' + context.tr('pack'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            IconButton.filledTonal(
              icon: const Icon(Icons.add),
              onPressed: () => setState(() => _packQty++),
            ),
          ],
        ),

        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amber.shade800,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.add_shopping_cart),
          label: Text(
            '${context.tr("add")} $_packQty ' + context.tr('pack') + ' (${(_packQty * _packPrice).toStringAsFixed(0)} ' + context.tr('currency_symbol') + ')',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          onPressed: _addPackToCart,
        ),
      ],
    );
  }

  // --- TAB 2: Carton Tab ---
  Widget _buildCartonTab() {
    final multiplier = widget.product.packsPerCarton > 0 ? widget.product.packsPerCarton : 10;
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${context.tr("carton_price_label")} ($multiplier ' + context.tr('packs') + '):', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                  const SizedBox(height: 4),
                  Text(widget.isWholesale ? context.tr('wholesale_price') : context.tr('retail_price'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ],
              ),
              Text(
                '${_cartonPrice.toStringAsFixed(0)} ' + context.tr('currency_symbol'),
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 24, color: Colors.blue.shade900),
              ),
            ],
          ),
        ),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton.filledTonal(
              icon: const Icon(Icons.remove),
              onPressed: _cartonQty > 1 ? () => setState(() => _cartonQty--) : null,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text('$_cartonQty ' + context.tr('carton'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            IconButton.filledTonal(
              icon: const Icon(Icons.add),
              onPressed: () => setState(() => _cartonQty++),
            ),
          ],
        ),

        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.indigo,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.inventory_2_outlined),
          label: Text(
            '${context.tr("add")} $_cartonQty ' + context.tr('carton') + ' (${(_cartonQty * _cartonPrice).toStringAsFixed(0)} ' + context.tr('currency_symbol') + ')',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          onPressed: _addCartonToCart,
        ),
      ],
    );
  }

  // --- TAB 3: Cigarette / Piece Tab ---
  Widget _buildCigaretteTab() {
    final singlePrice = _singlePiecePrice;
    final total = (_cigaretteCount * singlePrice).roundToDouble();

    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.deepOrange.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.deepOrange.shade200),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.tr('single_piece_price'), style: const TextStyle(fontSize: 11, color: Colors.black54)),
                  Text('${singlePrice.toStringAsFixed(0)} ' + context.tr('currency_symbol') + ' / ' + context.tr('piece'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
              Text(
                '${context.tr("total")}: ${total.toStringAsFixed(0)} ' + context.tr('currency_symbol'),
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: Colors.deepOrange.shade900),
              ),
            ],
          ),
        ),

        // Quick Count Buttons: [1, 2, 3, 4, 5, 10]
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [1, 2, 3, 4, 5, 10].map((c) {
            final isSelected = _cigaretteCount == c;
            return ChoiceChip(
              label: Text('$c ' + context.tr('pieces'), style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.black87)),
              selected: isSelected,
              selectedColor: Colors.deepOrange.shade700,
              backgroundColor: Colors.grey.shade100,
              onSelected: (_) {
                setState(() {
                  _cigaretteCount = c;
                  _customCigaretteCtrl.text = c.toString();
                });
              },
            );
          }).toList(),
        ),

        // Custom Count Row
        Row(
          children: [
            Text(context.tr('custom_count'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: _customCigaretteCtrl,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: context.tr('count_cigarettes'),
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                ),
              ),
            ),
          ],
        ),

        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepOrange.shade800,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.smoking_rooms_rounded),
          label: Text(
            '${context.tr("add")} $_cigaretteCount ' + context.tr('cigarettes') + ' (${total.toStringAsFixed(0)} ' + context.tr('currency_symbol') + ')',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          onPressed: _addCigarettesToCart,
        ),
      ],
    );
  }

  // --- METER TAB ---
  Widget _buildMeterTab() {
    final p = widget.product;
    final total = (_meterLength * p.price).roundToDouble();

    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.teal.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.teal.shade200),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.tr('meter_price_label'), style: const TextStyle(fontSize: 11, color: Colors.black54)),
                  Text('${p.price.toStringAsFixed(0)} ' + context.tr('currency_symbol') + ' / ' + context.tr('meter'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
              Text(
                '${context.tr("total")}: ${total.toStringAsFixed(0)} ' + context.tr('currency_symbol'),
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: Colors.teal.shade900),
              ),
            ],
          ),
        ),

        // Quick Length Chips: [0.5, 1.0, 1.5, 2.0, 3.0, 5.0]
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [0.5, 1.0, 1.5, 2.0, 3.0, 5.0].map((m) {
            final isSelected = (_meterLength - m).abs() < 0.05;
            return ChoiceChip(
              label: Text('$m ' + context.tr('meter'), style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.black87)),
              selected: isSelected,
              selectedColor: Colors.teal.shade700,
              backgroundColor: Colors.grey.shade100,
              onSelected: (_) {
                setState(() {
                  _meterLength = m;
                  _meterCtrl.text = m.toString();
                });
              },
            );
          }).toList(),
        ),

        Row(
          children: [
            Text(context.tr('custom_length'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: _meterCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: 'مثال: 1.5',
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                ),
              ),
            ),
          ],
        ),

        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal.shade700,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.straighten_rounded),
          label: Text(
            '${context.tr("add")} ${_meterLength.toStringAsFixed(1)} ' + context.tr('meter') + ' (${total.toStringAsFixed(0)} ' + context.tr('currency_symbol') + ')',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          onPressed: _addMeterToCart,
        ),
      ],
    );
  }

  // --- ML TAB ---
  Widget _buildMlTab() {
    final p = widget.product;
    final total = ((_mlVolume / 100.0) * p.price).roundToDouble();

    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.purple.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.purple.shade200),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.tr('bottle_price_label'), style: const TextStyle(fontSize: 11, color: Colors.black54)),
                  Text('${p.price.toStringAsFixed(0)} دج', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
              Text(
                '${context.tr("total")}: ${total.toStringAsFixed(0)} ' + context.tr('currency_symbol'),
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: Colors.purple.shade900),
              ),
            ],
          ),
        ),

        // Quick ml Chips: [10, 20, 30, 50, 100]
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [10.0, 20.0, 30.0, 50.0, 100.0].map((v) {
            final isSelected = (_mlVolume - v).abs() < 0.5;
            return ChoiceChip(
              label: Text('${v.toInt()} ' + context.tr('ml'), style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.black87)),
              selected: isSelected,
              selectedColor: Colors.purple.shade700,
              backgroundColor: Colors.grey.shade100,
              onSelected: (_) {
                setState(() {
                  _mlVolume = v;
                  _mlCtrl.text = v.toInt().toString();
                });
              },
            );
          }).toList(),
        ),

        Row(
          children: [
            Text(context.tr('custom_volume'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: _mlCtrl,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: 'مثال: 30',
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                ),
              ),
            ),
          ],
        ),

        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.purple.shade700,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.water_drop_outlined),
          label: Text(
            '${context.tr("add")} ${_mlVolume.toStringAsFixed(0)} ' + context.tr('ml') + ' (${total.toStringAsFixed(0)} ' + context.tr('currency_symbol') + ')',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          onPressed: _addMlToCart,
        ),
      ],
    );
  }
}
