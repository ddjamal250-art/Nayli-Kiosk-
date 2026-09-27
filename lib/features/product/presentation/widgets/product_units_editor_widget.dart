import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/product_unit.dart';
import '../../domain/entities/special_offer.dart';

/// ويدجت موحد يجمع طبقات الوحدات الثلاث (كرتونة -> علبة -> حبة) والعروض الخاصة
/// معروضة عمودياً تحت بعضها البعض بشكل مرن يغطي جميع حالات البيع والاستلام في الواقع
class ProductUnitsEditorWidget extends StatelessWidget {
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
  });

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
                keyboardType: TextInputType.number,
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
                    keyboardType: TextInputType.number,
                    onChanged: (_) => onInputsChanged?.call(),
                    decoration: const InputDecoration(
                      labelText: 'سعة الكرتونة (كم حبة؟) *',
                      suffixText: 'حبة/كرتونة',
                      border: OutlineInputBorder(),
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
                    keyboardType: TextInputType.number,
                    onChanged: (_) => onInputsChanged?.call(),
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
                    keyboardType: TextInputType.number,
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
              TextField(
                controller: packCountCtrl,
                keyboardType: TextInputType.number,
                onChanged: (_) => onInputsChanged?.call(),
                decoration: const InputDecoration(
                  labelText: 'عدد العلب المستلمة (خارج الكراتين)',
                  suffixText: 'علبة',
                  prefixIcon: Icon(Icons.inventory_2_outlined),
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
                    controller: packCapacityCtrl,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => onInputsChanged?.call(),
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
              children: [
                Expanded(
                  child: TextField(
                    controller: packCostCtrl,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => onInputsChanged?.call(),
                    decoration: const InputDecoration(
                      labelText: 'سعر شراء العلبة (دج)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: packPriceCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'سعر بيع العلبة (دج) *',
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

        // 3. الحبة (الوحدة الأساسية)
        _buildBaseTierCard(
          context: context,
          children: [
            if (isStockInMode && pieceCountCtrl != null) ...[
              TextField(
                controller: pieceCountCtrl,
                keyboardType: TextInputType.number,
                onChanged: (_) => onInputsChanged?.call(),
                decoration: const InputDecoration(
                  labelText: 'عدد الحبات المستلمة (فردية منفصلة)',
                  suffixText: 'حبة',
                  prefixIcon: Icon(Icons.tag),
                  border: OutlineInputBorder(),
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
              children: [
                Expanded(
                  child: TextField(
                    controller: pieceCostCtrl,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => onInputsChanged?.call(),
                    decoration: const InputDecoration(
                      labelText: 'سعر شراء الحبة (دج)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: piecePriceCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'سعر بيع الحبة (دج) *',
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
              'تحديد كمية محددة بسعر مخفض (مثلاً: 3 حبات بـ 100 دج أو كرتونتين بـ 4500 دج)',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
            trailing: Switch(
              value: hasSpecialOffer,
              activeColor: Colors.amber.shade800,
              onChanged: onHasSpecialOfferChange,
            ),
          ),
          if (hasSpecialOffer)
            Padding(
              padding: const EdgeInsets.only(left: 14, right: 14, bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // نافذة اختيار الوحدة (كرتونة / علبة / حبة)
                      Expanded(
                        flex: 3,
                        child: DropdownButtonFormField<UnitTier>(
                          value: offerTier,
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
                          onChanged: onOfferTierChange,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // خانة الكمية
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: offerQtyCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'الكمية *',
                            hintText: 'مثلاً 3',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // خانة السعر الإجمالي
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: offerPriceCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'سعر العرض (دج) *',
                            hintText: 'مثلاً 100',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
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
                            'عند البيع أو الإرجاع: إذا وصلت الكمية إلى مضاعفات العرض تُحسب بسعر العرض أوتوماتيكياً.',
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
    final cCount = int.tryParse(cartonCountCtrl?.text.trim() ?? '0') ?? 0;
    final cCap = int.tryParse(cartonCapacityCtrl.text.trim()) ?? 1;
    final pCount = int.tryParse(packCountCtrl?.text.trim() ?? '0') ?? 0;
    final pCap = int.tryParse(packCapacityCtrl.text.trim()) ?? 1;
    final piCount = int.tryParse(pieceCountCtrl?.text.trim() ?? '0') ?? 0;

    final totalPieces = (hasCarton ? (cCount * cCap) : 0)
                      + (hasPack ? (pCount * pCap) : 0)
                      + piCount;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.teal.shade300, width: 1.3),
      ),
      child: Row(
        children: [
          Icon(Icons.inventory_rounded, color: Colors.teal.shade800, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'إجمالي الكمية المستلمة التي ستدخل المخزون:',
                  style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold),
                ),
                Text(
                  '$totalPieces حبة / قطعة',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal.shade900,
                  ),
                ),
                Text(
                  'التفصيل: ${hasCarton ? '$cCount كرتونة (×$cCap) ' : ''}'
                  '${hasPack ? '+ $pCount علبة (×$pCap) ' : ''}'
                  '${piCount > 0 ? '+ $piCount حبة' : ''}',
                  style: TextStyle(fontSize: 11, color: Colors.teal.shade800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
