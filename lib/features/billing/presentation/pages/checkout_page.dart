import '../../../../core/widgets/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/data/hive_database.dart';
import '../../../../core/service_locator.dart';
import '../../../../core/utils/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/localization/app_localizations.dart';

import '../../../product/domain/repositories/product_repository.dart';
import '../../../product/data/models/product_model.dart';
import '../../../shop/presentation/bloc/shop_bloc.dart';
import '../../../customer/domain/entities/customer.dart';
import '../../../customer/presentation/cubit/customer_cubit.dart';
import '../../../customer/presentation/cubit/customer_state.dart';
import '../bloc/billing_bloc.dart';

enum PaymentMode { cash, fullCredit, acompteCredit }

class CheckoutPage extends StatefulWidget {
  CheckoutPage({super.key});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final TextEditingController _paidController = TextEditingController();
  final TextEditingController _acompteController = TextEditingController();
  PaymentMode _paymentMode = PaymentMode.cash;
  Customer? _selectedCustomer;
  Color borderColor = const Color(0xFFE5E5EA);

  @override
  void dispose() {
    _paidController.dispose();
    _acompteController.dispose();
    super.dispose();
  }

  void _showCustomerPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        String query = '';
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return BlocBuilder<CustomerCubit, CustomerState>(
              builder: (context, state) {
                final all = state is CustomerLoaded ? state.customers : <Customer>[];
                final filtered = query.isEmpty
                    ? all
                    : all.where((c) =>
                        c.name.toLowerCase().contains(query.toLowerCase()) ||
                        c.phoneNumber.contains(query)).toList();

                return Container(
                  height: MediaQuery.of(context).size.height * 0.75,
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(context.tr('select_customer'),
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          IconButton(icon: Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                        ],
                      ),
                      SizedBox(height: 8),
                      TextField(
                        decoration: InputDecoration(
                          hintText: context.tr('search_customer_hint'),
                          prefixIcon: Icon(Icons.search),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        onChanged: (val) => setModalState(() => query = val),
                      ),
                      SizedBox(height: 12),
                      Expanded(
                        child: filtered.isEmpty
                            ? Center(
                                child: Text(context.tr('no_customers_found'),
                                    style: TextStyle(color: Colors.grey)),
                              )
                            : ListView.separated(
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) => Divider(height: 1),
                                itemBuilder: (ctx, index) {
                                  final customer = filtered[index];
                                  return ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                                      child: Text(
                                        customer.name.isNotEmpty ? customer.name[0].toUpperCase() : 'C',
                                        style: TextStyle(
                                            color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    title: Text(customer.name, style: TextStyle(fontWeight: FontWeight.bold)),
                                    subtitle: Text(
                                      '${customer.phoneNumber.isNotEmpty ? customer.phoneNumber : ""} • ${context.tr('current_debt')}: ${customer.currentDebt.toStringAsFixed(0)} ${AppConstants.currencySymbol}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: customer.currentDebt > 0 ? Colors.red : Colors.grey[600],
                                      ),
                                    ),
                                    onTap: () {
                                      setState(() {
                                        _selectedCustomer = customer;
                                      });
                                      Navigator.pop(ctx);
                                    },
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _completeSaleWithoutPrint(BillingState billingState) async {
    if (_paymentMode != PaymentMode.cash && _selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('select_customer_hint')),
          backgroundColor: Colors.orange,
          duration: Duration(milliseconds: 1500),
        ),
      );
      return;
    }

    try {
      // 1. Decrement product stock in database
      final productBox = HiveDatabase.productBox;
      for (final item in billingState.cartItems) {
        if (!item.product.id.startsWith('custom_') && !item.product.id.startsWith('direct_')) {
          final p = productBox.get(item.product.id);
          if (p != null) {
            final newStock = (p.stock - item.quantity).clamp(0, 999999);
            await productBox.put(
              item.product.id,
              ProductModel(
                id: p.id,
                name: p.name,
                barcode: p.barcode,
                price: p.price,
                costPrice: p.costPrice,
                stock: newStock,
              ),
            );
          }
        }
      }

      // 2. Calculate costs and save invoice in invoicesBox for Daily Reports & Profit
      final totalCost = billingState.cartItems.fold<double>(
        0.0,
        (sum, i) => sum + (i.product.costPrice * i.quantity),
      );
      final invoiceId = DateTime.now().millisecondsSinceEpoch.toString();
      final items = billingState.cartItems.map((item) => {
        'name': item.product.name,
        'qty': item.quantity,
        'price': item.product.price,
        'costPrice': item.product.costPrice,
        'total': item.total,
      }).toList();

      final paidAmount = _paymentMode == PaymentMode.cash
          ? (double.tryParse(_paidController.text.trim()) ?? billingState.totalAmount)
          : (_paymentMode == PaymentMode.acompteCredit
              ? (double.tryParse(_acompteController.text.trim()) ?? 0.0)
              : 0.0);

      await HiveDatabase.invoicesBox.put(invoiceId, {
        'id': invoiceId,
        'timestamp': DateTime.now().toIso8601String(),
        'totalAmount': billingState.totalAmount,
        'totalCost': totalCost,
        'netProfit': (billingState.totalAmount - totalCost).clamp(0.0, double.infinity),
        'itemCount': billingState.cartItems.fold<int>(0, (sum, i) => sum + i.quantity),
        'items': items,
        'isCredit': _paymentMode != PaymentMode.cash,
        'customerName': _selectedCustomer?.name ?? '',
        'paidAmount': paidAmount,
        'paymentMode': _paymentMode.name,
      });

      // 3. Record customer debt if credit
      if (_paymentMode == PaymentMode.fullCredit && _selectedCustomer != null) {
        await context.read<CustomerCubit>().addCredit(
              customerId: _selectedCustomer!.id,
              creditAmount: billingState.totalAmount,
              note: 'مشتريات بالكريدي',
            );
      } else if (_paymentMode == PaymentMode.acompteCredit && _selectedCustomer != null) {
        final acomptePaid = double.tryParse(_acompteController.text.trim()) ?? 0.0;
        final creditToAdd = (billingState.totalAmount - acomptePaid).clamp(0.0, double.infinity);
        await context.read<CustomerCubit>().addCredit(
              customerId: _selectedCustomer!.id,
              creditAmount: creditToAdd,
              note: 'مشتريات (تسبيق $acomptePaid ${AppConstants.currencySymbol})',
            );
      }

      if (mounted) {
        context.read<BillingBloc>().add(ClearCartEvent());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ تم تسجيل البيع وتحديث المخزون والأرباح بنجاح!'),
            backgroundColor: Colors.green,
            duration: Duration(milliseconds: 1200),
          ),
        );
        context.go('/');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ أثناء تسجيل البيع: $e'),
            backgroundColor: Colors.red,
            duration: Duration(milliseconds: 1500),
          ),
        );
      }
    }
  }

  void _shareInvoiceViaWhatsApp(BillingState billingState) {
    final shopState = context.read<ShopBloc>().state;
    final shopName = shopState is ShopLoaded ? shopState.shop.name : 'متجرنا';
    final now = DateTime.now();
    final dateStr = '${now.year}/${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}';

    final buffer = StringBuffer();
    buffer.writeln('🧾 *فاتورة مشتريات*');
    buffer.writeln('🏪 *المتجر:* $shopName');
    buffer.writeln('📅 *التاريخ:* $dateStr');
    if (_selectedCustomer != null) {
      buffer.writeln('👤 *الزبون:* ${_selectedCustomer!.name}');
    }
    buffer.writeln('---------------------------');
    buffer.writeln('🛒 *قائمة السلع:*');
    for (var item in billingState.cartItems) {
      buffer.writeln('• ${item.product.name} × ${item.quantity} = ${item.total.toStringAsFixed(2)} ${AppConstants.currencySymbol}');
    }
    buffer.writeln('---------------------------');
    buffer.writeln('💰 *المجموع:* ${billingState.totalAmount.toStringAsFixed(2)} ${AppConstants.currencySymbol}');

    if (_paymentMode == PaymentMode.cash && billingState.paidAmount > 0) {
      buffer.writeln('💵 *المستلم:* ${billingState.paidAmount.toStringAsFixed(0)} ${AppConstants.currencySymbol}');
      if (billingState.changeAmount > 0) {
        buffer.writeln('🟢 *الباقي:* ${billingState.changeAmount.toStringAsFixed(2)} ${AppConstants.currencySymbol}');
      }
    } else if (_paymentMode != PaymentMode.cash) {
      buffer.writeln('⚠️ *طريقة الدفع:* كريدي / دين مسجل');
    }

    buffer.writeln('✨ شكراً لتعاملكم معنا!');

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('📋 تم نسخ نص الفاتورة لمشاركتها عبر واتساب!'),
        backgroundColor: Colors.teal,
        duration: Duration(milliseconds: 1200),
      ),
    );
  }

  Future<void> _saveAsDevis(BillingState billingState) async {
    if (billingState.cartItems.isEmpty) return;

    final clientName = _selectedCustomer?.name ?? 'زبون عام';
    final clientPhone = _selectedCustomer?.phoneNumber ?? '';
    final devisId = DateTime.now().millisecondsSinceEpoch.toString();

    final items = billingState.cartItems.map((it) => {
      'name': it.product.name,
      'price': it.product.price,
      'costPrice': it.product.costPrice,
      'quantity': it.quantity,
      'barcode': it.product.barcode,
    }).toList();

    await HiveDatabase.devisBox.put(devisId, {
      'id': devisId,
      'clientName': clientName,
      'clientPhone': clientPhone,
      'date': DateTime.now().toIso8601String(),
      'items': items,
      'totalAmount': billingState.totalAmount,
    });

    if (!mounted) return;

    context.read<BillingBloc>().add(ClearCartEvent());

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ تم حفظ عرض الأسعار للزبون: $clientName'),
        backgroundColor: Colors.purple[700],
        duration: Duration(milliseconds: 1500),
      ),
    );

    context.go('/devis');
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) return;
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/');
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.tr('checkout'),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new,
                size: 20, color: Theme.of(context).primaryColor),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/');
              }
            },
          ),
        ),
        body: BlocConsumer<BillingBloc, BillingState>(
          listener: (context, state) {
            if (state.printSuccess) {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(context.tr('printed_success')),
                  backgroundColor: Colors.green,
                  duration: Duration(milliseconds: 1200),
                ),
              );
            }
          },
          builder: (context, billingState) {
            return Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Column(
                          children: [
                            if (billingState.isReturnMode)
                              Container(
                                margin: EdgeInsets.only(bottom: 12),
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.replay_circle_filled, color: Colors.red, size: 24),
                                    SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(context.tr('return_mode_active'),
                                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.red)),
                                          Text(context.tr('return_mode_hint'),
                                              style: TextStyle(fontSize: 11, color: Colors.brown)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            // Items Table
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: borderColor),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 10,
                                    offset: Offset(0, 3),
                                  )
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Table(
                                  border: TableBorder(
                                    horizontalInside:
                                        BorderSide(color: borderColor),
                                    bottom: BorderSide(color: borderColor),
                                  ),
                                  children: [
                                    TableRow(
                                      decoration: BoxDecoration(
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
                                    if (billingState.calculatedDiscount > 0) ...[
                                      TableRow(
                                        decoration: BoxDecoration(color: Colors.purple.withOpacity(0.04)),
                                        children: [
                                          _buildDataCell('المجموع قبل الخصم', TextAlign.start, isSubtitle: true),
                                          _buildDataCell('', TextAlign.center),
                                          _buildDataCell('${billingState.subTotalAmount.toStringAsFixed(2)} ${AppConstants.currencySymbol}', TextAlign.end, isSubtitle: true),
                                        ],
                                      ),
                                      TableRow(
                                        decoration: BoxDecoration(color: Colors.purple.withOpacity(0.08)),
                                        children: [
                                          _buildDataCell('🏷️ التخفيض / Remise', TextAlign.start, isBold: true),
                                          _buildDataCell(billingState.isDiscountPercentage ? '(${billingState.discountValue.toStringAsFixed(0)}%)' : '', TextAlign.center),
                                          _buildDataCell('-${billingState.calculatedDiscount.toStringAsFixed(2)} ${AppConstants.currencySymbol}', TextAlign.end, isBold: true),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                            SizedBox(height: 16),

                            // Payment Mode Selector Card
                            Container(
                              padding: EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: borderColor),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    context.tr('payment_mode'),
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildPaymentModeChip(
                                          mode: PaymentMode.cash,
                                          label: context.tr('pay_cash'),
                                          icon: Icons.payments_outlined,
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: _buildPaymentModeChip(
                                          mode: PaymentMode.fullCredit,
                                          label: context.tr('pay_credit'),
                                          icon: Icons.menu_book_rounded,
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: _buildPaymentModeChip(
                                          mode: PaymentMode.acompteCredit,
                                          label: context.tr('pay_acompte'),
                                          icon: Icons.price_check,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            SizedBox(height: 16),

                            // 1. CASH Change Calculator Mode
                            if (_paymentMode == PaymentMode.cash) ...[
                              Container(
                                padding: EdgeInsets.all(14),
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
                                        Icon(Icons.calculate_outlined, color: AppTheme.primaryColor, size: 20),
                                        SizedBox(width: 6),
                                        Text(context.tr('change_calc'),
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                      ],
                                    ),
                                    SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextFormField(
                                            controller: _paidController,
                                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                                            decoration: InputDecoration(
                                              labelText: context.tr('paid_amount'),
                                              hintText: '0.00',
                                              prefixText: '${AppConstants.currencySymbol} ',
                                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                            ),
                                            onChanged: (val) {
                                              final paid = double.tryParse(val) ?? 0.0;
                                              context.read<BillingBloc>().add(SetPaidAmountEvent(paid));
                                            },
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        _buildCashChip(billingState.totalAmount, context.tr('exact_amount'), isExact: true),
                                      ],
                                    ),
                                    SizedBox(height: 8),
                                    Row(
                                      children: [
                                        _buildCashChip(500, '500'),
                                        SizedBox(width: 6),
                                        _buildCashChip(1000, '1000'),
                                        SizedBox(width: 6),
                                        _buildCashChip(2000, '2000'),
                                      ],
                                    ),
                                    if (billingState.paidAmount > 0) ...[
                                      SizedBox(height: 12),
                                      Container(
                                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: billingState.paidAmount >= billingState.totalAmount
                                              ? Colors.green.withOpacity(0.1)
                                              : Colors.orange.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: billingState.paidAmount >= billingState.totalAmount
                                                ? Colors.green.withOpacity(0.3)
                                                : Colors.orange.withOpacity(0.3),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              billingState.paidAmount >= billingState.totalAmount
                                                  ? context.tr('change_due')
                                                  : context.tr('insufficient_amount'),
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
                            ],

                            // 2. CREDIT / ACOMPTE Customer Selector Mode
                            if (_paymentMode != PaymentMode.cash) ...[
                              Container(
                                padding: EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      context.tr('select_customer'),
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    SizedBox(height: 8),
                                    InkWell(
                                      onTap: _showCustomerPicker,
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[50],
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: borderColor),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                Icon(Icons.person,
                                                    color: _selectedCustomer != null ? AppTheme.primaryColor : Colors.grey),
                                                SizedBox(width: 8),
                                                Text(
                                                  _selectedCustomer != null
                                                      ? _selectedCustomer!.name
                                                      : context.tr('select_customer_hint'),
                                                  style: TextStyle(
                                                    fontWeight: _selectedCustomer != null ? FontWeight.bold : FontWeight.normal,
                                                    color: _selectedCustomer != null ? Colors.black87 : Colors.grey,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Icon(Icons.arrow_drop_down, color: Colors.grey),
                                          ],
                                        ),
                                      ),
                                    ),
                                    if (_selectedCustomer != null) ...[
                                      SizedBox(height: 10),
                                      Container(
                                        padding: EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.red.withOpacity(0.08),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(context.tr('current_debt'),
                                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                            Text(
                                              '${_selectedCustomer!.currentDebt.toStringAsFixed(2)} ${AppConstants.currencySymbol}',
                                              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                    if (_paymentMode == PaymentMode.acompteCredit) ...[
                                      SizedBox(height: 12),
                                      TextFormField(
                                        controller: _acompteController,
                                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                                        decoration: InputDecoration(
                                          labelText: context.tr('acompte_amount'),
                                          hintText: '0.00',
                                          prefixText: '${AppConstants.currencySymbol} ',
                                        ),
                                        onChanged: (v) => setState(() {}),
                                      ),
                                      SizedBox(height: 8),
                                      Builder(builder: (context) {
                                        final acompte = double.tryParse(_acompteController.text.trim()) ?? 0.0;
                                        final toCredit = (billingState.totalAmount - acompte).clamp(0.0, double.infinity);
                                        return Text(
                                          '${context.tr('remaining_to_credit')} ${toCredit.toStringAsFixed(2)} ${AppConstants.currencySymbol}',
                                          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12),
                                        );
                                      }),
                                    ],
                                  ],
                                ),
                              ),
                            ],

                            SizedBox(height: 120),
                          ],
                        ),
                      ),
                    ),

                    // Bottom Action Bar
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 10,
                            offset: Offset(0, -3),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: EdgeInsets.fromLTRB(20, 14, 20, 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${context.tr('total_price')}:',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
                                ),
                                Text(
                                  '${billingState.totalAmount.toStringAsFixed(2)} ${AppConstants.currencySymbol}',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // 1. PRIMARY: Fast Sale Without Printing (Green 1-Tap)
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green[700],
                                      padding: EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    icon: Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                                    label: Text(
                                      '⚡ إتمام البيع السريع (بدون طباعة)',
                                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                    onPressed: () => _completeSaleWithoutPrint(billingState),
                                  ),
                                ),
                                SizedBox(height: 8),

                                // 2. SECONDARY: Thermal Bluetooth Print & WhatsApp Share
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          padding: EdgeInsets.symmetric(vertical: 12),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          side: BorderSide(color: AppTheme.primaryColor.withOpacity(0.5)),
                                        ),
                                        icon: Icon(Icons.print, size: 18, color: AppTheme.primaryColor),
                                        label: Text(
                                          billingState.printSuccess ? context.tr('reprint') : '🖨️ طباعة الوصل',
                                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                                        ),
                                        onPressed: () async {
                                          if (_paymentMode != PaymentMode.cash && _selectedCustomer == null) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text(context.tr('select_customer_hint')),
                                                backgroundColor: Colors.orange,
                                              ),
                                            );
                                            return;
                                          }

                                          final shopState = context.read<ShopBloc>().state;
                                          final shopName = shopState is ShopLoaded ? shopState.shop.name : 'Superette';
                                          final address1 = shopState is ShopLoaded ? shopState.shop.addressLine1 : '';
                                          final address2 = shopState is ShopLoaded ? shopState.shop.addressLine2 : '';
                                          final phone = shopState is ShopLoaded ? shopState.shop.phoneNumber : '';
                                          final footer = shopState is ShopLoaded ? shopState.shop.footerText : 'Merci!';

                                          double creditToAdd = 0.0;
                                          double acomptePaid = 0.0;
                                          double previousDebt = 0.0;
                                          double newDebtTotal = 0.0;

                                          if (_paymentMode == PaymentMode.fullCredit && _selectedCustomer != null) {
                                            creditToAdd = billingState.totalAmount;
                                            previousDebt = _selectedCustomer!.currentDebt;
                                            newDebtTotal = previousDebt + creditToAdd;

                                            await context.read<CustomerCubit>().addCredit(
                                                  customerId: _selectedCustomer!.id,
                                                  creditAmount: creditToAdd,
                                                  note: 'مشتريات بالكريدي',
                                                );
                                          } else if (_paymentMode == PaymentMode.acompteCredit && _selectedCustomer != null) {
                                            acomptePaid = double.tryParse(_acompteController.text.trim()) ?? 0.0;
                                            creditToAdd = (billingState.totalAmount - acomptePaid).clamp(0.0, double.infinity);
                                            previousDebt = _selectedCustomer!.currentDebt;
                                            newDebtTotal = previousDebt + creditToAdd;

                                            await context.read<CustomerCubit>().addCredit(
                                                  customerId: _selectedCustomer!.id,
                                                  creditAmount: creditToAdd,
                                                  note: 'مشتريات (تسبيق $acomptePaid ${AppConstants.currencySymbol})',
                                                );
                                          }

                                          if (mounted) {
                                            context.read<BillingBloc>().add(
                                                  PrintReceiptEvent(
                                                    shopName: shopName,
                                                    address1: address1,
                                                    address2: address2,
                                                    phone: phone,
                                                    footer: footer,
                                                    isCredit: _paymentMode != PaymentMode.cash,
                                                    customerName: _selectedCustomer?.name,
                                                    paidAmount: _paymentMode == PaymentMode.acompteCredit
                                                        ? acomptePaid
                                                        : billingState.paidAmount,
                                                    previousDebt: previousDebt,
                                                    newDebtTotal: newDebtTotal,
                                                  ),
                                                );
                                          }
                                        },
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          padding: EdgeInsets.symmetric(vertical: 12),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          side: BorderSide(color: Colors.teal.withOpacity(0.5)),
                                        ),
                                        icon: Icon(Icons.share, size: 18, color: Colors.teal),
                                        label: Text(
                                          '💬 مشاركة',
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.teal),
                                        ),
                                        onPressed: () => _shareInvoiceViaWhatsApp(billingState),
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          padding: EdgeInsets.symmetric(vertical: 12),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          side: BorderSide(color: Colors.purple.withOpacity(0.5)),
                                        ),
                                        icon: Icon(Icons.description, size: 18, color: Colors.purple),
                                        label: Text(
                                          '📄 عرض أسعار',
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.purple),
                                        ),
                                        onPressed: () => _saveAsDevis(billingState),
                                      ),
                                    ),
                                  ],
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
        ),
      ),
    );
  }

  Widget _buildPaymentModeChip({
    required PaymentMode mode,
    required String label,
    required IconData icon,
  }) {
    final isSelected = _paymentMode == mode;
    return InkWell(
      onTap: () => setState(() => _paymentMode = mode),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor.withOpacity(0.1) : Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: isSelected ? AppTheme.primaryColor : Colors.grey[700]),
            SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? AppTheme.primaryColor : Colors.black87,
              ),
            ),
          ],
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
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isExact ? AppTheme.primaryColor.withOpacity(0.1) : Colors.grey[100],
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
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Text(
        text,
        textAlign: align,
        style: TextStyle(
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
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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

