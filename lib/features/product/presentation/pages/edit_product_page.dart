import 'package:intl/intl.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import '../../../../core/data/hive_database.dart';
import '../../../../core/utils/snackbar_helper.dart';
import '../../../../core/utils/sound_service.dart';
import '../../../shop/data/models/shop_model.dart';
import '../../../../core/widgets/input_label.dart';
import '../../../../core/widgets/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../bloc/product_bloc.dart';
import '../../domain/entities/product.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_validators.dart';
import '../../../../core/utils/app_constants.dart';
import '../../../../core/localization/app_localizations.dart';

class EditProductPage extends StatefulWidget {
  final Product product;
  const EditProductPage({super.key, required this.product});

  @override
  State<EditProductPage> createState() => _EditProductPageState();
}

class _EditProductPageState extends State<EditProductPage> {
  final _formKey = GlobalKey<FormState>();
  late String _name;
  late double _price;
  late double _costPrice;
  late int _stock;

  @override
  void initState() {
    super.initState();
    _name = widget.product.name;
    _price = widget.product.price;
    _costPrice = widget.product.costPrice;
    _stock = widget.product.stock;
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      final updatedProduct = Product(
        id: widget.product.id,
        name: _name,
        barcode: widget.product.barcode,
        price: _price,
        costPrice: _costPrice,
        stock: _stock,
      );

      context.read<ProductBloc>().add(UpdateProduct(updatedProduct));
      context.pop();
    }
  }

  Future<void> _printShelfLabel() async {
    final isConnected = await PrintBluetoothThermal.connectionStatus;
    if (!isConnected) {
      if (mounted) {
        context.showAppSnackBar(
          '⚠️ الطابعة الحرارية غير متصلة! يرجى تشغيل البلوتوث وتوصيلها في الإعدادات.',
          backgroundColor: Colors.orange[800]!,
        );
      }
      return;
    }

    String shopName = AppConstants.defaultShopName;
    final shopBox = HiveDatabase.shopBox;
    if (shopBox.isNotEmpty) {
      final ShopModel? shop = shopBox.getAt(0);
      if (shop != null && shop.name.isNotEmpty) shopName = shop.name;
    }

    final dateStr = DateFormat('yyyy/MM/dd').format(DateTime.now());

    try {
      final List<int> bytes = [];
      bytes.addAll([27, 64]); // Initialize
      bytes.addAll([27, 97, 1]); // Center align
      bytes.addAll('$shopName\n'.codeUnits);
      bytes.addAll([27, 33, 16]); // Double height
      bytes.addAll('${widget.product.name}\n'.codeUnits);
      bytes.addAll([27, 33, 48]); // Huge Price
      bytes.addAll('${widget.product.price.toStringAsFixed(0)} DZD\n'.codeUnits);
      if (widget.product.barcode.isNotEmpty) {
        bytes.addAll([27, 33, 0]);
        bytes.addAll('||||| ${widget.product.barcode} |||||\n'.codeUnits);
      }
      bytes.addAll([27, 33, 0]);
      bytes.addAll('Date: $dateStr\n'.codeUnits);
      bytes.addAll('--------------------------------\n\n'.codeUnits);
      bytes.addAll([29, 86, 66, 0]); // Cut paper

      await PrintBluetoothThermal.writeBytes(bytes);
      SoundService.playCheckoutSuccess();
      if (mounted) {
        context.showAppSnackBar(
          '✅ تم إرسال ملصق الرف لـ (${widget.product.name}) إلى الطابعة بنجاح!',
          backgroundColor: Colors.green[800]!,
        );
      }
    } catch (e) {
      if (mounted) {
        context.showAppSnackBar('حدث خطأ أثناء الطباعة: $e', backgroundColor: Colors.red[800]!);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new,
              size: 20, color: Theme.of(context).primaryColor),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/products');
            }
          },
        ),
        title: Text(context.tr('edit'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.label_important_rounded, color: Colors.amber),
            tooltip: 'طباعة بطاقة الرف 🏷️',
            onPressed: _printShelfLabel,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Display Barcode details (immutable block)
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppTheme.primaryColor.withOpacity(0.1)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.qr_code_scanner,
                          color: AppTheme.primaryColor, size: 28),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(context.tr('barcode_label'),
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor
                                      .withOpacity(0.7))),
                          const SizedBox(height: 2),
                          Text(widget.product.barcode,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'monospace')),
                        ],
                      ),
                    ],
                  ),
                ),
                InputLabel(text: context.tr('product_name')),
                TextFormField(
                  initialValue: _name,
                  decoration: InputDecoration(
                    hintText: context.tr('product_name'),
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: AppValidators.required(context.tr('required')),
                  onSaved: (value) => _name = value!,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InputLabel(text: context.tr('selling_price')),
                          TextFormField(
                            initialValue: _price.toStringAsFixed(2),
                            keyboardType:
                                const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              hintText: '0.00',
                              prefixText: '${AppConstants.currencySymbol} ',
                            ),
                            validator: AppValidators.price,
                            onSaved: (value) => _price = double.parse(value!),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InputLabel(text: context.tr('cost_price')),
                          TextFormField(
                            initialValue: _costPrice > 0 ? _costPrice.toStringAsFixed(2) : '',
                            keyboardType:
                                const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              hintText: '0.00',
                              prefixText: '${AppConstants.currencySymbol} ',
                            ),
                            onSaved: (value) => _costPrice = double.tryParse(value ?? '') ?? 0.0,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                InputLabel(text: context.tr('current_stock')),
                TextFormField(
                  initialValue: _stock.toString(),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(hintText: '0'),
                  onSaved: (value) => _stock = int.tryParse(value ?? '0') ?? _stock,
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: PrimaryButton(
        onPressed: _submit,
        icon: Icons.save,
        label: context.tr('save'),
      ),
    );
  }
}

