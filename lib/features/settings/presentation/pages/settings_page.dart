import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:app_settings/app_settings.dart';
import '../../../../core/data/hive_database.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_constants.dart';
import '../../../../core/utils/backup_helper.dart';
import '../../../../core/utils/excel_export_helper.dart';
import '../../../../core/utils/license_service.dart';
import '../../../../core/utils/security_pin_helper.dart';
import '../../../../core/utils/sound_service.dart';
import '../../../../core/utils/notification_service.dart';
import '../../../../core/utils/snackbar_helper.dart';
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
    final isSoundOn = SoundService.isSoundEnabled();
    final isNotifOn = NotificationService.isNotificationsEnabled();
    final liveAlerts = NotificationService.getLiveAlerts();

    return Scaffold(
      appBar: AppBar(
        title: const Text('الإعدادات والإدارة الشاملة',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 40),
        child: Column(
          children: [
            // Profile / Store Header
            Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
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
                              width: 78,
                              height: 78,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.primaryColor.withOpacity(0.25),
                                    blurRadius: 12,
                                    spreadRadius: 3,
                                  )
                                ],
                              ),
                              alignment: Alignment.center,
                              child: ClipOval(
                                child: hasValidLogo
                                    ? Image.file(
                                        File(logoPath),
                                        width: 78,
                                        height: 78,
                                        fit: BoxFit.cover,
                                      )
                                    : Text(
                                        initials,
                                        style: const TextStyle(
                                          fontSize: 26,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: AppTheme.primaryColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.edit, size: 12, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        shopName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isActivated ? 'نسخة مرخصة ومفعلة ⚡' : 'نسخة تجريبية نشطة',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isActivated ? Colors.green[700] : Colors.orange[800],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            // Section 1: Notifications & Sound FX Center
            _buildSectionHeader(context, 'مركز التنبيهات والأصوات التفاعلية'),
            _buildListGroup(
              children: [
                // Notifications Hub Tile
                _buildListItem(
                  icon: Icons.notifications_active_outlined,
                  iconColor: Colors.amber[800],
                  title: 'مركز التنبيهات والإشعارات',
                  subtitle: liveAlerts.isNotEmpty
                      ? 'يوجد ${liveAlerts.length} تنبيهات نشطة (المخزون، الديون، الصلاحية)'
                      : 'لا توجد تنبيهات عاجلة حالياً (المتجر في حالة ممتازة)',
                  trailingWidget: liveAlerts.isNotEmpty
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${liveAlerts.length}',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        )
                      : null,
                  onTap: () => _showNotificationsHub(context),
                ),
                _buildDivider(),

                // System Push Notifications Toggle
                _buildListItem(
                  icon: Icons.cell_tower_rounded,
                  iconColor: Colors.blue,
                  title: 'إشعارات شريط الهاتف',
                  subtitle: isNotifOn
                      ? 'مفعلة (تصلك التنبيهات في شريط الإشعارات العلوي للهاتف)'
                      : 'معطلة (الإشعارات تظهر داخل التطبيق فقط)',
                  trailingWidget: Switch(
                    value: isNotifOn,
                    activeColor: AppTheme.primaryColor,
                    onChanged: (val) async {
                      await NotificationService.setNotificationsEnabled(val);
                      setState(() {});
                      if (context.mounted) {
                        context.showAppSnackBar(
                          val ? '🔔 تم تفعيل إشعارات شريط الهاتف' : '🔕 تم إسكات إشعارات شريط الهاتف',
                          backgroundColor: val ? Colors.blue[800]! : Colors.grey[800]!,
                        );
                      }
                    },
                  ),
                ),
                _buildDivider(),

                // Interactive Sound FX Toggle
                _buildListItem(
                  icon: isSoundOn ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                  iconColor: isSoundOn ? Colors.teal : Colors.grey,
                  title: 'المؤثرات الصوتية لنقاط البيع (Sound FX)',
                  subtitle: isSoundOn
                      ? 'مفعلة (نغمة مسح الباركود، رنين الصندوق، والحذف)'
                      : 'مكتومة (الوضع الصامت بدون أصوات)',
                  trailingWidget: Switch(
                    value: isSoundOn,
                    activeColor: Colors.teal,
                    onChanged: (val) async {
                      await SoundService.setSoundEnabled(val);
                      setState(() {});
                      if (val) SoundService.playCheckoutSuccess();
                      if (context.mounted) {
                        context.showAppSnackBar(
                          val ? '🔊 تم تشغيل المؤثرات الصوتية' : '🔇 تم كتم الأصوات (الوضع الصامت)',
                          backgroundColor: val ? Colors.teal[800]! : Colors.grey[800]!,
                        );
                      }
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // Section 2: Store Management Tools (Owner PIN Protected)
            _buildSectionHeader(context, 'إدارة المتجر والعمليات (صلاحيات المالك 🔒)'),
            _buildListGroup(
              children: [
                _buildListItem(
                  icon: Icons.qr_code_scanner,
                  iconColor: Colors.indigo,
                  title: 'إدارة المنتجات والمخزون',
                  subtitle: 'إضافة، تعديل الأسعار، ومراقبة الكميات',
                  onTap: () async {
                    final auth = await SecurityPinHelper.authenticate(context, title: 'إدارة المنتجات والمخزون');
                    if (auth && context.mounted) {
                      context.push('/products');
                    }
                  },
                ),
                _buildDivider(),
                _buildListItem(
                  icon: Icons.archive_outlined,
                  iconColor: Colors.blue,
                  title: 'استلام السلع / Arrivage',
                  subtitle: 'مسح سريع وإدخال دفعات السلع الجديدة للمخزن',
                  onTap: () => context.push('/products/stock-in'),
                ),
                _buildDivider(),
                _buildListItem(
                  icon: Icons.local_shipping_outlined,
                  iconColor: Colors.deepPurple,
                  title: 'فواتير الموردين والمشتريات',
                  subtitle: 'تسجيل فواتير الشراء، متابعة الديون، ودفعات الموردين',
                  onTap: () async {
                    final auth = await SecurityPinHelper.authenticate(context, title: 'فواتير الموردين والمشتريات');
                    if (auth && context.mounted) {
                      context.push('/products/supplier-invoices');
                    }
                  },
                ),
                _buildDivider(),
                _buildListItem(
                  icon: Icons.bar_chart_rounded,
                  iconColor: Colors.green[800]!,
                  title: 'الداشبورد والتقارير اليومية والأرباح',
                  subtitle: 'صافي الأرباح، الإيرادات، وتقرير الإغلاق Z',
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
                  iconColor: Colors.orange[800]!,
                  title: 'دفتر ديون الزبائن (Crédit)',
                  subtitle: 'متابعة الديون، التسديدات، وسجل المعاملات',
                  onTap: () => context.push('/customers'),
                ),
                _buildDivider(),
                _buildListItem(
                  icon: Icons.receipt_long_outlined,
                  iconColor: Colors.red[700]!,
                  title: 'مصاريف ونفقات المحل',
                  subtitle: 'تسجيل فواتير الكهرباء، الكراء، والعمال',
                  onTap: () async {
                    final auth = await SecurityPinHelper.authenticate(context, title: 'مصاريف ونفقات المحل');
                    if (auth && context.mounted) {
                      context.push('/expenses');
                    }
                  },
                ),
                _buildDivider(),
                _buildListItem(
                  icon: Icons.request_quote_outlined,
                  iconColor: Colors.teal[700]!,
                  title: 'عروض الأسعار والفواتير المبدئية (Devis)',
                  subtitle: 'إنشاء Devis رسمي وتحويله لفاتورة بيع بضغطة زر',
                  onTap: () => context.push('/devis'),
                ),
                _buildDivider(),
                _buildListItem(
                  icon: Icons.point_of_sale_rounded,
                  iconColor: Colors.brown[700]!,
                  title: 'مناوبات الكاسة والصندوق (Shifts)',
                  subtitle: 'رصيد البداية والختام وتسليم عهدة الصندوق',
                  onTap: () => context.push('/shifts'),
                ),
                _buildDivider(),
                _buildListItem(
                  icon: Icons.auto_awesome,
                  iconColor: Colors.amber[900]!,
                  title: 'مكتبة المنتجات الجزائرية (100,000+)',
                  subtitle: 'تصفح واستيراد سلع السوبرماركت لمخزونك بضغطة زر',
                  onTap: () => context.push('/master-catalog'),
                ),
                _buildDivider(),
                _buildListItem(
                  icon: Icons.receipt_long,
                  iconColor: Colors.blueGrey,
                  title: 'تخصيص وتصميم وصل الفاتورة (Receipt Designer)',
                  subtitle: 'تعديل الشعار، أرقام الهاتف، والشروط في التذكرة الحرارية',
                  onTap: () => context.push('/settings/receipt-designer'),
                ),
                _buildDivider(),
                _buildListItem(
                  icon: Icons.label_important_rounded,
                  iconColor: Colors.deepOrange,
                  title: 'مولد وطباعة ملصقات الرفوف والباركود 🏷️',
                  subtitle: 'توليد وطباعة بطاقات الأسعار لرفوف السوبرماركت مباشرة',
                  onTap: () => context.push('/products/shelf-labels'),
                ),
                _buildDivider(),
                _buildListItem(
                  icon: Icons.inventory_rounded,
                  iconColor: Colors.teal[700]!,
                  title: 'وحدة الجرد السنوي والدوري ورأس المال 📋⚖️',
                  subtitle: 'جرد المخزون بالكاميرا، حساب الفوارق، ورأس مال المحل',
                  onTap: () => context.push('/products/inventory-audit'),
                ),
                _buildDivider(),
                _buildListItem(
                  icon: Icons.table_chart_outlined,
                  iconColor: Colors.green[700]!,
                  title: 'تصدير البيانات والنسخ الاحتياطي (Excel)',
                  subtitle: 'تصدير المخزون والديون كـ Excel وإنشاء نسخة أمان',
                  onTap: () => _showBackupRestoreSheet(context),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // Section 3: Security PIN
            _buildSectionHeader(context, 'الأمان وحماية المالك (Security PIN)'),
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
                            context.showAppSnackBar(
                              '🔓 تم إلغاء القفل بالرمز السري',
                              backgroundColor: Colors.orange[800]!,
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

            const SizedBox(height: 18),

            // Section 4: Language
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

            const SizedBox(height: 18),

            // Section 5: Hardware & Printer
            _buildSectionHeader(context, context.tr('hardware')),
            BlocConsumer<PrinterBloc, PrinterState>(
              listener: (context, state) {
                if (state.errorMessage != null) {
                  context.showAppSnackBar(state.errorMessage!, backgroundColor: Colors.red);
                } else if (state.status == PrinterStatus.connected) {
                  context.showAppSnackBar(context.tr('connected'), backgroundColor: Colors.green);
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

            const SizedBox(height: 18),

            // Section 6: License & Activation
            _buildSectionHeader(context, 'الترخيص والتفعيل'),
            _buildListGroup(
              children: [
                _buildListItem(
                  icon: Icons.verified_user_outlined,
                  title: isActivated ? 'النسخة مفعلة بالكامل' : 'تفعيل النسخة الرسمية',
                  subtitle: isActivated
                      ? 'الترخيص نشط ويعمل على هذا الجهاز'
                      : 'اضغط لإدخال كود التفعيل أو شراء ترخيص دائم',
                  trailingWidget: isActivated
                      ? const Icon(Icons.check_circle, color: Colors.green, size: 22)
                      : Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('تفعيل', style: TextStyle(color: Colors.brown, fontWeight: FontWeight.bold, fontSize: 11)),
                        ),
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => const ActivationModal(),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showNotificationsHub(BuildContext context) {
    final alerts = NotificationService.getLiveAlerts();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.notifications_active, color: Colors.amber, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        'مركز التنبيهات والإشعارات (${alerts.length})',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: alerts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline, size: 48, color: Colors.green[400]),
                          const SizedBox(height: 12),
                          const Text('لا توجد تنبيهات عاجلة حالياً', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          const SizedBox(height: 4),
                          const Text('جميع مستويات المخزون والديون في حالة طبيعية', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: alerts.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (ctx, index) {
                        final alert = alerts[index];
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withOpacity(0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(alert.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    const SizedBox(height: 4),
                                    Text(alert.message, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                    if (alert.targetRoute != null) ...[
                                      const SizedBox(height: 8),
                                      InkWell(
                                        onTap: () {
                                          Navigator.pop(ctx);
                                          context.push(alert.targetRoute!);
                                        },
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text('معاينة القسم', style: TextStyle(fontSize: 11, color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                                            SizedBox(width: 2),
                                            Icon(Icons.arrow_forward_ios, size: 10, color: AppTheme.primaryColor),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
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
                  context.showAppSnackBar(
                    '🔒 تم تفعيل الرمز السري بنجاح!',
                    backgroundColor: Colors.green[800]!,
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
                    context.showAppSnackBar(
                      '✅ تم تغيير الرمز السري بنجاح!',
                      backgroundColor: Colors.green[800]!,
                    );
                  }
                }
              } else {
                if (ctx.mounted) {
                  context.showAppSnackBar(
                    '❌ الرمز السري القديم غير صحيح!',
                    backgroundColor: Colors.red[800]!,
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

  void _showBackupRestoreSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.table_chart, color: Colors.green, size: 24),
                SizedBox(width: 8),
                Text('النسخ الاحتياطي وتصدير البيانات', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const CircleAvatar(backgroundColor: Color(0xFFE8F5E9), child: Icon(Icons.download, color: Colors.green)),
              title: const Text('تصدير المخزون كملف Excel (CSV)'),
              subtitle: const Text('حفظ قائمة السلع والأسعار والكميات في ملف إكسل'),
              onTap: () async {
                Navigator.pop(ctx);
                final res = await ExcelExportHelper.exportProductsToCSV();
                if (context.mounted) {
                  context.showAppSnackBar(
                    res != null ? '✅ تم حفظ ملف Excel في: $res' : 'تم إلغاء التصدير',
                    backgroundColor: res != null ? Colors.green[800]! : Colors.grey[800]!,
                  );
                }
              },
            ),
            const Divider(),
            ListTile(
              leading: const CircleAvatar(backgroundColor: Color(0xFFE3F2FD), child: Icon(Icons.cloud_upload, color: Colors.blue)),
              title: const Text('إنشاء نسخة احتياطية كاملة (Backup)'),
              subtitle: const Text('حفظ قاعدة بيانات المحل بالكامل في ملف آمن'),
              onTap: () async {
                Navigator.pop(ctx);
                final res = await BackupHelper.exportFullBackup();
                if (context.mounted) {
                  context.showAppSnackBar(
                    res != null ? '✅ تم إنشاء النسخة الاحتياطية بنجاح!' : 'تم الإلغاء',
                    backgroundColor: res != null ? Colors.blue[800]! : Colors.grey[800]!,
                  );
                }
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
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
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E5EA)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(children: children),
      ),
    );
  }

  Widget _buildListItem({
    required IconData icon,
    Color? iconColor,
    required String title,
    String? subtitle,
    Widget? subtitleWidget,
    Widget? trailingWidget,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: (iconColor ?? AppTheme.primaryColor).withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor ?? AppTheme.primaryColor, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
      ),
      subtitle: subtitleWidget ??
          (subtitle != null
              ? Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey[600]))
              : null),
      trailing: trailingWidget ?? const Icon(Icons.arrow_forward_ios, size: 13, color: Colors.grey),
      onTap: onTap,
    );
  }

  Widget _buildDivider() {
    return const Divider(height: 1, indent: 56, color: Color(0xFFF1F5F9));
  }
}
