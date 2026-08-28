import 'package:billing_app/core/widgets/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import '../../../../core/utils/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/localization/app_localizations.dart';

import '../../../shop/presentation/bloc/shop_bloc.dart';
import '../bloc/billing_bloc.dart';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final TextEditingController _paidController = TextEditingController();

  @override
  void dispose() {
    _paidController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const borderColor = Color(0xFFE5E5EA);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) return;
        context.read<BillingBloc>().add(ClearCartEvent());
        context.go('/');
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.tr('checkout'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.chevron_left,
                size: 28, color: Theme.of(context).primaryColor),
            onPressed: () {
              context.read<BillingBloc>().add(ClearCartEvent());
              context.go('/');
            },
          ),
        ),
        body: BlocConsumer<BillingBloc, BillingState>(
          listener: (context, state) {
            if (state.printSuccess) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(context.tr('printed_success')),
                  backgroundColor: Colors.green,
                ),
              );
            }
          },
          builder: (context, billingState) {
            return BlocBuilder<ShopBloc, ShopState>(
              builder: (context, shopState) {
                String upiId = '';
                String shopName = 'Shop';

                if (shopState is ShopLoaded) {
                  upiId = shopState.shop.upiId;
                  shopName = shopState.shop.name;
                }

                return Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Column(
                          children: [
                            // Items Table
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: borderColor),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  )
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Table(
                                  border: const TableBorder(
                                    horizontalInside:
                                        BorderSide(color: borderColor),
                                    bottom: BorderSide(color: borderColor),
                                  ),
                                  children: [
                                    TableRow(
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFF8FAFC),
                                        border: Border(
                                            bottom:
                                                BorderSide(color: borderColor)),
                                      ),
                                      children: [
                                        _buildHeaderCell(
                                            context.tr('item_name'), TextAlign.start),
                                        _buildHeaderCell(
                                            context.tr('item_price'), TextAlign.center),
                                        _buildHeaderCell(
                                            context.tr('total'), TextAlign.end),
                                      ],
                                    ),
                                    ...billingState.cartItems.map((item) {
                                      return TableRow(
                                        children: [
                                          _buildDataCell(
                                            '${item.quantity} × ${item.product.name}',
                                            TextAlign.start,
                                          ),
                                          _buildDataCell(
                                              item.product.price.toStringAsFixed(2),
                                              TextAlign.center,
                                              isSubtitle: true),
                                          _buildDataCell(
                                              '${item.total.toStringAsFixed(2)} ${AppConstants.currencySymbol}',
                                              TextAlign.end,
                                              isBold: true),
                                        ],
                                      );
                                    }),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Change Calculator Section
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: borderColor),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.calculate_outlined, color: AppTheme.primaryColor, size: 20),
                                      const SizedBox(width: 6),
                                      Text(context.tr('change_calc'),
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          controller: _paidController,
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          decoration: InputDecoration(
                                            labelText: context.tr('paid_amount'),
                                            hintText: '0.00',
                                            prefixText: '${AppConstants.currencySymbol} ',
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                          ),
                                          onChanged: (val) {
                                            final paid = double.tryParse(val) ?? 0.0;
                                            context.read<BillingBloc>().add(SetPaidAmountEvent(paid));
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      _buildCashChip(billingState.totalAmount, context.tr('exact_amount'), isExact: true),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      _buildCashChip(500, '500'),
                                      const SizedBox(width: 6),
                                      _buildCashChip(1000, '1000'),
                                      const SizedBox(width: 6),
                                      _buildCashChip(2000, '2000'),
                                    ],
                                  ),
                                  if (billingState.paidAmount > 0) ...[
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: billingState.paidAmount >= billingState.totalAmount
                                            ? Colors.green.withValues(alpha: 0.1)
                                            : Colors.orange.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: billingState.paidAmount >= billingState.totalAmount
                                              ? Colors.green.withValues(alpha: 0.3)
                                              : Colors.orange.withValues(alpha: 0.3),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            billingState.paidAmount >= billingState.totalAmount
                                                ? context.tr('change_due')
                                                : context.tr('remaining_due'),
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: billingState.paidAmount >= billingState.totalAmount
                                                  ? Colors.green[900]
                                                  : Colors.orange[900],
                                            ),
                                          ),
                                          Text(
                                            '${(billingState.paidAmount >= billingState.totalAmount ? billingState.changeAmount : (billingState.totalAmount - billingState.paidAmount)).toStringAsFixed(2)} ${AppConstants.currencySymbol}',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w900,
                                              color: billingState.paidAmount >= billingState.totalAmount
                                                  ? Colors.green[900]
                                                  : Colors.orange[900],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ]
                                ],
                              ),
                            ),

                            if (upiId.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              SizedBox(
                                width: 140,
                                height: 140,
                                child: PrettyQrView.data(
                                  data:
                                      'upi://pay?pa=$upiId&pn=$shopName&am=${billingState.totalAmount.toStringAsFixed(2)}&cu=${AppConstants.currencySymbol}',
                                ),
                              ),
                            ],

                            const SizedBox(height: 120),
                          ],
                        ),
                      ),
                    ),

                    // Bottom Action Bar
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 10,
                            offset: const Offset(0, -3),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${context.tr('total_price')}:',
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
                                ),
                                Text(
                                  '${billingState.totalAmount.toStringAsFixed(2)} ${AppConstants.currencySymbol}',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Row(
                              children: [
                                if (billingState.printSuccess) ...[
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      icon: const Icon(Icons.receipt_long),
                                      label: Text(context.tr('new_invoice'), style: const TextStyle(fontWeight: FontWeight.bold)),
                                      onPressed: () {
                                        context.read<BillingBloc>().add(ClearCartEvent());
                                        context.go('/');
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Expanded(
                                  flex: 2,
                                  child: PrimaryButton(
                                    onPressed: () {
                                      if (shopState is ShopLoaded) {
                                        context.read<BillingBloc>().add(
                                          PrintReceiptEvent(
                                            shopName: shopState.shop.name,
                                            address1: shopState.shop.addressLine1,
                                            address2: shopState.shop.addressLine2,
                                            phone: shopState.shop.phoneNumber,
                                            footer: shopState.shop.footerText,
                                          ),
                                        );
                                      } else {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Error loading shop'), backgroundColor: Colors.red),
                                        );
                                      }
                                    },
                                    label: billingState.printSuccess ? context.tr('reprint') : context.tr('confirm_and_print'),
                                    icon: Icons.print,
                                    isLoading: billingState.isPrinting,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildCashChip(double amount, String label, {bool isExact = false}) {
    return InkWell(
      onTap: () {
        _paidController.text = amount.toStringAsFixed(0);
        context.read<BillingBloc>().add(SetPaidAmountEvent(amount));
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isExact ? AppTheme.primaryColor.withValues(alpha: 0.1) : Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isExact ? AppTheme.primaryColor : Colors.grey[300]!),
        ),
        child: Text(
          '$label ${isExact ? "" : AppConstants.currencySymbol}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: isExact ? AppTheme.primaryColor : Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCell(String text, TextAlign align) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Text(
        text,
        textAlign: align,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildDataCell(String text, TextAlign align,
      {bool isBold = false, bool isSubtitle = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Text(
        text,
        textAlign: align,
        style: TextStyle(
          fontSize: isSubtitle ? 12 : 13,
          fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
          color: isSubtitle ? Colors.grey[600] : Colors.black87,
        ),
      ),
    );
  }
}
