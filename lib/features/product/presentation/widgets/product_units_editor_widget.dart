import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/product_unit.dart';
import '../../domain/entities/special_offer.dart';

/// ويدجت موحد يجمع طبقات الوحدات الثلاث (كرتونة -> علبة -> حبة) والعروض الخاصة
/// معروضة عمودياً تحت بعضها البعض بشكل مرن يغطي جميع حالات البيع والاستلام في الواقع
class ProductUnitsEditorWidget extends StatefulWidget {

  // --- وضع الاستلام (Stock In / Arrivage) ---
  final bool isStockInMode;
  final TextEditingController? cartonCountCtrl; // عدد الكراتين المستلمة
  final TextEditingController? packCountCtrl;   // عدد العلب المستلمة
  final TextEditingController? pieceCountCtrl;  // عدد الحبات المستلمة
  final VoidCallback? onInputsChanged;

  // --- إعدادات الكرتونة (Large) ---
  final bool hasCarton;
  final ValueChanged<bool> onHasCartonChange;
  final TextEditingController cartonBarcodeCtrl;
  final TextEditingController cartonCapacityCtrl; // سعة الكرتونة بالحبة
  final TextEditingController cartonCostCtrl;
  final TextEditingController cartonPriceCtrl;
  final VoidCallback? onScanCartonBarcode;

  // --- إعدادات العلبة (Medium) ---
  final bool hasPack;
  final ValueChanged<bool> onHasPackChange;
  final TextEditingController packBarcodeCtrl;
  final TextEditingController packCapacityCtrl; // سعة العلبة بالحبة
  final TextEditingController packCostCtrl;
  final TextEditingController packPriceCtrl;
  final VoidCallback? onScanPackBarcode;

  // --- إعدادات الحبة (Base / Small) ---
  final TextEditingController pieceBarcodeCtrl;
  final TextEditingController pieceCostCtrl;
  final TextEditingController piecePriceCtrl;
  final TextEditingController? baseUnitNameCtrl;
  final VoidCallback? onScanPieceBarcode;

  // --- العروض الخاصة والتخفيضات الذكية ---
  final bool hasSpecialOffer;
  final ValueChanged<bool> onHasSpecialOfferChange;
  final UnitTier offerTier;
  final ValueChanged<UnitTier?> onOfferTierChange;
  final TextEditingController offerQtyCtrl;
  final TextEditingController offerPriceCtrl;

  const ProductUnitsEditorWidget({
    super.key,
    this.isStockInMode = false,
    this.cartonCountCtrl,
    this.packCountCtrl,
    this.pieceCountCtrl,
    this.onInputsChanged,

    required this.hasCarton,
    required this.onHasCartonChange,
    required this.cartonBarcodeCtrl,
    required this.cartonCapacityCtrl,
    required this.cartonCostCtrl,
    required this.cartonPriceCtrl,
    this.onScanCartonBarcode,

    required this.hasPack,
    required this.onHasPackChange,
    required this.packBarcodeCtrl,
    required this.packCapacityCtrl,
    required this.packCostCtrl,
    required this.packPriceCtrl,
    this.onScanPackBarcode,

    required this.pieceBarcodeCtrl,
    required this.pieceCostCtrl,
    required this.piecePriceCtrl,
    this.baseUnitNameCtrl,
    this.onScanPieceBarcode,

    required this.hasSpecialOffer,
    required this.onHasSpecialOfferChange,
    required this.offerTier,
    required this.onOfferTierChange,
    required this.offerQtyCtrl,
    required this.offerPriceCtrl,
    this.specialOffers,
    this.onSpecialOffersChange,
  });

  final List<SpecialOffer>? specialOffers;
  final ValueChanged<List<SpecialOffer>>? onSpecialOffersChange;

  @override
  State<ProductUnitsEditorWidget> createState() => _ProductUnitsEditorWidgetState();
}

class _OfferRowControllers {
  UnitTier tier;
  final TextEditingController qtyCtrl;
  final TextEditingController priceCtrl;

  _OfferRowControllers({
    required this.tier,
    required double quantity,
    required double price,
  })  : qtyCtrl = TextEditingController(
          text: quantity > 0
              ? (quantity == quantity.roundToDouble()
                  ? (quantity == quantity.roundToDouble() ? quantity.toInt().toString() : quantity.toString())
                  : quantity.toString())
              : '',
        ),
        priceCtrl = TextEditingController(
          text: price > 0
              ? (price == price.roundToDouble()
                  ? (price == price.roundToDouble() ? price.toInt().toString() : price.toString())
                  : price.toString())
              : '',
        );

  void dispose() {
    qtyCtrl.dispose();
    priceCtrl.dispose();
  }
}

class _ProductUnitsEditorWidgetState extends State<ProductUnitsEditorWidget> {
  final List<_OfferRowControllers> _offerControllers = [];

  // --- Convenience Getters to Delegate to Widget Properties ---
  bool get isStockInMode => widget.isStockInMode;
  TextEditingController? get cartonCountCtrl => widget.cartonCountCtrl;
  TextEditingController? get packCountCtrl => widget.packCountCtrl;
  TextEditingController? get pieceCountCtrl => widget.pieceCountCtrl;
  VoidCallback? get onInputsChanged => widget.onInputsChanged;

  bool get hasCarton => widget.hasCarton;
  ValueChanged<bool> get onHasCartonChange => widget.onHasCartonChange;
  TextEditingController get cartonBarcodeCtrl => widget.cartonBarcodeCtrl;
  TextEditingController get cartonCapacityCtrl => widget.cartonCapacityCtrl;
  TextEditingController get cartonCostCtrl => widget.cartonCostCtrl;
  TextEditingController get cartonPriceCtrl => widget.cartonPriceCtrl;
  VoidCallback? get onScanCartonBarcode => widget.onScanCartonBarcode;

  bool get hasPack => widget.hasPack;
  ValueChanged<bool> get onHasPackChange => widget.onHasPackChange;
  TextEditingController get packBarcodeCtrl => widget.packBarcodeCtrl;
  TextEditingController get packCapacityCtrl => widget.packCapacityCtrl;
  TextEditingController get packCostCtrl => widget.packCostCtrl;
  TextEditingController get packPriceCtrl => widget.packPriceCtrl;
  VoidCallback? get onScanPackBarcode => widget.onScanPackBarcode;

  TextEditingController get pieceBarcodeCtrl => widget.pieceBarcodeCtrl;
  TextEditingController get pieceCostCtrl => widget.pieceCostCtrl;
  TextEditingController get piecePriceCtrl => widget.piecePriceCtrl;
  TextEditingController? get baseUnitNameCtrl => widget.baseUnitNameCtrl;
  VoidCallback? get onScanPieceBarcode => widget.onScanPieceBarcode;

  bool get hasSpecialOffer => widget.hasSpecialOffer;
  ValueChanged<bool> get onHasSpecialOfferChange => widget.onHasSpecialOfferChange;
  UnitTier get offerTier => widget.offerTier;
  ValueChanged<UnitTier?> get onOfferTierChange => widget.onOfferTierChange;
  TextEditingController get offerQtyCtrl => widget.offerQtyCtrl;
  TextEditingController get offerPriceCtrl => widget.offerPriceCtrl;

  @override
  void initState() {
    super.initState();
    _initOfferControllers();
  }

  void _initOfferControllers() {
    for (final c in _offerControllers) {
      c.dispose();
    }
    _offerControllers.clear();

    if (widget.specialOffers != null && widget.specialOffers!.isNotEmpty) {
      for (final offer in widget.specialOffers!) {
        _offerControllers.add(_OfferRowControllers(
          tier: offer.targetTier,
          quantity: offer.quantity,
          price: offer.offerPrice,
        ));
      }
    } else if (hasSpecialOffer) {
      final q = double.tryParse(offerQtyCtrl.text.trim().replaceAll(',', '.').replaceAll('،', '.')) ?? 3.0;
      final pr = double.tryParse(offerPriceCtrl.text.trim().replaceAll(',', '.').replaceAll('،', '.')) ?? 0.0;
      _offerControllers.add(_OfferRowControllers(
        tier: offerTier,
        quantity: q,
        price: pr,
      ));
    }
    if (_offerControllers.isEmpty && hasSpecialOffer) {
      _offerControllers.add(_OfferRowControllers(
        tier: UnitTier.small,
        quantity: 3.0,
        price: 0.0,
      ));
    }
  }

  void _notifyOffersChanged() {
    final list = _offerControllers.map((c) {
      final q = double.tryParse(c.qtyCtrl.text.trim().replaceAll(',', '.').replaceAll('،', '.')) ?? 0.0;
      final p = double.tryParse(c.priceCtrl.text.trim().replaceAll(',', '.').replaceAll('،', '.')) ?? 0.0;
      return SpecialOffer(
        targetTier: c.tier,
        quantity: q,
        offerPrice: p,
        isEnabled: true,
      );
    }).where((o) => o.isValid).toList();

    widget.onSpecialOffersChange?.call(list);

    if (_offerControllers.isNotEmpty) {
      final first = _offerControllers.first;
      offerQtyCtrl.text = first.qtyCtrl.text;
      offerPriceCtrl.text = first.priceCtrl.text;
      if (first.tier != offerTier) {
        onOfferTierChange(first.tier);
      }
    }
  }

  @override
  void dispose() {
    for (final c in _offerControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ProductUnitsEditorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.hasPack != widget.hasPack || oldWidget.hasCarton != widget.hasCarton) {
      _onInputsChanged();
    }
    if (oldWidget.hasSpecialOffer != widget.hasSpecialOffer) {
      if (widget.hasSpecialOffer && _offerControllers.isEmpty) {
        _offerControllers.add(_OfferRowControllers(
          tier: UnitTier.small,
          quantity: 3.0,
          price: 0.0,
        ));
        _notifyOffersChanged();
      }
    }
  }

  double _safeDivide(double num, double den) {
    if (den <= 0) return 0.0;
    return num / den;
  }

  double _parse(TextEditingController? ctrl) {
    if (ctrl == null) return 0.0;
    final cleaned = ctrl.text.trim().replaceAll(',', '.').replaceAll('،', '.');
    return double.tryParse(cleaned) ?? 0.0;
  }

  void _onInputsChanged() {
    widget.onInputsChanged?.call();
    if (mounted) setState(() {});
  }

  double? get _suggestedPackCost {
    final cCost = _parse(widget.cartonCostCtrl);
    final cCap = _parse(widget.cartonCapacityCtrl);
    if (cCost > 0 && cCap > 0) {
      return (cCost / cCap);
    }
    return null;
  }

  double? get _suggestedPieceCost {
    final pCost = _parse(widget.packCostCtrl);
    final pCap = _parse(widget.packCapacityCtrl);
    if (widget.hasPack && pCost > 0 && pCap > 0) {
      return (pCost / pCap);
    }
    final cCost = _parse(widget.cartonCostCtrl);
    final cCap = _parse(widget.cartonCapacityCtrl);
    if (cCost > 0 && cCap > 0) {
      return (widget.hasPack && pCap > 0) ? (cCost / (cCap * pCap)) : (cCost / cCap);
    }
    return null;
  }

  double? get _suggestedPackPrice {
    final cPrice = _parse(widget.cartonPriceCtrl);
    final cCap = _parse(widget.cartonCapacityCtrl);
    if (cPrice > 0 && cCap > 0) {
      return (cPrice / cCap);
    }
    return null;
  }

  double? get _suggestedPiecePrice {
    final pPrice = _parse(widget.packPriceCtrl);
    final pCap = _parse(widget.packCapacityCtrl);
    if (widget.hasPack && pPrice > 0 && pCap > 0) {
      return (pPrice / pCap);
    }
    final cPrice = _parse(widget.cartonPriceCtrl);
    final cCap = _parse(widget.cartonCapacityCtrl);
    if (cPrice > 0 && cCap > 0) {
      return (widget.hasPack && pCap > 0) ? (cPrice / (cCap * pCap)) : (cPrice / cCap);
    }
    return null;
  }

  int? get _suggestedPacksFromCarton {
    final cCount = _parse(widget.cartonCountCtrl).toInt();
    final cCap = _parse(widget.cartonCapacityCtrl).toInt();
    if (widget.hasCarton && cCount > 0 && cCap > 0) {
      return cCount * cCap;
    }
    return null;
  }

  int? get _suggestedPiecesFromTiers {
    final cCount = _parse(widget.cartonCountCtrl).toInt();
    final cCap = _parse(widget.cartonCapacityCtrl).toInt();
    final pCount = _parse(widget.packCountCtrl).toInt();
    final pCap = _parse(widget.packCapacityCtrl).toInt();

    int total = 0;
    if (widget.hasCarton && cCount > 0 && cCap > 0) {
      final multiplier = widget.hasPack && pCap > 0 ? (cCap * pCap) : cCap;
      total += (cCount * multiplier);
    }
    if (widget.hasPack && pCount > 0 && pCap > 0) {
      total += (pCount * pCap);
    }
    return total > 0 ? total : null;
  }

  Widget _buildSuggestionBadge({
    required String label,
    required double? suggestedVal,
    required TextEditingController targetCtrl,
  }) {
    if (suggestedVal == null || suggestedVal <= 0) return const SizedBox.shrink();
    final currentVal = _parse(targetCtrl);
    final isAlreadySame = (currentVal - suggestedVal).abs() < 0.01;

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 2),
      child: InkWell(
        onTap: () {
          final str = suggestedVal.toStringAsFixed(2);
          final clean = str.endsWith('.00') ? str.substring(0, str.length - 3) : str;
          targetCtrl.text = clean;
          _onInputsChanged();
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
          decoration: BoxDecoration(
            color: isAlreadySame ? Colors.grey.shade100 : Colors.amber.shade50,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isAlreadySame ? Colors.grey.shade300 : Colors.amber.shade400,
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isAlreadySame ? Icons.check_circle_outline : Icons.lightbulb_outline_rounded,
                size: 13,
                color: isAlreadySame ? Colors.grey.shade600 : Colors.amber.shade900,
              ),
              const SizedBox(width: 4),
              Text(
                '$label: ${suggestedVal.toStringAsFixed(2)} دج',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: isAlreadySame ? Colors.grey.shade700 : Colors.amber.shade900,
                ),
              ),
              if (!isAlreadySame) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade700,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'تطبيق',
                    style: TextStyle(fontSize: 9.5, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. الكرتونة (الوحدة الكبرى)
        _buildTierCard(
          context: context,
          title: '📦 إعدادات الكرتونة (الوحدة الكبرى)',
          subtitle: isStockInMode
              ? 'تحديد عدد الكراتين المستلمة وسعة وسعر الكرتونة'
              : 'للبيع أو الاستلام بالكرتونة / الصندوق',
          color: Colors.brown.shade700,
          bgColor: Colors.brown.shade50,
          isEnabled: hasCarton,
          onToggle: onHasCartonChange,
          children: [
            if (isStockInMode && cartonCountCtrl != null) ...[
              TextField(
                controller: cartonCountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => onInputsChanged?.call(),
                decoration: const InputDecoration(
                  labelText: 'عدد الكراتين المستلمة في هذه الشحنة *',
                  suffixText: 'كرتونة',
                  prefixIcon: Icon(Icons.all_inbox_rounded),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
            ],
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: cartonCapacityCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => _onInputsChanged(),
                    decoration: InputDecoration(
                      labelText: 'سعة الكرتونة (كم حبة؟) *',
                      suffixText: 'حبة/كرتونة',
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 4,
                  child: TextField(
                    controller: cartonBarcodeCtrl,
                    decoration: InputDecoration(
                      labelText: 'باركود الكرتونة',
                      border: const OutlineInputBorder(),
                      isDense: true,
                      suffixIcon: onScanCartonBarcode != null
                          ? IconButton(
                              icon: const Icon(Icons.qr_code_scanner, size: 20),
                              onPressed: onScanCartonBarcode,
                            )
                          : null,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: cartonCostCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => _onInputsChanged(),
                    decoration: const InputDecoration(
                      labelText: 'سعر شراء الكرتونة (دج)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: cartonPriceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => _onInputsChanged(),
                    decoration: const InputDecoration(
                      labelText: 'سعر بيع الكرتونة (دج) *',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),

        // 2. العلبة (الوحدة الوسطى)
        _buildTierCard(
          context: context,
          title: '🛍️ إعدادات العلبة (الوحدة الوسطى)',
          subtitle: isStockInMode
              ? 'تحديد عدد العلب الإضافية وسعة وسعر العلبة'
              : 'للبيع أو الاستلام بالعلبة / الباكي',
          color: Colors.indigo.shade700,
          bgColor: Colors.indigo.shade50,
          isEnabled: hasPack,
          onToggle: onHasPackChange,
          children: [
            if (isStockInMode && packCountCtrl != null) ...[
              if (hasCarton && _suggestedPacksFromCarton != null && _suggestedPacksFromCarton! > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.indigo.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.auto_awesome, size: 15, color: Colors.indigo),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'المحسوب من الكراتين: $_suggestedPacksFromCarton علبة (${_parse(widget.cartonCountCtrl).toInt()} كرتونة × ${_parse(widget.cartonCapacityCtrl).toInt()})',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.indigo.shade900),
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          packCountCtrl?.text = _suggestedPacksFromCarton.toString();
                          _onInputsChanged();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.indigo.shade600,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('اعتماد كإجمالي', style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              TextField(
                controller: packCountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => onInputsChanged?.call(),
                decoration: InputDecoration(
                  labelText: hasCarton ? 'عدد العلب (إضافية منفردة أو إجمالي)' : 'عدد العلب المستلمة',
                  hintText: 'أدخل العلب الإضافية إن وجدت أو الإجمالي',
                  suffixText: 'علبة',
                  prefixIcon: const Icon(Icons.inventory_2_outlined),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
            ],
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: packCapacityCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => _onInputsChanged(),
                    decoration: const InputDecoration(
                      labelText: 'سعة العلبة (كم حبة؟) *',
                      suffixText: 'حبة/علبة',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 4,
                  child: TextField(
                    controller: packBarcodeCtrl,
                    decoration: InputDecoration(
                      labelText: 'باركود العلبة',
                      border: const OutlineInputBorder(),
                      isDense: true,
                      suffixIcon: onScanPackBarcode != null
                          ? IconButton(
                              icon: const Icon(Icons.qr_code_scanner, size: 20),
                              onPressed: onScanPackBarcode,
                            )
                          : null,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: packCostCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) => _onInputsChanged(),
                        decoration: InputDecoration(
                          labelText: 'سعر شراء العلبة (دج)',
                          border: const OutlineInputBorder(),
                          isDense: true,
                          hintText: _suggestedPackCost != null && packCostCtrl.text.isEmpty
                              ? 'اقتراح: ${_suggestedPackCost!.toStringAsFixed(2)}'
                              : null,
                        ),
                      ),
                      _buildSuggestionBadge(
                        label: 'اقتراح التكلفة',
                        suggestedVal: _suggestedPackCost,
                        targetCtrl: packCostCtrl,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: packPriceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) => _onInputsChanged(),
                        decoration: InputDecoration(
                          labelText: 'سعر بيع العلبة (دج) *',
                          border: const OutlineInputBorder(),
                          isDense: true,
                          hintText: _suggestedPackPrice != null && packPriceCtrl.text.isEmpty
                              ? 'اقتراح: ${_suggestedPackPrice!.toStringAsFixed(2)}'
                              : null,
                        ),
                      ),
                      _buildSuggestionBadge(
                        label: 'اقتراح البيع',
                        suggestedVal: _suggestedPackPrice,
                        targetCtrl: packPriceCtrl,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),

        // 3. الحبة (الوحدة الأساسية)
        _buildBaseTierCard(
          context: context,
          children: [
            if (isStockInMode && pieceCountCtrl != null) ...[
              if (_suggestedPiecesFromTiers != null && _suggestedPiecesFromTiers! > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade300),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.auto_awesome, size: 15, color: Colors.green),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'المحسوب من العلب والكراتين: $_suggestedPiecesFromTiers حبة',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.green.shade900),
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          pieceCountCtrl?.text = _suggestedPiecesFromTiers.toString();
                          _onInputsChanged();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.green.shade700,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('اعتماد كإجمالي', style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              TextField(
                controller: pieceCountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => onInputsChanged?.call(),
                decoration: InputDecoration(
                  labelText: (hasCarton || hasPack) ? 'عدد الحبات (فردية إضافية أو إجمالي)' : 'عدد الحبات المستلمة',
                  hintText: 'أدخل الحبات الإضافية إن وجدت أو الإجمالي',
                  suffixText: 'حبة',
                  prefixIcon: const Icon(Icons.tag),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
            ],
            Row(
              children: [
                if (baseUnitNameCtrl != null) ...[
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: baseUnitNameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'اسم الوحدة الأساسية',
                        hintText: 'حبة، قطعة...',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  flex: 4,
                  child: TextField(
                    controller: pieceBarcodeCtrl,
                    decoration: InputDecoration(
                      labelText: 'باركود الحبة (الأساسي) *',
                      border: const OutlineInputBorder(),
                      isDense: true,
                      suffixIcon: onScanPieceBarcode != null
                          ? IconButton(
                              icon: const Icon(Icons.qr_code_scanner, size: 20),
                              onPressed: onScanPieceBarcode,
                            )
                          : null,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: pieceCostCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) => _onInputsChanged(),
                        decoration: InputDecoration(
                          labelText: 'سعر شراء الحبة (دج)',
                          border: const OutlineInputBorder(),
                          isDense: true,
                          hintText: _suggestedPieceCost != null && pieceCostCtrl.text.isEmpty
                              ? 'اقتراح: ${_suggestedPieceCost!.toStringAsFixed(2)}'
                              : null,
                        ),
                      ),
                      _buildSuggestionBadge(
                        label: 'اقتراح التكلفة',
                        suggestedVal: _suggestedPieceCost,
                        targetCtrl: pieceCostCtrl,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: piecePriceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) => _onInputsChanged(),
                        decoration: InputDecoration(
                          labelText: 'سعر بيع الحبة (دج) *',
                          border: const OutlineInputBorder(),
                          isDense: true,
                          hintText: _suggestedPiecePrice != null && piecePriceCtrl.text.isEmpty
                              ? 'اقتراح: ${_suggestedPiecePrice!.toStringAsFixed(2)}'
                              : null,
                        ),
                      ),
                      _buildSuggestionBadge(
                        label: 'اقتراح البيع',
                        suggestedVal: _suggestedPiecePrice,
                        targetCtrl: piecePriceCtrl,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),

        // 4. العروض الخاصة والتخفيضات الذكية
        _buildSpecialOfferCard(context),

        // 5. ملخص إجمالي الاستلام في حالة Stock In
        if (isStockInMode) ...[
          const SizedBox(height: 14),
          _buildStockInSummaryCard(),
        ],
      ],
    );
  }

  Widget _buildTierCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required Color color,
    required Color bgColor,
    required bool isEnabled,
    required ValueChanged<bool> onToggle,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isEnabled ? bgColor : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isEnabled ? color.withOpacity(0.4) : Colors.grey.shade300,
          width: 1.2,
        ),
      ),
      child: Column(
        children: [
          ListTile(
            title: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isEnabled ? color : Colors.grey.shade700,
              ),
            ),
            subtitle: Text(
              subtitle,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
            trailing: Switch(
              value: isEnabled,
              activeColor: color,
              onChanged: onToggle,
            ),
          ),
          if (isEnabled)
            Padding(
              padding: const EdgeInsets.only(left: 14, right: 14, bottom: 14),
              child: Column(children: children),
            ),
        ],
      ),
    );
  }

  Widget _buildBaseTierCard({
    required BuildContext context,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.green.shade600.withOpacity(0.4),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '🍬 إعدادات الحبة (الوحدة الأساسية)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.green.shade800,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'أساسي ومطلوب',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'الوحدة التي يُحسب عليها المخزون والبيع الفردي',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSpecialOfferCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: hasSpecialOffer ? Colors.amber.shade50 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasSpecialOffer ? Colors.amber.shade700 : Colors.grey.shade300,
          width: 1.4,
        ),
      ),
      child: Column(
        children: [
          ListTile(
            leading: Icon(
              Icons.local_offer_rounded,
              color: hasSpecialOffer ? Colors.amber.shade800 : Colors.grey,
            ),
            title: Text(
              '🎁 العروض الخاصة والتخفيض الذكي',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: hasSpecialOffer ? Colors.amber.shade900 : Colors.grey.shade700,
              ),
            ),
            subtitle: Text(
              'تحديد كميات محددة بأسعار مخفضة (مثلاً: 3 حبات بـ 100 دج أو 10 حبات بـ 300 دج)',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
            trailing: Switch(
              value: hasSpecialOffer,
              activeColor: Colors.amber.shade800,
              onChanged: (val) {
                onHasSpecialOfferChange(val);
                if (val && _offerControllers.isEmpty) {
                  _offerControllers.add(_OfferRowControllers(
                    tier: UnitTier.small,
                    quantity: 3.0,
                    price: 0.0,
                  ));
                }
                _notifyOffersChanged();
              },
            ),
          ),
          if (hasSpecialOffer)
            Padding(
              padding: const EdgeInsets.only(left: 14, right: 14, bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (int idx = 0; idx < _offerControllers.length; idx++) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.amber.shade300),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade800,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'عرض ${idx + 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              if (_offerControllers.length > 1)
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                  tooltip: 'حذف هذا العرض',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () {
                                    setState(() {
                                      final removed = _offerControllers.removeAt(idx);
                                      removed.dispose();
                                      _notifyOffersChanged();
                                    });
                                  },
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              // نافذة اختيار الوحدة (كرتونة / علبة / حبة)
                              Expanded(
                                flex: 3,
                                child: DropdownButtonFormField<UnitTier>(
                                  value: _offerControllers[idx].tier,
                                  decoration: const InputDecoration(
                                    labelText: 'وحدة العرض *',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: UnitTier.small,
                                      child: Text('🍬 حبة (منفردة)'),
                                    ),
                                    DropdownMenuItem(
                                      value: UnitTier.medium,
                                      child: Text('🛍️ علبة'),
                                    ),
                                    DropdownMenuItem(
                                      value: UnitTier.large,
                                      child: Text('📦 كرتونة'),
                                    ),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() {
                                        _offerControllers[idx].tier = val;
                                        _notifyOffersChanged();
                                      });
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              // خانة الكمية
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  controller: _offerControllers[idx].qtyCtrl,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: const InputDecoration(
                                    labelText: 'الكمية *',
                                    hintText: 'مثلاً 3',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                  onChanged: (_) => _notifyOffersChanged(),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // خانة السعر الإجمالي
                              Expanded(
                                flex: 3,
                                child: TextField(
                                  controller: _offerControllers[idx].priceCtrl,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: const InputDecoration(
                                    labelText: 'سعر العرض (دج) *',
                                    hintText: 'مثلاً 100',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                  onChanged: (_) => _notifyOffersChanged(),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.amber.shade900,
                      side: BorderSide(color: Colors.amber.shade700),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.add_circle_outline, size: 18),
                    label: const Text(
                      '+ إضافة عرض ترويجي آخر لهذا المنتج',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    onPressed: () {
                      setState(() {
                        _offerControllers.add(_OfferRowControllers(
                          tier: UnitTier.small,
                          quantity: 0,
                          price: 0,
                        ));
                      });
                      _notifyOffersChanged();
                    },
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, size: 16, color: Colors.brown),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'يمكنك تحديد عرض واحد أو أكثر (مثلاً: 3 بـ 100 دج و 10 بـ 300 دج). في الكاشير تظهر العروض للاختيار المباشر أو تُطبق تلقائياً.',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.brown.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStockInSummaryCard() {
    final cCount = _parse(widget.cartonCountCtrl).toInt();
    final cCap = _parse(widget.cartonCapacityCtrl).toInt();
    final pCount = _parse(widget.packCountCtrl).toInt();
    final pCap = _parse(widget.packCapacityCtrl).toInt();
    final piCount = _parse(widget.pieceCountCtrl).toInt();

    final cCost = _parse(widget.cartonCostCtrl);
    final pCost = _parse(widget.packCostCtrl);
    final piCost = _parse(widget.pieceCostCtrl);

    final cPrice = _parse(widget.cartonPriceCtrl);
    final pPrice = _parse(widget.packPriceCtrl);
    final piPrice = _parse(widget.piecePriceCtrl);

    final cartonMultiplier = widget.hasPack ? (cCap * pCap) : cCap;
    final totalPieces = (widget.hasCarton ? (cCount * cartonMultiplier) : 0)
                      + (widget.hasPack ? (pCount * pCap) : 0)
                      + piCount;

    final totalCost = (widget.hasCarton ? (cCount * cCost) : 0)
                    + (widget.hasPack ? (pCount * pCost) : 0)
                    + (piCount * piCost);

    final totalRevenue = (widget.hasCarton ? (cCount * cPrice) : 0)
                       + (widget.hasPack ? (pCount * pPrice) : 0)
                       + (piCount * piPrice);

    final totalProfit = totalRevenue - totalCost;
    final marginPct = totalCost > 0 ? ((totalProfit / totalCost) * 100) : 0.0;
    final hasProfitData = totalCost > 0 && totalRevenue > 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.teal.shade300, width: 1.3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.inventory_rounded, color: Colors.teal.shade800, size: 26),
              const SizedBox(width: 8),
              Text(
                'ملخص الاستلام والأرباح التقديرية',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('إجمالي الحبات المضافة:', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                    Text('$totalPieces حبة', style: TextStyle(fontSize: 18, color: Colors.teal.shade900, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('إجمالي تكلفة الشراء:', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                    Text('${totalCost.toStringAsFixed(2)} د.ج', style: TextStyle(fontSize: 16, color: Colors.red.shade800, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          if (hasProfitData) ...[
            const Divider(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('إجمالي المبيعات المتوقعة:', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                      Text('${totalRevenue.toStringAsFixed(2)} د.ج', style: TextStyle(fontSize: 15, color: Colors.indigo.shade900, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('صافي الأرباح المتوقعة:', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                      Text(
                        '${totalProfit >= 0 ? "+" : ""}${totalProfit.toStringAsFixed(2)} د.ج (${marginPct.toStringAsFixed(1)}%)',
                        style: TextStyle(
                          fontSize: 15,
                          color: totalProfit >= 0 ? Colors.green.shade800 : Colors.red.shade800,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
