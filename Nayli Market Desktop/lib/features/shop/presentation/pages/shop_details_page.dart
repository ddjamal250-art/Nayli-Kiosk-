import 'dart:io';
import '../../../../core/widgets/input_label.dart';
import '../../../../core/widgets/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/data/hive_database.dart';
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
  String? _logoPath;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _address1Controller = TextEditingController();
    _address2Controller = TextEditingController();
    _phoneController = TextEditingController();
    _upiController = TextEditingController();
    _footerController = TextEditingController();

    _logoPath = HiveDatabase.settingsBox.get('shop_logo_path') as String?;
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

  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'شعار وصورة بروفيل المتجر',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.photo_library_outlined, color: Colors.blue),
              ),
              title: const Text('اختيار من المعرض (Gallery)'),
              onTap: () async {
                Navigator.pop(ctx);
                final picker = ImagePicker();
                final picked = await picker.pickImage(
                  source: ImageSource.gallery,
                  imageQuality: 85,
                  maxWidth: 800,
                );
                if (picked != null) {
                  await HiveDatabase.settingsBox.put('shop_logo_path', picked.path);
                  setState(() => _logoPath = picked.path);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('📸 تم تحديث شعار المتجر بنجاح!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                }
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.camera_alt_outlined, color: Colors.teal),
              ),
              title: const Text('التقاط صورة بالكاميرا (Camera)'),
              onTap: () async {
                Navigator.pop(ctx);
                final picker = ImagePicker();
                final picked = await picker.pickImage(
                  source: ImageSource.camera,
                  imageQuality: 85,
                  maxWidth: 800,
                );
                if (picked != null) {
                  await HiveDatabase.settingsBox.put('shop_logo_path', picked.path);
                  setState(() => _logoPath = picked.path);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('📸 تم التقاط وحفظ شعار المتجر!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                }
              },
            ),
            if (_logoPath != null) ...[
              const Divider(),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.delete_outline, color: Colors.red),
                ),
                title: const Text('حذف الشعار الحالي', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await HiveDatabase.settingsBox.delete('shop_logo_path');
                  setState(() => _logoPath = null);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('🗑️ تم حذف شعار المتجر')),
                    );
                  }
                },
              ),
            ],
          ],
        ),
      ),
    );
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
    final hasValidLogo = _logoPath != null && File(_logoPath!).existsSync();

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
              const SnackBar(content: Text('✅ تم حفظ معلومات المتجر بنجاح!'), backgroundColor: Colors.green),
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
                  // Logo / Profile Image Picker
                  Center(
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: _pickImage,
                          child: Stack(
                            children: [
                              Container(
                                width: 96,
                                height: 96,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppTheme.primaryColor.withOpacity(0.1),
                                  border: Border.all(
                                    color: AppTheme.primaryColor.withOpacity(0.3),
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.06),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ClipOval(
                                  child: hasValidLogo
                                      ? Image.file(
                                          File(_logoPath!),
                                          fit: BoxFit.cover,
                                          width: 96,
                                          height: 96,
                                        )
                                      : const Icon(
                                          Icons.storefront_rounded,
                                          size: 48,
                                          color: AppTheme.primaryColor,
                                        ),
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: _pickImage,
                          icon: const Icon(Icons.add_photo_alternate_outlined, size: 16),
                          label: Text(
                            hasValidLogo ? 'تغيير صورة الشعار' : 'رفع شعار المتجر (Logo)',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  const InputLabel(text: 'اسم المحل / المتجر التجاري'),
                  _buildTextField(
                    controller: _nameController,
                    hint: 'مثال: سوبرماركت البركة / Superette El Baraka',
                    validator: AppValidators.required(context.tr('required')),
                  ),
                  const SizedBox(height: 15),
                  const InputLabel(text: 'العنوان - السطر 1'),
                  _buildTextField(
                    controller: _address1Controller,
                    hint: 'مثال: حي 1000 مسكن، قرب المسجد',
                    validator: AppValidators.required(context.tr('required')),
                  ),
                  const SizedBox(height: 15),
                  const InputLabel(text: 'المدينة / الولاية'),
                  _buildTextField(
                    controller: _address2Controller,
                    hint: 'مثال: الجزائر العاصمة / وهران / سطيف',
                  ),
                  const SizedBox(height: 15),
                  const InputLabel(text: 'رقم هاتف المتجر'),
                  _buildTextField(
                    controller: _phoneController,
                    hint: 'مثال: 0550 12 34 56',
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 15),
                  const InputLabel(text: 'رسالة تذييل الوصل (Footer)'),
                  _buildTextField(
                    controller: _footerController,
                    hint: 'مثال: شكراً لزيارتكم ونتشرف بخدمتكم - Merci pour votre visite',
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: BlocBuilder<ShopBloc, ShopState>(
          builder: (context, state) {
            return PrimaryButton(
              onPressed: _saveShop,
              icon: Icons.save,
              label: context.tr('save'),
              isLoading: state is ShopLoading,
            );
          },
        ),
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