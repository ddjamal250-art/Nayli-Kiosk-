import 'package:flutter/material.dart';
import '../../../../core/utils/sound_service.dart';

class AlgerianDenominationDialog extends StatefulWidget {
  final double initialTotal;
  final String title;

  const AlgerianDenominationDialog({
    super.key,
    this.initialTotal = 0.0,
    this.title = 'حاسبة الفئات النقدية الجزائرية 🇩🇿 (Fond & Caisse)',
  });

  static Future<double?> show(BuildContext context, {double initialTotal = 0.0, String? title}) {
    return showDialog<double>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlgerianDenominationDialog(
        initialTotal: initialTotal,
        title: title ?? 'حاسبة الفئات النقدية الجزائرية 🇩🇿 (Fond & Caisse)',
      ),
    );
  }

  @override
  State<AlgerianDenominationDialog> createState() => _AlgerianDenominationDialogState();
}

class _AlgerianDenominationDialogState extends State<AlgerianDenominationDialog> {
  // Algerian Denominations Map: Face value -> Count
  final Map<int, int> _counts = {
    2000: 0,
    1000: 0,
    500: 0,
    200: 0,
    100: 0,
    50: 0,
    20: 0,
    10: 0,
  };

  double get _total {
    double sum = 0.0;
    _counts.forEach((denom, count) {
      sum += denom * count;
    });
    return sum;
  }

  void _increment(int denom, int delta) {
    setState(() {
      final current = _counts[denom] ?? 0;
      final next = current + delta;
      _counts[denom] = next < 0 ? 0 : next;
    });
    SoundService.playKeyTap();
  }

  void _setCount(int denom, String val) {
    setState(() {
      _counts[denom] = int.tryParse(val) ?? 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.teal.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.payments_rounded, color: Colors.teal, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const Text('أدخل عدد الأوراق والقطع النقدية لعد الصندوق بدقة ومنع أخطاء الأصفار',
                    style: TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Total Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.teal.shade700,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: Colors.teal.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('المجموع الكلي المحسوب:',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                  Text('${_total.toStringAsFixed(2)} دج',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Denominations List
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 380),
              child: ListView(
                shrinkWrap: true,
                children: [
                  _buildDenomRow(2000, 'ورقة 2000 دج 💵', Colors.teal),
                  _buildDenomRow(1000, 'ورقة 1000 دج 💵', Colors.blue),
                  _buildDenomRow(500, 'ورقة 500 دج 💵', Colors.indigo),
                  _buildDenomRow(200, 'قطعة 200 دج 🪙', Colors.amber.shade800),
                  _buildDenomRow(100, 'قطعة 100 دج 🪙', Colors.orange),
                  _buildDenomRow(50, 'قطعة 50 دج 🪙', Colors.brown),
                  _buildDenomRow(20, 'قطعة 20 دج 🪙', Colors.grey.shade700),
                  _buildDenomRow(10, 'قطعة 10 دج 🪙', Colors.blueGrey),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          icon: const Icon(Icons.check_circle_rounded, color: Colors.white),
          label: Text('تأكيد المبلغ (${_total.toStringAsFixed(0)} دج)',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          onPressed: () {
            SoundService.playSaveSuccess();
            Navigator.pop(context, _total);
          },
        ),
      ],
    );
  }

  Widget _buildDenomRow(int denom, String label, Color color) {
    final count = _counts[denom] ?? 0;
    final subtotal = denom * count;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 140,
              child: Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
            ),
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, size: 20),
              color: Colors.red,
              onPressed: () => _increment(denom, -1),
            ),
            Container(
              width: 50,
              alignment: Alignment.center,
              child: Text('$count', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline, size: 20),
              color: Colors.green,
              onPressed: () => _increment(denom, 1),
            ),
            const SizedBox(width: 4),
            ActionChip(
              label: const Text('+5', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
              padding: EdgeInsets.zero,
              onPressed: () => _increment(denom, 5),
            ),
            const SizedBox(width: 4),
            ActionChip(
              label: const Text('+10', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
              padding: EdgeInsets.zero,
              onPressed: () => _increment(denom, 10),
            ),
            const Spacer(),
            Text('${subtotal.toStringAsFixed(0)} دج',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5)),
          ],
        ),
      ),
    );
  }
}
