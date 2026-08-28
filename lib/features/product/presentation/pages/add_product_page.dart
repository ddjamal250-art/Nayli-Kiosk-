import 'package:billing_app/core/widgets/input_label.dart';
import 'package:billing_app/core/widgets/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../bloc/product_bloc.dart';
import '../../domain/entities/product.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_validators.dart';
import '../../../../core/utils/app_constants.dart';
import '../../../../core/localization/app_localizations.dart';

class AddProductPage extends StatefulWidget {
  const AddProductPage({super.key});

  @override
  State<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
  final _formKey = GlobalKey<FormState>();
  String _name = '';
  String _barcode = '';
  double _price = 0.0;
  int _stock = 10;

  void _scanBarcode() async {
    final result = await context.push<String>('/scanner');
    if (result != null && result.isNotEmpty) {
      setState(() {
        _barcode = result;
      });
    }
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      final productState = context.read<ProductBloc>().state;
      final existingProduct =
          productState.products.where((p) => p.barcode == _barcode).firstOrNull;

      if (existingProduct != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Barcode "$_barcode" already registered'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final product = Product(
        id: const Uuid().v4(),
        name: _name,
        barcode: _barcode,
        price: _price,
        stock: _stock,
      );

      context.read<ProductBloc>().add(AddProduct(product));
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.chevron_left,
              size: 28, color: Theme.of(context).primaryColor),
          onPressed: () => context.pop(),
        ),
        title: Text(context.tr('quick_add_title'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InputLabel(text: context.tr('barcode_label')),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        key: ValueKey(_barcode),
                        initialValue: _barcode,
                        decoration: InputDecoration(
                          hintText: context.tr('barcode_label'),
                        ),
                        validator: AppValidators.required(context.tr('required')),
                        onSaved: (value) => _barcode = value!,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.qr_code_scanner,
                            color: AppTheme.primaryColor),
                        onPressed: _scanBarcode,
                        padding: const EdgeInsets.all(14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                InputLabel(text: context.tr('product_name')),
                TextFormField(
                  decoration: InputDecoration(
                    hintText: context.tr('product_name'),
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: AppValidators.required(context.tr('required')),
                  onSaved: (value) => _name = value!,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InputLabel(text: context.tr('selling_price')),
                          TextFormField(
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                          InputLabel(text: context.tr('initial_stock')),
                          TextFormField(
                            keyboardType: TextInputType.number,
                            initialValue: '10',
                            decoration: const InputDecoration(hintText: '10'),
                            onSaved: (value) => _stock = int.tryParse(value ?? '10') ?? 10,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: PrimaryButton(
        onPressed: _submit,
        icon: Icons.add_circle,
        label: context.tr('save'),
      ),
    );
  }
}
