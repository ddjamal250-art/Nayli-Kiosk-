import 'package:billing_app/core/widgets/input_label.dart';
import 'package:billing_app/core/widgets/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../domain/entities/shop.dart';
import '../bloc/shop_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_validators.dart';
import '../../../../core/localization/app_localizations.dart';

class ShopDetailsPage extends StatefulWidget {
  const ShopDetailsPage({super.key});

  @override
  State<ShopDetailsPage> createState() => _ShopDetailsPageState();
}

class _ShopDetailsPageState extends State<ShopDetailsPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _address1Controller;
  late TextEditingController _address2Controller;
  late TextEditingController _phoneController;
  late TextEditingController _upiController;
  late TextEditingController _footerController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _address1Controller = TextEditingController();
    _address2Controller = TextEditingController();
    _phoneController = TextEditingController();
    _upiController = TextEditingController();
    _footerController = TextEditingController();

    context.read<ShopBloc>().add(LoadShopEvent());
  }

  void _updateControllers(Shop shop) {
    if (_nameController.text.isEmpty && shop.name.isNotEmpty) {
      _nameController.text = shop.name;
      _address1Controller.text = shop.addressLine1;
      _address2Controller.text = shop.addressLine2;
      _phoneController.text = shop.phoneNumber;
      _upiController.text = shop.upiId;
      _footerController.text = shop.footerText;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _address1Controller.dispose();
    _address2Controller.dispose();
    _phoneController.dispose();
    _upiController.dispose();
    _footerController.dispose();
    super.dispose();
  }

  void _saveShop() {
    if (_formKey.currentState!.validate()) {
      final shop = Shop(
        name: _nameController.text,
        addressLine1: _address1Controller.text,
        addressLine2: _address2Controller.text,
        phoneNumber: _phoneController.text,
        upiId: _upiController.text,
        footerText: _footerController.text,
      );

      context.read<ShopBloc>().add(UpdateShopEvent(shop));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('shop_details'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 28),
          onPressed: () => context.pop(),
        ),
      ),
      body: BlocConsumer<ShopBloc, ShopState>(
        listener: (context, state) {
          if (state is ShopLoaded) {
            _updateControllers(state.shop);
          } else if (state is ShopOperationSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Shop details saved!'), backgroundColor: Colors.green),
            );
            context.pop();
          } else if (state is ShopError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: Colors.red),
            );
          }
        },
        buildWhen: (previous, current) => current is ShopLoading || current is ShopLoaded,
        builder: (context, state) {
          if (state is ShopLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const InputLabel(text: 'Shop / Store Name'),
                  _buildTextField(
                    controller: _nameController,
                    hint: 'e.g. Superette El Baraka',
                    validator: AppValidators.required(context.tr('required')),
                  ),
                  const SizedBox(height: 15),
                  const InputLabel(text: 'Address Line 1'),
                  _buildTextField(
                    controller: _address1Controller,
                    hint: 'e.g. Cité 1000 Logements',
                    validator: AppValidators.required(context.tr('required')),
                  ),
                  const SizedBox(height: 15),
                  const InputLabel(text: 'Address Line 2 (City / Wilaya)'),
                  _buildTextField(
                    controller: _address2Controller,
                    hint: 'e.g. Alger / Oran / Constantine',
                  ),
                  const SizedBox(height: 15),
                  const InputLabel(text: 'Phone Number'),
                  _buildTextField(
                    controller: _phoneController,
                    hint: 'e.g. 0550 12 34 56',
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 15),
                  const InputLabel(text: 'Receipt Footer Message'),
                  _buildTextField(
                    controller: _footerController,
                    hint: 'e.g. شكراً لزيارتكم - Merci pour votre visite',
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: BlocBuilder<ShopBloc, ShopState>(
        builder: (context, state) {
          return PrimaryButton(
            onPressed: _saveShop,
            icon: Icons.save,
            label: context.tr('save'),
            isLoading: state is ShopLoading,
          );
        },
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}
