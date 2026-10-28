import 'dart:io';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:printing/printing.dart';

import '../../../../core/data/hive_database.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/utils/printer_helper.dart';
import '../../../../core/utils/security_pin_helper.dart';
import '../../../../core/utils/snackbar_helper.dart';
import '../../../../core/utils/sound_service.dart';
import '../../../../core/utils/tpe_payment_service.dart';
import '../bloc/billing_bloc.dart';
import 'printer_selection_dialog.dart';

class PosPaymentModal {
  static void show({
    required BuildContext context,
    required BillingState state,
    required double cartDiscountValue,
    required bool isDiscountPercentage,
    required String? selectedCustomerId,
    required String selectedCustomerName,
    required double customerCreditBalance,
    required Future<void> Function(
      PosPaymentMethod method,
      double total,
      String tpeRef, {
      bool printReceipt,
      double? receivedAmount,
      List<Map<String, dynamic>>? splitPayments,
      String? orderNote,
    }) onFinalizeSale,
    required void Function(double total, BillingState state) onSendWhatsAppReceipt,
  }) {
    SoundService.playTabSwitch();
    PosPaymentMethod paymentMethod = PosPaymentMethod.cash;

    final bool isReturnMode = state.isRefund || state.totalAmount < 0;

    // Calculate final total after discount
    double calculatedTotal = cartDiscountValue > 0 ? state.subTotalAmount : state.totalAmount;
    if (cartDiscountValue > 0) {
      if (isDiscountPercentage) {
        calculatedTotal = isReturnMode 
            ? (calculatedTotal + (calculatedTotal.abs() * (cartDiscountValue / 100))) 
            : (calculatedTotal - (calculatedTotal * (cartDiscountValue / 100)));
      } else {
        calculatedTotal = isReturnMode
            ? (calculatedTotal + cartDiscountValue.abs())
            : (calculatedTotal - cartDiscountValue).clamp(0.0, double.infinity);
      }
    }

    final double displayTotal = isReturnMode ? calculatedTotal.abs() : calculatedTotal;
    double receivedAmount = displayTotal;
    final manualTpeRefController = TextEditingController();
    final cashSplitController = TextEditingController();
    final cardSplitController = TextEditingController();
    final baridiSplitController = TextEditingController();
    final creditSplitController = TextEditingController();
    final orderNoteController = TextEditingController();
    bool shouldPrintReceipt = (HiveDatabase.settingsBox.get('pos_auto_print_receipt', defaultValue: false) as bool) &&
        PrinterHelper.defaultThermalPrinter.isNotEmpty;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final total = displayTotal;
          final change = isReturnMode ? 0.0 : (receivedAmount - total).clamp(0.0, 999999.0);

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(
                  isReturnMode ? Icons.assignment_return_rounded : Icons.point_of_sale_rounded,
                  color: isReturnMode ? Colors.deepOrange : Colors.teal,
                  size: 30,
                ),
                const SizedBox(width: 8),
                Text(
                  isReturnMode ? 'استرجاع سلع وصرف نقدي للزبون 🔄' : context.tr('btn_pay_checkout'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            content: SizedBox(
              width: 580,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Total Box
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                    decoration: BoxDecoration(
                      color: isReturnMode ? Colors.deepOrange.shade50 : Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isReturnMode ? Colors.deepOrange.shade300 : Colors.teal.shade200,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isReturnMode ? 'المبلغ المستحق إرجاعه للزبون (صرف من الصندوق):' : context.tr('cart_net_total'),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: isReturnMode ? Colors.deepOrange.shade900 : Colors.black87,
                              ),
                            ),
                            if (cartDiscountValue > 0)
                              Text('${context.tr("discount")}: ${cartDiscountValue.toStringAsFixed(1)}${isDiscountPercentage ? "%" : " DA"}',
                                  style: const TextStyle(fontSize: 12, color: Colors.purple, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Text(
                          '${isReturnMode ? "- " : ""}${total.toStringAsFixed(2)} DA',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: isReturnMode ? Colors.deepOrange.shade800 : Colors.teal,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Payment Method Selector
                  Text(context.tr('payment_mode'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: PosPaymentMethod.values.map((method) {
                      final isSelected = paymentMethod == method;
                      return ChoiceChip(
                        selected: isSelected,
                        label: Text('${method.icon} ${method.title(context)}'),
                        selectedColor: Colors.teal,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        onSelected: (val) {
                          if (val) {
                            setModalState(() {
                              paymentMethod = method;
                            });
                            SoundService.playTabSwitch();
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Dynamic Content based on method
                  if (paymentMethod == PosPaymentMethod.cash) ...[
                    if (isReturnMode) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.amber.shade400, width: 1.2),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, color: Colors.orange, size: 26),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'سيتم فتح درج النقود (Tiroir Caisse) تلقائياً لصرف مبلغ ${displayTotal.toStringAsFixed(2)} دج نقداً للزبون وخصمه من رصيد الصندوق والوردية.',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              autofocus: true,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: context.tr('paid_amount'),
                                border: const OutlineInputBorder(),
                                prefixIcon: const Icon(Icons.money),
                              ),
                              onChanged: (val) {
                                final numVal = double.tryParse(val) ?? 0.0;
                                setModalState(() {
                                  receivedAmount = numVal;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(context.tr('change_due'), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                Text('${change.toStringAsFixed(2)} DA',
                                    style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: change >= 0 ? Colors.green : Colors.red)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Quick Bill Buttons
                      Row(
                        children: [500, 1000, 2000, 5000].map((bill) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ActionChip(
                              label: Text('+$bill DA'),
                              onPressed: () {
                                setModalState(() {
                                  receivedAmount = bill.toDouble();
                                });
                                SoundService.playTabSwitch();
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ] else if (paymentMethod == PosPaymentMethod.tpeCard) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.credit_card_rounded, color: Colors.blueAccent),
                              SizedBox(width: 8),
                              Text('TPE (CIB / Edahabia)', style: TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: manualTpeRefController,
                            decoration: const InputDecoration(
                              labelText: 'SATIM Ref / Ticket Code',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else if (paymentMethod == PosPaymentMethod.baridiPayQr) ...[
                    Center(
                      child: Column(
                        children: [
                          QrImageView(
                            data: TpePaymentService.generateBaridiPayQrPayload(
                              amount: total,
                              invoiceNumber: 'INV-${DateTime.now().millisecondsSinceEpoch}',
                            ),
                            version: QrVersions.auto,
                            size: 160.0,
                          ),
                          const SizedBox(height: 8),
                          const Text('BaridiMob (BaridiPay QR)',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
                        ],
                      ),
                    ),
                  ] else if (paymentMethod == PosPaymentMethod.customerCredit) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.shade300),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.account_balance_wallet_rounded, color: Colors.amber),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${context.tr("remaining_to_credit")} ${total.toStringAsFixed(2)} DA ($selectedCustomerName)',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else if (paymentMethod == PosPaymentMethod.split) ...[
                    Builder(
                      builder: (context) {
                        final double cashVal = double.tryParse(cashSplitController.text) ?? 0.0;
                        final double cardVal = double.tryParse(cardSplitController.text) ?? 0.0;
                        final double baridiVal = double.tryParse(baridiSplitController.text) ?? 0.0;
                        final double creditVal = double.tryParse(creditSplitController.text) ?? 0.0;
                        final double allocated = cashVal + cardVal + baridiVal + creditVal;
                        final double remaining = total - allocated;

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.purple.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.purple.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('توزيع مبالغ الدفع المجزأ:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: remaining.abs() < 0.01
                                          ? Colors.green.shade100
                                          : (remaining > 0 ? Colors.red.shade100 : Colors.orange.shade100),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      remaining.abs() < 0.01
                                          ? '✅ المجموع مكتمل تماماً'
                                          : (remaining > 0
                                              ? 'متبقي: ${remaining.toStringAsFixed(2)} DA'
                                              : 'زيادة: ${(-remaining).toStringAsFixed(2)} DA'),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: remaining.abs() < 0.01
                                            ? Colors.green.shade900
                                            : (remaining > 0 ? Colors.red.shade900 : Colors.orange.shade900),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),

                              // Quick Fill Buttons
                              if (remaining > 0)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: [
                                      ActionChip(
                                        avatar: const Text('💵'),
                                        label: Text('+ الباقي كاش (${remaining.toStringAsFixed(0)} DA)', style: const TextStyle(fontSize: 11)),
                                        onPressed: () {
                                          setModalState(() {
                                            cashSplitController.text = (cashVal + remaining).toStringAsFixed(2);
                                          });
                                          SoundService.playTabSwitch();
                                        },
                                      ),
                                      ActionChip(
                                        avatar: const Text('💳'),
                                        label: Text('+ الباقي TPE (${remaining.toStringAsFixed(0)} DA)', style: const TextStyle(fontSize: 11)),
                                        onPressed: () {
                                          setModalState(() {
                                            cardSplitController.text = (cardVal + remaining).toStringAsFixed(2);
                                          });
                                          SoundService.playTabSwitch();
                                        },
                                      ),
                                      ActionChip(
                                        avatar: const Text('📱'),
                                        label: Text('+ الباقي بريدي (${remaining.toStringAsFixed(0)} DA)', style: const TextStyle(fontSize: 11)),
                                        onPressed: () {
                                          setModalState(() {
                                            baridiSplitController.text = (baridiVal + remaining).toStringAsFixed(2);
                                          });
                                          SoundService.playTabSwitch();
                                        },
                                      ),
                                      if (selectedCustomerId != null)
                                        ActionChip(
                                          avatar: const Text('📒'),
                                          label: Text('+ الباقي كريدي (${remaining.toStringAsFixed(0)} DA)', style: const TextStyle(fontSize: 11)),
                                          onPressed: () {
                                            setModalState(() {
                                              creditSplitController.text = (creditVal + remaining).toStringAsFixed(2);
                                            });
                                            SoundService.playTabSwitch();
                                          },
                                        ),
                                    ],
                                  ),
                                ),

                              // Row 1: Cash & TPE Card
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: cashSplitController,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      decoration: const InputDecoration(
                                        prefixText: '💵 ',
                                        labelText: 'نقداً (كاش)',
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                      ),
                                      onChanged: (_) => setModalState(() {}),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextField(
                                      controller: cardSplitController,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      decoration: const InputDecoration(
                                        prefixText: '💳 ',
                                        labelText: 'بطاقة (TPE)',
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                      ),
                                      onChanged: (_) => setModalState(() {}),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              // Row 2: BaridiPay & Credit
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: baridiSplitController,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      decoration: const InputDecoration(
                                        prefixText: '📱 ',
                                        labelText: 'بريدي موب (BaridiMob)',
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                      ),
                                      onChanged: (_) => setModalState(() {}),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextField(
                                      controller: creditSplitController,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      enabled: selectedCustomerId != null,
                                      decoration: InputDecoration(
                                        prefixText: '📒 ',
                                        labelText: selectedCustomerId != null ? 'كريدي ($selectedCustomerName)' : 'كريدي (اختر زبوناً)',
                                        border: const OutlineInputBorder(),
                                        isDense: true,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                      ),
                                      onChanged: (_) => setModalState(() {}),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                  const SizedBox(height: 10),

                  // Optional Order / Invoice Note
                  TextField(
                    controller: orderNoteController,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.note_alt_outlined, size: 18),
                      labelText: 'ملاحظة الفاتورة / الطلب (اختياري)',
                      hintText: 'مثال: طاولة رقم 4، توصيل، طلب خاص...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Printer Selection & Auto-Print Toggle Bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: shouldPrintReceipt
                            ? (PrinterHelper.defaultThermalPrinter.isNotEmpty ? Colors.teal.shade300 : Colors.deepOrange.shade300)
                            : Colors.grey.shade300,
                      ),
                    ),
                    child: Row(
                      children: [
                        Checkbox(
                          value: shouldPrintReceipt,
                          activeColor: Colors.teal,
                          onChanged: (val) {
                            setModalState(() {
                              shouldPrintReceipt = val ?? true;
                              HiveDatabase.settingsBox.put('pos_auto_print_receipt', shouldPrintReceipt);
                            });
                          },
                        ),
                        Icon(
                          Icons.print_rounded,
                          size: 20,
                          color: shouldPrintReceipt
                              ? (PrinterHelper.defaultThermalPrinter.isNotEmpty ? Colors.teal : Colors.deepOrange)
                              : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(context.tr('receipt_print_title'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              Text(
                                !shouldPrintReceipt
                                    ? context.tr('paper_print_disabled')
                                    : (PrinterHelper.defaultThermalPrinter.isNotEmpty
                                        ? '${context.tr("printer")}: ${PrinterHelper.defaultThermalPrinter}'
                                        : context.tr('no_printer_selected_warning')),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: !shouldPrintReceipt
                                      ? Colors.grey
                                      : (PrinterHelper.defaultThermalPrinter.isNotEmpty ? Colors.teal.shade800 : Colors.red),
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        if (shouldPrintReceipt)
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            icon: const Icon(Icons.tune_rounded, size: 14),
                            label: Text(context.tr('change_printer'), style: const TextStyle(fontSize: 11)),
                            onPressed: () async {
                              final chosen = await PrinterSelectionDialog.show(context, targetRole: PrinterRole.thermalReceipt);
                              if (chosen != null) {
                                setModalState(() {});
                              }
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.tr('cancel'))),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.green.shade800,
                  side: BorderSide(color: Colors.green.shade600),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                icon: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.green, size: 18),
                label: Text('${context.tr("whatsapp")} 💬', style: const TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () => onSendWhatsAppReceipt(total, state),
              ),
              if (!isReturnMode)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.teal.shade800,
                    side: BorderSide(color: Colors.teal.shade600, width: 1.5),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.bolt_rounded, size: 20),
                  label: const Text(
                    'حفظ بدون طباعة ⚡',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  onPressed: () async {
                    if (paymentMethod == PosPaymentMethod.customerCredit && selectedCustomerId != null) {
                      final cData = HiveDatabase.customersBox.get(selectedCustomerId);
                      double maxLimit = 50000.0;
                      if (cData is Map) {
                        maxLimit = (cData['maxDebtLimit'] as num?)?.toDouble() ?? 50000.0;
                      }
                      final projectedDebt = customerCreditBalance + total;
                      if (projectedDebt > maxLimit) {
                        final authorized = await SecurityPinHelper.authenticate(
                          context,
                          title: '${context.tr("debt_limit_exceeded")} (${maxLimit.toStringAsFixed(0)} DA)',
                        );
                        if (!authorized) {
                          SnackbarHelper.showError(context, '❌ ' + context.tr('sale_cancelled_debt_refused'));
                          return;
                        }
                      }
                    }

                    List<Map<String, dynamic>>? splitList;
                    if (paymentMethod == PosPaymentMethod.split) {
                      final double cashVal = double.tryParse(cashSplitController.text) ?? 0.0;
                      final double cardVal = double.tryParse(cardSplitController.text) ?? 0.0;
                      final double baridiVal = double.tryParse(baridiSplitController.text) ?? 0.0;
                      final double creditVal = double.tryParse(creditSplitController.text) ?? 0.0;
                      final double allocated = cashVal + cardVal + baridiVal + creditVal;
                      if ((total - allocated).abs() > 0.05) {
                        SnackbarHelper.showError(context, '❌ يجب أن يعادل مجموع أجزاء الدفع الإجمالي تماماً (${total.toStringAsFixed(2)} DA)');
                        return;
                      }
                      splitList = [
                        if (cashVal > 0) {'method': 'Espèces', 'amount': cashVal},
                        if (cardVal > 0) {'method': 'TPE / Carte', 'amount': cardVal},
                        if (baridiVal > 0) {'method': 'BaridiPay QR', 'amount': baridiVal},
                        if (creditVal > 0) {'method': 'Crédit', 'amount': creditVal},
                      ];
                    }

                    final noteText = orderNoteController.text.trim();
                    final double effectiveReceived = isReturnMode
                        ? -total
                        : (paymentMethod == PosPaymentMethod.customerCredit
                            ? 0.0
                            : (paymentMethod == PosPaymentMethod.cash ? receivedAmount : total));

                    Navigator.pop(ctx);
                    await onFinalizeSale(
                      paymentMethod,
                      isReturnMode ? -total : total,
                      manualTpeRefController.text,
                      printReceipt: false,
                      receivedAmount: effectiveReceived,
                      splitPayments: splitList,
                      orderNote: noteText.isNotEmpty ? noteText : null,
                    );
                  },
                ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isReturnMode ? Colors.deepOrange.shade700 : Colors.teal.shade700,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: Icon(
                  isReturnMode
                      ? Icons.assignment_return_rounded
                      : (shouldPrintReceipt ? Icons.print_rounded : Icons.check_circle_outline),
                  color: Colors.white,
                ),
                label: Text(
                  isReturnMode
                      ? 'تأكيد الإرجاع وصرف ${total.toStringAsFixed(2)} دج للزبون ↩️'
                      : (shouldPrintReceipt ? context.tr('confirm_and_print') : context.tr('confirm_and_save_sale')),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                onPressed: () async {
                  if (paymentMethod == PosPaymentMethod.customerCredit && selectedCustomerId != null) {
                    final cData = HiveDatabase.customersBox.get(selectedCustomerId);
                    double maxLimit = 50000.0;
                    if (cData is Map) {
                      maxLimit = (cData['maxDebtLimit'] as num?)?.toDouble() ?? 50000.0;
                    }
                    final projectedDebt = customerCreditBalance + total;
                    if (projectedDebt > maxLimit) {
                      final authorized = await SecurityPinHelper.authenticate(
                        context,
                        title: '${context.tr("debt_limit_exceeded")} (${maxLimit.toStringAsFixed(0)} DA)',
                      );
                      if (!authorized) {
                        SnackbarHelper.showError(context, '❌ ' + context.tr('sale_cancelled_debt_refused'));
                        return;
                      }
                    }
                  }

                  if (shouldPrintReceipt && Platform.isWindows && PrinterHelper.defaultThermalPrinter.isEmpty) {
                    final printers = await Printing.listPrinters();
                    final detected = PrinterHelper.findBestThermalPrinter(printers);
                    if (detected == null) {
                      final chosen = await PrinterSelectionDialog.show(context, targetRole: PrinterRole.thermalReceipt);
                      if (chosen == null) {
                        shouldPrintReceipt = false;
                      }
                    }
                  }

                  List<Map<String, dynamic>>? splitList;
                  if (paymentMethod == PosPaymentMethod.split) {
                    final double cashVal = double.tryParse(cashSplitController.text) ?? 0.0;
                    final double cardVal = double.tryParse(cardSplitController.text) ?? 0.0;
                    final double baridiVal = double.tryParse(baridiSplitController.text) ?? 0.0;
                    final double creditVal = double.tryParse(creditSplitController.text) ?? 0.0;
                    final double allocated = cashVal + cardVal + baridiVal + creditVal;
                    if ((total - allocated).abs() > 0.05) {
                      SnackbarHelper.showError(context, '❌ يجب أن يعادل مجموع أجزاء الدفع الإجمالي تماماً (${total.toStringAsFixed(2)} DA)');
                      return;
                    }
                    splitList = [
                      if (cashVal > 0) {'method': 'Espèces', 'amount': cashVal},
                      if (cardVal > 0) {'method': 'TPE / Carte', 'amount': cardVal},
                      if (baridiVal > 0) {'method': 'BaridiPay QR', 'amount': baridiVal},
                      if (creditVal > 0) {'method': 'Crédit', 'amount': creditVal},
                    ];
                  }

                  final noteText = orderNoteController.text.trim();
                  final double effectiveReceived = isReturnMode
                        ? -total
                        : (paymentMethod == PosPaymentMethod.customerCredit
                            ? 0.0
                            : (paymentMethod == PosPaymentMethod.cash ? receivedAmount : total));

                  Navigator.pop(ctx);
                  await onFinalizeSale(
                    paymentMethod,
                    isReturnMode ? -total : total,
                    manualTpeRefController.text,
                    printReceipt: shouldPrintReceipt,
                    receivedAmount: effectiveReceived,
                    splitPayments: splitList,
                    orderNote: noteText.isNotEmpty ? noteText : null,
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

