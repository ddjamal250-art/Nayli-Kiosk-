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
    }) onFinalizeSale,
    required void Function(double total, BillingState state) onSendWhatsAppReceipt,
  }) {
    SoundService.playTabSwitch();
    PosPaymentMethod paymentMethod = PosPaymentMethod.cash;

    // Calculate final total after discount
    double calculatedTotal = state.totalAmount;
    if (cartDiscountValue > 0) {
      if (isDiscountPercentage) {
        calculatedTotal = calculatedTotal - (calculatedTotal * (cartDiscountValue / 100));
      } else {
        calculatedTotal = (calculatedTotal - cartDiscountValue).clamp(0.0, double.infinity);
      }
    }

    double receivedAmount = calculatedTotal;
    final manualTpeRefController = TextEditingController();
    bool shouldPrintReceipt = HiveDatabase.settingsBox.get('pos_auto_print_receipt', defaultValue: true) as bool;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final total = calculatedTotal;
          final change = (receivedAmount - total).clamp(0.0, 999999.0);

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.point_of_sale_rounded, color: Colors.teal, size: 30),
                const SizedBox(width: 8),
                Text(context.tr('btn_pay_checkout'), style: const TextStyle(fontWeight: FontWeight.bold)),
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
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.teal.shade200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(context.tr('cart_net_total'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                            if (cartDiscountValue > 0)
                              Text('${context.tr("discount")}: ${cartDiscountValue.toStringAsFixed(1)}${isDiscountPercentage ? "%" : " DA"}',
                                  style: const TextStyle(fontSize: 12, color: Colors.purple, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Text('${total.toStringAsFixed(2)} DA',
                            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.teal)),
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
                        label: Text('${method.icon} ${method.titleAr}'),
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
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            autofocus: true,
                            keyboardType: TextInputType.number,
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
                  ],
                  const SizedBox(height: 12),

                  // Printer Selection & Auto-Print Toggle Bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
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
                              const Text('طباعة وصل الكاشير:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              Text(
                                !shouldPrintReceipt
                                    ? 'تم تعطيل الطباعة الورقية (تسجيل البيع في النظام فقط)'
                                    : (PrinterHelper.defaultThermalPrinter.isNotEmpty
                                        ? 'الطابعة: ${PrinterHelper.defaultThermalPrinter}'
                                        : '⚠️ لم تحدد طابعة إيصالات (انقر لتحديدها)'),
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
                            label: const Text('تغيير الطابعة', style: TextStyle(fontSize: 11)),
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
                label: const Text('واتساب 💬', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () => onSendWhatsAppReceipt(total, state),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
                icon: Icon(shouldPrintReceipt ? Icons.print_rounded : Icons.check_circle_outline, color: Colors.white),
                label: Text(
                  shouldPrintReceipt ? context.tr('confirm_and_print') : 'تأكيد وحفظ البيع',
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
                        title: '⚠️ تجاوز سقف الدين (${maxLimit.toStringAsFixed(0)} DA) - إذن المشرف',
                      );
                      if (!authorized) {
                        SnackbarHelper.showError(context, '❌ تم إلغاء البيع: رُفض تجاوز سقف الدين بدون إذن المشرف.');
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
                        final proceed = await showDialog<bool>(
                          context: context,
                          builder: (c) => AlertDialog(
                            title: const Text('لم يتم تحديد طابعة إيصالات'),
                            content: const Text('لم يتم اختيار طابعة الوصولات الحرارية.\nهل ترغب في تسجيل البيع في النظام بدون طباعة ورقية لتفادي الطباعة على الطابعة الكبيرة؟'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
                              ElevatedButton(onPressed: () => Navigator.pop(c, true), child: const Text('نعم، حفظ بدون طباعة')),
                            ],
                          ),
                        );
                        if (proceed != true) return;
                        shouldPrintReceipt = false;
                      }
                    }
                  }

                  Navigator.pop(ctx);
                  await onFinalizeSale(paymentMethod, total, manualTpeRefController.text, printReceipt: shouldPrintReceipt);
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
