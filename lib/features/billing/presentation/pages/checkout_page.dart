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
  const CheckoutPage({super.key});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final TextEditingController _paidController = TextEditingController();
  final TextEditingController _acompteController = TextEditingController();
  PaymentMode _paymentMode = PaymentMode.cash;
  Customer? _selectedCustomer;

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
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
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
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(context.tr('select_customer'),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        decoration: InputDecoration(
                          hintText: context.tr('search_customer_hint'),
                          prefixIcon: const Icon(Icons.search),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        onChanged: (val) => setModalState(() => query = val),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: filtered.isEmpty
                            ? Center(
                                child: Text(context.tr('no_customers_found'),
                                    style: const TextStyle(color: Colors.grey)),
                              )
                            : ListView.separated(
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (ctx, index) {
                                  final customer = filtered[index];
                                  return ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                                      child: Text(
                                        customer.name.isNotEmpty ? customer.name[0].toUpperCase() : 'C',
                                        style: const TextStyle(
                                            color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    title: Text(customer.name, style: const TextStyle(fontWeight: FontWeight.bold)),
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
          duration: const Duration(milliseconds: 1500),
        ),
      );
      return;
    }

    try {
      // 1. Decrement product stock in database
      final productRepo = sl<ProductRepository>();
      for (final item in billingState.cartItems) {
        if (!item.product.id.startsWith('custom_') && !item.product.id.startsWith('direct_')) {
          final getResult = await productRepo.getProductById(item.product.id);
          if (getResult.isRight()) {
            final p = getResult.getOrElse(() => throw Exception());
            final newStock = (p.stock - item.quantity).clamp(0, 999999);
            await productRepo.updateProduct(
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
          const SnackBar(
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
            duration: const Duration(milliseconds: 1500),
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
      const SnackBar(
        content: Text('📋 تم نسخ نص الفاتورة لمشاركتها عبر واتساب!'),
        backgroundColor: Colors.teal,
        duration: Duration(seconds: 2),
      ),
    );
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
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(context.tr('printed_success')),
                  backgroundColor: Colors.green,
                  duration: const Duration(milliseconds: 1200),
                ),
              );
            }
          },
          builder: (context, billingState) {
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
                                    color: Colors.black.withOpacity(0.05),
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

                            // Payment Mode Selector Card
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
                                  Text(
                                    context.tr('payment_mode'),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildPaymentModeChip(
                                          mode: PaymentMode.cash,
                                          label: context.tr('pay_cash'),
                                          icon: Icons.payments_outlined,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: _buildPaymentModeChip(
                                          mode: PaymentMode.fullCredit,
                                          label: context.tr('pay_credit'),
                                          icon: Icons.menu_book_rounded,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
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

                            const SizedBox(height: 16),

                            // 1. CASH Change Calculator Mode
                            if (_paymentMode == PaymentMode.cash) ...[
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
                                padding: const EdgeInsets.all(14),
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
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    const SizedBox(height: 8),
                                    InkWell(
                                      onTap: _showCustomerPicker,
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                                                const SizedBox(width: 8),
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
                                            const Icon(Icons.arrow_drop_down, color: Colors.grey),
                                          ],
                                        ),
                                      ),
                                    ),
                                    if (_selectedCustomer != null) ...[
                                      const SizedBox(height: 10),
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.red.withOpacity(0.08),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(context.tr('current_debt'),
                                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                            Text(
                                              '${_selectedCustomer!.currentDebt.toStringAsFixed(2)} ${AppConstants.currencySymbol}',
                                              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                    if (_paymentMode == PaymentMode.acompteCredit) ...[
                                      const SizedBox(height: 12),
                                      TextFormField(
                                        controller: _acompteController,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        decoration: InputDecoration(
                                          labelText: context.tr('acompte_amount'),
                                          hintText: '0.00',
                                          prefixText: '${AppConstants.currencySymbol} ',
                                        ),
                                        onChanged: (v) => setState(() {}),
                                      ),
                                      const SizedBox(height: 8),
                                      Builder(builder: (context) {
                                        final acompte = double.tryParse(_acompteController.text.trim()) ?? 0.0;
                                        final toCredit = (billingState.totalAmount - acompte).clamp(0.0, double.infinity);
                                        return Text(
                                          '${context.tr('remaining_to_credit')} ${toCredit.toStringAsFixed(2)} ${AppConstants.currencySymbol}',
                                          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12),
                                        );
                                      }),
                                    ],
                                  ],
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
                            color: Colors.black.withOpacity(0.08),
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
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // 1. PRIMARY: Fast Sale Without Printing (Green 1-Tap)
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green[700],
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    icon: const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                                    label: const Text(
                                      '⚡ إتمام البيع السريع (بدون طباعة)',
                                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                    onPressed: () => _completeSaleWithoutPrint(billingState),
                                  ),
                                ),
                                const SizedBox(height: 8),

                                // 2. SECONDARY: Thermal Bluetooth Print & WhatsApp Share
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          side: BorderSide(color: AppTheme.primaryColor.withOpacity(0.5)),
                                        ),
                                        icon: const Icon(Icons.print, size: 18, color: AppTheme.primaryColor),
                                        label: Text(
                                          billingState.printSuccess ? context.tr('reprint') : '🖨️ طباعة الوصل',
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
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
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          side: BorderSide(color: Colors.teal.withOpacity(0.5)),
                                        ),
                                        icon: const Icon(Icons.share, size: 18, color: Colors.teal),
                                        label: const Text(
                                          '💬 مشاركة الفاتورة',
                                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.teal),
                                        ),
                                        onPressed: () => _shareInvoiceViaWhatsApp(billingState),
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
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
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
            const SizedBox(height: 4),
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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

