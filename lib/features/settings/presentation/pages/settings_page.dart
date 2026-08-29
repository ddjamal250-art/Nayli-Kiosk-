import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:app_settings/app_settings.dart';
import 'package:flutter/services.dart';
import '../../../../core/data/hive_database.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_constants.dart';
import '../../../../core/utils/backup_helper.dart';
import '../../../../core/utils/excel_export_helper.dart';
import '../../../../core/utils/license_service.dart';
import '../../../../core/utils/security_pin_helper.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/language_cubit.dart';

import '../bloc/printer_bloc.dart';
import '../bloc/printer_event.dart';
import '../bloc/printer_state.dart';
import '../widgets/activation_modal.dart';
import '../../../shop/presentation/bloc/shop_bloc.dart';
import '../../../customer/presentation/cubit/customer_cubit.dart';
import '../../../customer/presentation/cubit/customer_state.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    final isPinEnabled = SecurityPinHelper.isPinEnabled();
    final isActivated = LicenseService.isActivated();
    final trialDays = LicenseService.getRemainingTrialDays();

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('settings'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 28),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profile / Store Header
            Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
              child: BlocBuilder<ShopBloc, ShopState>(
                builder: (context, state) {
                  String shopName = AppConstants.defaultShopName;
                  String initials = 'MS';
                  if (state is ShopLoaded && state.shop.name.isNotEmpty) {
                    shopName = state.shop.name;
                    final parts = shopName.split(' ');
                    initials = parts
                        .take(2)
                        .map((p) => p.isNotEmpty ? p[0].toUpperCase() : '')
                        .join('');
                    if (initials.isEmpty) initials = 'S';
                  }

                  final logoPath = HiveDatabase.settingsBox.get('shop_logo_path') as String?;
                  final hasValidLogo = logoPath != null && File(logoPath).existsSync();

                  return Column(
                    children: [
                      GestureDetector(
                        onTap: () async {
                          final auth = await SecurityPinHelper.authenticate(context, title: 'إعدادات المتجر والشعار');
                          if (auth && context.mounted) {
                            await context.push('/shop');
                            setState(() {});
                          }
                        },
                        child: Stack(
                          children: [
                            Container(
                              width: 84,
                              height: 84,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.primaryColor.withOpacity(0.25),
                                    blurRadius: 12,
                                    spreadRadius: 4,
                                  )
                                ],
                              ),
                              alignment: Alignment.center,
                              child: ClipOval(
                                child: hasValidLogo
                                    ? Image.file(
                                        File(logoPath),
                                        fit: BoxFit.cover,
                                        width: 84,
                                        height: 84,
                                      )
                                    : Text(
                                        initials,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.15),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.edit,
                                  size: 14,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        shopName.toUpperCase(),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  );
                },
              ),
            ),

            // License & Activation Section
            _buildSectionHeader(context, 'ترخيص وتفعيل التطبيق (Activation License)'),
            _buildListGroup(
              children: [
                _buildListItem(
                  icon: isActivated ? Icons.verified_user_rounded : Icons.vpn_key_rounded,
                  title: 'ترخيص التطبيق (Offline Hardware Key)',
                  subtitleWidget: Text(
                    isActivated
                        ? '✅ النسخة الأصلية مفعلة مدى الحياة'
                        : (trialDays > 0
                            ? '⏳ فترة تجريبية مجانية (متبقي $trialDays أيام)'
                            : '❌ انتهت الفترة التجريبية - يلزم التفعيل'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isActivated
                          ? Colors.green[700]
                          : (trialDays > 0 ? Colors.orange[800] : Colors.red[800]),
                    ),
                  ),
                  trailingWidget: TextButton(
                    onPressed: () async {
                      await ActivationModal.show(context);
                      setState(() {});
                    },
                    child: Text(isActivated ? 'عرض المعرّف' : 'تفعيل الآن',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  onTap: () async {
                    await ActivationModal.show(context);
                    setState(() {});
                  },
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Language Selector Section
            _buildSectionHeader(context, context.tr('language')),
            BlocBuilder<LanguageCubit, Locale>(
              builder: (context, currentLocale) {
                return _buildListGroup(
                  children: [
                    _buildLanguageItem(
                      context: context,
                      title: 'العربية (Arabic)',
                      flag: '🇩🇿',
                      code: 'ar',
                      isSelected: currentLocale.languageCode == 'ar',
                    ),
                    _buildDivider(),
                    _buildLanguageItem(
                      context: context,
                      title: 'Français (French)',
                      flag: '🇫🇷',
                      code: 'fr',
                      isSelected: currentLocale.languageCode == 'fr',
                    ),
                    _buildDivider(),
                    _buildLanguageItem(
                      context: context,
                      title: 'English',
                      flag: '🇬🇧',
                      code: 'en',
                      isSelected: currentLocale.languageCode == 'en',
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 20),

            // Security PIN Section
            _buildSectionHeader(context, 'الأمان وقفل الكاسة (Security PIN)'),
            _buildListGroup(
              children: [
                _buildListItem(
                  icon: Icons.lock_outline,
                  title: 'قفل التطبيق برمز سري (PIN)',
                  subtitle: isPinEnabled
                      ? 'مفعل (يحمي الأرباح والإعدادات وتعديل الأسعار)'
                      : 'معطل (يمكن لأي شخص الوصول لجميع الشاشات)',
                  trailingWidget: Switch(
                    value: isPinEnabled,
                    activeColor: AppTheme.primaryColor,
                    onChanged: (val) async {
                      if (val) {
                        _showSetPinModal(context);
                      } else {
                        final auth = await SecurityPinHelper.authenticate(context, title: 'تأكيد إلغاء القفل');
                        if (auth) {
                          await SecurityPinHelper.disablePin();
                          setState(() {});
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('🔓 تم إلغاء القفل بالرمز السري'), backgroundColor: Colors.orange),
                            );
                          }
                        }
                      }
                    },
                  ),
                ),
                if (isPinEnabled) ...[
                  _buildDivider(),
                  _buildListItem(
                    icon: Icons.password_rounded,
                    title: 'تغيير الرمز السري',
                    subtitle: 'تعديل رمز الأمان المكون من 4 أرقام',
                    onTap: () => _showChangePinModal(context),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 20),

            // Management Section
            _buildSectionHeader(context, context.tr('products_management')),
            _buildListGroup(
              children: [
                _buildListItem(
                  icon: Icons.qr_code_scanner,
                  title: context.tr('products_management'),
                  subtitle: context.tr('edit'),
                  onTap: () => context.push('/products'),
                ),
                _buildDivider(),
                _buildListItem(
                  icon: Icons.archive_outlined,
                  title: context.tr('stock_in'),
                  subtitle: context.tr('stock_in_hint'),
                  onTap: () => context.push('/products/stock-in'),
                ),
                _buildDivider(),
                _buildListItem(
                  icon: Icons.bar_chart_rounded,
                  title: context.tr('daily_report'),
                  subtitle: context.tr('print_z_report'),
                  onTap: () async {
                    final auth = await SecurityPinHelper.authenticate(context, title: 'تقرير الأرباح والمبيعات');
                    if (auth && context.mounted) {
                      context.push('/reports');
                    }
                  },
                ),
                _buildDivider(),
                _buildListItem(
                  icon: Icons.menu_book_rounded,
                  title: context.tr('credit_ledger_title'),
                  subtitle: context.tr('total_credit_debts'),
                  onTap: () => context.push('/customers'),
                ),
                _buildDivider(),
                _buildListItem(
                  icon: Icons.auto_awesome,
                  title: 'مكتبة المنتجات الجزائرية (15,500+)',
                  subtitle: 'تصفح واستيراد سلع السوبرماركت لمخزونك',
                  onTap: () => context.push('/master-catalog'),
                ),
                _buildDivider(),
                _buildListItem(
                  icon: Icons.receipt_long,
                  title: 'تخصيص وتصميم وصل الفاتورة (Receipt Designer)',
                  subtitle: 'تعديل وتخصيص شكل الوصل، الشعار، أرقام الهاتف، والشروط',
                  onTap: () => context.push('/settings/receipt-designer'),
                ),
                _buildDivider(),
                _buildListItem(
                  icon: Icons.storefront,
                  title: context.tr('shop_details'),
                  subtitle: context.tr('shop_details'),
                  onTap: () async {
                    final auth = await SecurityPinHelper.authenticate(context, title: 'إعدادات المتجر');
                    if (auth && context.mounted) {
                      await context.push('/shop');
                      setState(() {});
                    }
                  },
                ),
                _buildDivider(),
                _buildListItem(
                  icon: Icons.table_chart_outlined,
                  title: 'تصدير البيانات والنسخ الاحتياطي (Excel)',
                  subtitle: 'تصدير المخزون والديون كـ Excel وإنشاء نسخة أمان',
                  onTap: () => _showBackupRestoreSheet(context),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Hardware Section
            _buildSectionHeader(context, context.tr('hardware')),
            BlocConsumer<PrinterBloc, PrinterState>(
              listener: (context, state) {
                if (state.errorMessage != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(state.errorMessage!), backgroundColor: Colors.red),
                  );
                } else if (state.status == PrinterStatus.connected) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(context.tr('connected')), backgroundColor: Colors.green),
                  );
                }
              },
              builder: (context, state) {
                return _buildListGroup(
                  children: [
                    _buildListItem(
                      icon: Icons.print,
                      title: context.tr('print_device'),
                      subtitleWidget: Row(
                        children: [
                          Text(
                            state.connectedMac != null
                                ? (state.connectedName ?? context.tr('connected'))
                                : context.tr('disconnected'),
                            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                          ),
                          if (state.connectedMac != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.teal[100],
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.teal[200]!),
                              ),
                              child: Text(
                                context.tr('connected'),
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.teal[700],
                                ),
                              ),
                            ),
                          ]
                        ],
                      ),
                      trailingWidget: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (state.status == PrinterStatus.scanning ||
                              state.status == PrinterStatus.connecting)
                            const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else
                            IconButton(
                              icon: const Icon(Icons.refresh),
                              onPressed: () => context.read<PrinterBloc>().add(RefreshPrinterEvent()),
                              color: AppTheme.primaryColor,
                            ),
                          IconButton(
                            icon: const Icon(Icons.settings),
                            onPressed: () {
                              AppSettings.openAppSettings(type: AppSettingsType.bluetooth);
                            },
                            color: Colors.grey,
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 36),
          ],
        ),
      ),
    );
  }

  void _showSetPinModal(BuildContext context) {
    final pinController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.lock_outline, color: AppTheme.primaryColor),
            SizedBox(width: 8),
            Text('تعيين رمز سري PIN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('اختر رمزاً من 4 أرقام لحماية حسابات المتجر والأرباح:'),
            const SizedBox(height: 12),
            TextField(
              controller: pinController,
              keyboardType: TextInputType.number,
              maxLength: 4,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'الرمز السري (4 أرقام)',
                hintText: 'مثال: 1234',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
            onPressed: () async {
              final pin = pinController.text.trim();
              if (pin.length == 4) {
                await SecurityPinHelper.setPin(pin);
                if (ctx.mounted) Navigator.pop(ctx);
                setState(() {});
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('🔒 تم تفعيل الرمز السري بنجاح!'), backgroundColor: Colors.green),
                  );
                }
              }
            },
            child: const Text('حفظ وتفعيل', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showChangePinModal(BuildContext context) {
    final oldPinController = TextEditingController();
    final newPinController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('تغيير الرمز السري', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: oldPinController,
              keyboardType: TextInputType.number,
              maxLength: 4,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'الرمز السري القديم',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: newPinController,
              keyboardType: TextInputType.number,
              maxLength: 4,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'الرمز السري الجديد (4 أرقام)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
            onPressed: () async {
              if (SecurityPinHelper.verifyPin(oldPinController.text.trim())) {
                final newPin = newPinController.text.trim();
                if (newPin.length == 4) {
                  await SecurityPinHelper.setPin(newPin);
                  if (ctx.mounted) Navigator.pop(ctx);
                  setState(() {});
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('✅ تم تغيير الرمز السري بنجاح!'), backgroundColor: Colors.green),
                    );
                  }
                }
              } else {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('❌ الرمز السري القديم غير صحيح!'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('تأكيد التغيير', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageItem({
    required BuildContext context,
    required String title,
    required String flag,
    required String code,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () {
        context.read<LanguageCubit>().setLanguage(code);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Text(flag, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? AppTheme.primaryColor : Colors.black87,
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: AppTheme.primaryColor, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey[600],
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildListGroup({required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E5EA)),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildListItem({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? subtitleWidget,
    VoidCallback? onTap,
    Widget? trailingWidget,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: AppTheme.primaryColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  if (subtitleWidget != null) ...[
                    const SizedBox(height: 2),
                    subtitleWidget,
                  ] else if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                  ],
                ],
              ),
            ),
            if (trailingWidget != null)
              trailingWidget
            else if (onTap != null)
              const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(height: 1, indent: 16, endIndent: 16, color: Color(0xFFF2F2F7));
  }

  void _showBackupRestoreSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('تصدير البيانات والنسخ الاحتياطي',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const SizedBox(height: 12),

            // 1. Export Products to Excel (CSV)
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.teal.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.table_view_rounded, color: Colors.teal),
              ),
              title: const Text('📊 تصدير السلع والمخزون كـ Excel (CSV)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: const Text('استخراج كامل أسعار التكلفة والبيع والكميات في ملف Excel', style: TextStyle(fontSize: 11)),
              onTap: () {
                Navigator.pop(ctx);
                _showCsvExportDialog(context, title: 'ملف سلع ومخزون المحل (Excel)', csvData: ExcelExportHelper.exportProductsToCsv());
              },
            ),
            const Divider(),

            // 2. Export Debts to Excel (CSV)
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.indigo.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.menu_book_rounded, color: Colors.indigo),
              ),
              title: const Text('📖 تصدير دفتر ديون الزبائن كـ Excel (CSV)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: const Text('استخراج أسماء المدينين وأرقام هواتفهم وإجمالي ديونهم', style: TextStyle(fontSize: 11)),
              onTap: () {
                Navigator.pop(ctx);
                final customerState = context.read<CustomerCubit>().state;
                final customers = customerState is CustomerLoaded ? customerState.customers : [];
                _showCsvExportDialog(context, title: 'دفتر ديون الزبائن (Excel)', csvData: ExcelExportHelper.exportDebtsToCsv(customers.cast()));
              },
            ),
            const Divider(),

            // 3. Full Database Backup
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.download, color: Colors.green),
              ),
              title: const Text('💾 إنشاء نسخة احتياطية شاملة (JSON Backup)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: const Text('تصدير كافة المنتجات والمبيعات والديون والإعدادات كملف أمان', style: TextStyle(fontSize: 11)),
              onTap: () {
                Navigator.pop(ctx);
                _showExportDialog(context);
              },
            ),
            const Divider(),

            // 4. Restore Database
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.upload, color: Colors.blue),
              ),
              title: const Text('📥 استرجاع نسخة احتياطية سابقة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: const Text('استيراد البيانات واسترجاع قاعدة البيانات بأمان', style: TextStyle(fontSize: 11)),
              onTap: () {
                Navigator.pop(ctx);
                _showImportDialog(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showCsvExportDialog(BuildContext context, {required String title, required String csvData}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.table_chart_rounded, color: Colors.teal),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('تم تجهيز وتنسيق البيانات بصيغة CSV المتوافقة مع Microsoft Excel و Google Sheets:'),
            const SizedBox(height: 10),
            Container(
              constraints: const BoxConstraints(maxHeight: 140),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
              child: SingleChildScrollView(
                child: Text(csvData, style: const TextStyle(fontFamily: 'monospace', fontSize: 10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: csvData));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('📋 تم نسخ بيانات Excel إلى الحافظة لمشاركتها!'), backgroundColor: Colors.teal),
              );
            },
            child: const Text('نسخ كـ Excel (Copy)'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('تم', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showExportDialog(BuildContext context) {
    final jsonStr = BackupHelper.exportDatabaseToJson();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('النسخة الاحتياطية جاهزة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('تم تجميع وحفظ كامل قاعدة بيانات المحل (السلع، الديون، الفواتير). يمكنك نسخ الكود وحفظه:'),
            const SizedBox(height: 10),
            Container(
              constraints: const BoxConstraints(maxHeight: 140),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
              child: SingleChildScrollView(
                child: Text(jsonStr, style: const TextStyle(fontFamily: 'monospace', fontSize: 10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: jsonStr));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('📋 تم نسخ النسخة الاحتياطية إلى الحافظة!'), backgroundColor: Colors.green),
              );
            },
            child: const Text('نسخ كود النسخة (Copy)'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('تم', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showImportDialog(BuildContext context) {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('استرجاع قاعدة البيانات', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('ألصق نص النسخة الاحتياطية (JSON Backup) لاسترجاع البيانات:'),
            const SizedBox(height: 10),
            TextField(
              controller: textController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'ألصق كود النسخة الاحتياطية هنا...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
            onPressed: () async {
              final text = textController.text.trim();
              if (text.isNotEmpty) {
                final success = await BackupHelper.restoreDatabaseFromJson(context, text);
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(success ? '✅ تم استرجاع قاعدة البيانات بنجاح!' : '❌ حدث خطأ في صيغة النسخة الاحتياطية'),
                      backgroundColor: success ? Colors.green : Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('استرجاع الآن', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}