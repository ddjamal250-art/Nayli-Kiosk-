import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_constants.dart';
import '../bloc/billing_bloc.dart';
import '../../domain/entities/held_cart.dart';

class HeldCartsModal extends StatelessWidget {
  const HeldCartsModal({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BillingBloc, BillingState>(
      builder: (context, state) {
        final activeCarts = state.activeHeldCarts;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.pause_circle_filled, color: Colors.orange, size: 24),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'السلات المعلقة المؤقتة (${activeCarts.length})',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const Text(
                          'تحذف تلقائياً بعد 20 دقيقة إذا لم يعد الزبون',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (activeCarts.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 30),
                  alignment: Alignment.center,
                  child: Column(
                    children: [
                      Icon(Icons.remove_shopping_cart_outlined, size: 40, color: Colors.grey[300]),
                      const SizedBox(height: 8),
                      const Text('لا توجد أي سلات معلقة حالياً', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: activeCarts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final cart = activeCarts[index];
                      final remainingMin = cart.remainingMinutes;

                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.orange.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.shopping_bag_outlined, color: Colors.orange, size: 18),
                                    const SizedBox(width: 6),
                                    Text(
                                      cart.label,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: remainingMin <= 5 ? Colors.red[50] : Colors.orange[50],
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: remainingMin <= 5 ? Colors.red[200]! : Colors.orange[200]!,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.timer_outlined, size: 12, color: remainingMin <= 5 ? Colors.red : Colors.orange[800]),
                                      const SizedBox(width: 4),
                                      Text(
                                        'متبقي $remainingMin د',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: remainingMin <= 5 ? Colors.red : Colors.orange[800],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${cart.itemCount} مواد (${cart.items.map((i) => i.product.name).take(2).join(', ')}...)',
                                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                                ),
                                Text(
                                  '${cart.totalAmount.toStringAsFixed(2)} ${AppConstants.currencySymbol}',
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.green),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                    ),
                                    icon: const Icon(Icons.play_arrow, size: 16, color: Colors.white),
                                    label: const Text('استرجاع السلة للكاسة', style: TextStyle(color: Colors.white, fontSize: 12)),
                                    onPressed: () {
                                      context.read<BillingBloc>().add(ResumeHeldCartEvent(cart.id));
                                      Navigator.pop(context);
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                  tooltip: 'حذف السلة',
                                  onPressed: () {
                                    context.read<BillingBloc>().add(DeleteHeldCartEvent(cart.id));
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}