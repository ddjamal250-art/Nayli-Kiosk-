import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../../customer/domain/entities/customer.dart';
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
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'الإعدادات والإدارة الشاملة ⚙️',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0.5,
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Store Profile & License Card
            _buildStoreProfileCard(context, isActivated),

            const SizedBox(height: 18),

            // 2. Business Operations Hubs (3 Smart Hubs)
            _buildSectionHeader('مراكز إدارة الأعمال والنشاط التجاري 🗂️'),
            _buildBusinessHubsGrid(context),

            const SizedBox(height: 20),

            // 3. Hardware & Printing Center
            _buildSectionHeader('الأجهزة والطباعة الحرارية 🖨️'),
            _buildHardwareSection(context),

            const SizedBox(height: 20),

            // 4. Sound & Notifications Center
            _buildSectionHeader('الأصوات والإشعارات والتنبيهات 🔊🔔'),
            _buildSoundAndNotificationsSection(context, isSoundOn, isNotifOn, liveAlerts),

            const SizedBox(height: 20),

            // 5. Security & Data Backup Center
            _buildSectionHeader('الأمان والنسخ الاحتياطي 🔒💾'),
            _buildSecurityAndBackupSection(context, isPinEnabled),

            const SizedBox(height: 20),

            // 6. Language & App Info
            _buildSectionHeader('اللغة ومعلومات التطبيق 🌐✨'),
            _buildLanguageAndInfoSection(context, isActivated),

            const SizedBox(height: 35),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // SECTION BUILDERS
  // ==========================================

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, right: 4, left: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Color(0xFF475569),
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildStoreProfileCard(BuildContext context, bool isActivated) {
    return BlocBuilder<ShopBloc, ShopState>(
      builder: (context, state) {
        String shopName = AppConstants.defaultShopName;
        String initials = 'MS';
        if (state is ShopLoaded && state.shop.name.isNotEmpty) {
          shopName = state.shop.name;
          final parts = shopName.split(' ');
          initials = parts.take(2).map((p) => p.isNotEmpty ? p[0].toUpperCase() : '').join('');
          if (initials.isEmpty) initials = 'S';
        }

        final logoPath = HiveDatabase.settingsBox.get('shop_logo_path') as String?;
        bool hasValidLogo = false;
        if (logoPath != null && logoPath.isNotEmpty) {
          try {
            hasValidLogo = File(logoPath).existsSync();
          } catch (_) {
            hasValidLogo = false;
          }
        }

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
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
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withOpacity(0.2),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: ClipOval(
                        child: (hasValidLogo && logoPath != null)
                            ? Image.file(File(logoPath), width: 58, height: 58, fit: BoxFit.cover)
                            : Text(
                                initials,
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(color: AppTheme.primaryColor, shape: BoxShape.circle),
                          child: const Icon(Icons.edit, size: 10, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shopName,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isActivated ? Colors.green.withOpacity(0.12) : Colors.orange.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isActivated ? 'نسخة مرخصة ومفعلة ⚡' : 'نسخة تجريبية ⏳',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isActivated ? Colors.green[800] : Colors.orange[900],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  side: BorderSide(color: AppTheme.primaryColor.withOpacity(0.5)),
                ),
                icon: const Icon(Icons.settings, size: 16, color: AppTheme.primaryColor),
                label: const Text('تعديل', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                onPressed: () async {
                  final auth = await SecurityPinHelper.authenticate(context, title: 'إعدادات المتجر والشعار');
                  if (auth && context.mounted) {
                    await context.push('/shop');
                    setState(() {});
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// 3 Business Management Smart Hubs
  Widget _buildBusinessHubsGrid(BuildContext context) {
    return Column(
      children: [
        // 1. Finance & Reports Hub
        _buildHubCard(
          context: context,
          icon: Icons.bar_chart_rounded,
          iconColor: Colors.green[700]!,
          title: 'مركز المالية والتقارير والأرباح',
          subtitle: 'صافي الأرباح اليومية، المصاريف، ومناوبات الصندوق (Z-Report)',
          badgeText: 'مالية 📊',
          badgeColor: Colors.green,
          onTap: () => _showFinanceHubSheet(context),
        ),
        const SizedBox(height: 10),

        // 2. Inventory & Supply Hub
        _buildHubCard(
          context: context,
          icon: Icons.inventory_2_rounded,
          iconColor: Colors.blue[700]!,
          title: 'مركز المخزون والسلع والتوالف',
          subtitle: 'إدارة السلع، استلام الشحنات، الجرد السنوي، وسجل التوالف',
          badgeText: 'مخزون 📦',
          badgeColor: Colors.blue,
          onTap: () => _showInventoryHubSheet(context),
        ),
        const SizedBox(height: 10),

        // 3. Partners & Customer Credit Hub
        _buildHubCard(
          context: context,
          icon: Icons.groups_rounded,
          iconColor: Colors.orange[800]!,
          title: 'مركز العلاقات والديون وعروض الأسعار',
          subtitle: 'دفتر ديون الزبائن (Crédit)، فواتير الموردين، وعروض Devis',
          badgeText: 'شركاء 👥',
          badgeColor: Colors.orange,
          onTap: () => _showPartnersHubSheet(context),
        ),
      ],
    );
  }

  Widget _buildHubCard({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String badgeText,
    required MaterialColor badgeColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF0F172A)),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(badgeText, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: badgeColor[800])),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }

  /// Hardware & Printing Card
  Widget _buildHardwareSection(BuildContext context) {
    return _buildCardGroup([
      BlocConsumer<PrinterBloc, PrinterState>(
        listener: (context, state) {
          if (state.errorMessage != null) {
            context.showAppSnackBar(state.errorMessage!, backgroundColor: Colors.red);
          } else if (state.status == PrinterStatus.connected) {
            context.showAppSnackBar('✅ تم توصيل الطابعة بنجاح', backgroundColor: Colors.green);
          }
        },
        builder: (context, state) {
          final isConnected = state.connectedMac != null;
          return _buildTile(
            icon: Icons.print_rounded,
            iconColor: Colors.teal[700]!,
            title: 'الطابعة الحرارية (Bluetooth)',
            subtitle: isConnected ? (state.connectedName ?? 'متصلة') : 'اضغط للبحث والاتصال بالطابعة',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isConnected)
                  Container(
                    margin: const EdgeInsets.only(left: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.teal[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.teal[200]!),
                    ),
                    child: Text('متصلة ⚡', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.teal[800])),
                  ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: () => context.read<PrinterBloc>().add(RefreshPrinterEvent()),
                  color: AppTheme.primaryColor,
                ),
              ],
            ),
            onTap: () => context.read<PrinterBloc>().add(RefreshPrinterEvent()),
          );
        },
      ),
      _buildDivider(),
      _buildTile(
        icon: Icons.receipt_long_rounded,
        iconColor: Colors.blueGrey,
        title: 'مصمم التذكرة والوصل الحراري',
        subtitle: 'تخصيص الشعار، أرقام الهاتف، وشروط الفاتورة',
        onTap: () => context.push('/settings/receipt-designer'),
      ),
      _buildDivider(),
      _buildTile(
        icon: Icons.label_important_rounded,
        iconColor: Colors.deepOrange,
        title: 'مولد وطباعة ملصقات الرفوف والباركود',
        subtitle: 'توليد وطباعة بطاقات الأسعار للرفوف مباشرة',
        onTap: () => context.push('/products/shelf-labels'),
      ),
    ]);
  }

  /// Sound & Notifications Card
  Widget _buildSoundAndNotificationsSection(
    BuildContext context,
    bool isSoundOn,
    bool isNotifOn,
    List<StoreAlert> liveAlerts,
  ) {
    return _buildCardGroup([
      _buildTile(
        icon: isSoundOn ? Icons.volume_up_rounded : Icons.volume_off_rounded,
        iconColor: isSoundOn ? Colors.deepPurple : Colors.grey,
        title: 'المؤثرات الصوتية لنقاط البيع (10 نغمات)',
        subtitle: isSoundOn
            ? 'مفعلة (${SoundService.themes.firstWhere((t) => t.id == SoundService.getSelectedThemeId(), orElse: () => SoundService.themes.first).icon} ${SoundService.themes.firstWhere((t) => t.id == SoundService.getSelectedThemeId(), orElse: () => SoundService.themes.first).name})'
            : 'مكتومة (الوضع الصامت)',
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSoundOn)
              IconButton(
                icon: const Icon(Icons.tune_rounded, size: 20, color: AppTheme.primaryColor),
                tooltip: 'تغيير النغمة ومستوى الصوت',
                onPressed: () => _showSoundThemesModal(context),
              ),
            Switch(
              value: isSoundOn,
              activeColor: AppTheme.primaryColor,
              onChanged: (val) async {
                await SoundService.setSoundEnabled(val);
                setState(() {});
                if (val) SoundService.playCheckoutSuccess();
              },
            ),
          ],
        ),
        onTap: isSoundOn ? () => _showSoundThemesModal(context) : null,
      ),
      _buildDivider(),
      _buildTile(
        icon: Icons.notifications_active_outlined,
        iconColor: Colors.amber[800]!,
        title: 'مركز التنبيهات والإشعارات',
        subtitle: liveAlerts.isNotEmpty
            ? 'يوجد ${liveAlerts.length} تنبيهات نشطة (المخزون، الديون)'
            : 'المتجر في حالة ممتازة ولا توجد نواقص',
        trailing: liveAlerts.isNotEmpty
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(12)),
                child: Text('${liveAlerts.length}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              )
            : const Icon(Icons.arrow_forward_ios, size: 13, color: Colors.grey),
        onTap: () => _showNotificationsHub(context),
      ),
      _buildDivider(),
      _buildTile(
        icon: Icons.cell_tower_rounded,
        iconColor: Colors.blue,
        title: 'إشعارات شريط الهاتف العلوي',
        subtitle: isNotifOn ? 'تصلك التنبيهات خارج التطبيق' : 'التنبيهات تظهر داخل التطبيق فقط',
        trailing: Switch(
          value: isNotifOn,
          activeColor: AppTheme.primaryColor,
          onChanged: (val) async {
            await NotificationService.setNotificationsEnabled(val);
            setState(() {});
          },
        ),
      ),
    ]);
  }

  /// Security & Data Backup Card
  Widget _buildSecurityAndBackupSection(BuildContext context, bool isPinEnabled) {
    return _buildCardGroup([
      _buildTile(
        icon: Icons.lock_outline_rounded,
        iconColor: Colors.indigo,
        title: 'قفل التطبيق برمز الأمان (Security PIN)',
        subtitle: isPinEnabled ? 'مفعل (يحمي الأرباح والإعدادات)' : 'معطل (وصول مباشر)',
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isPinEnabled)
              IconButton(
                icon: const Icon(Icons.password_rounded, size: 20, color: AppTheme.primaryColor),
                tooltip: 'تغيير الرمز السري',
                onPressed: () => _showChangePinModal(context),
              ),
            Switch(
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
                  }
                }
              },
            ),
          ],
        ),
      ),
      _buildDivider(),
      _buildTile(
        icon: Icons.table_chart_outlined,
        iconColor: Colors.green[700]!,
        title: 'النسخ الاحتياطي وتصدير البيانات (Excel & Backup)',
        subtitle: 'تصدير المخزون والديون كـ Excel وإنشاء نسخة أمان',
        onTap: () async {
          final auth = await SecurityPinHelper.authenticate(context, title: 'النسخ الاحتياطي وتصدير البيانات');
          if (auth && context.mounted) {
            _showBackupRestoreSheet(context);
          }
        },
      ),
    ]);
  }

  /// Language & App Info Card
  Widget _buildLanguageAndInfoSection(BuildContext context, bool isActivated) {
    return _buildCardGroup([
      BlocBuilder<LanguageCubit, Locale>(
        builder: (context, currentLocale) {
          String langName = 'العربية 🇩🇿';
          if (currentLocale.languageCode == 'fr') langName = 'Français 🇫🇷';
          if (currentLocale.languageCode == 'en') langName = 'English 🇬🇧';

          return _buildTile(
            icon: Icons.language_rounded,
            iconColor: Colors.teal,
            title: 'لغة التطبيق (Language)',
            subtitle: langName,
            onTap: () => _showLanguageModal(context, currentLocale),
          );
        },
      ),
      _buildDivider(),
      _buildTile(
        icon: Icons.verified_user_outlined,
        iconColor: isActivated ? Colors.green : Colors.orange,
        title: isActivated ? 'النسخة مفعلة بالكامل' : 'تفعيل النسخة الرسمية',
        subtitle: isActivated ? 'الترخيص نشط ويعمل على هذا الجهاز' : 'اضغط لإدخال كود التفعيل',
        trailing: isActivated
            ? const Icon(Icons.check_circle, color: Colors.green, size: 22)
            : Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.orange[100], borderRadius: BorderRadius.circular(8)),
                child: const Text('تفعيل ⚡', style: TextStyle(color: Colors.brown, fontWeight: FontWeight.bold, fontSize: 11)),
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
      _buildDivider(),
      _buildTile(
        icon: Icons.info_outline_rounded,
        iconColor: Colors.blueGrey,
        title: 'عن التطبيق والإصدار',
        subtitle: 'Nayli Market Pro V1.4.0 • أحدث إصدار',
        onTap: () => _showAboutModal(context),
      ),
    ]);
  }

  // ==========================================
  // SMART HUB MODAL SHEETS (Context.push with back preservation)
  // ==========================================

  /// 1. Finance & Reports Hub Sheet
  void _showFinanceHubSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.bar_chart_rounded, color: Colors.green, size: 26),
                    SizedBox(width: 8),
                    Text('مركز المالية والتقارير والأرباح 📊', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const SizedBox(height: 10),
            _buildHubActionTile(
              icon: Icons.analytics_outlined,
              iconColor: Colors.green[800]!,
              title: 'الداشبورد والتقارير اليومية والأرباح',
              subtitle: 'صافي الأرباح، الإيرادات، ومبيعات اليوم (Z-Report)',
              onTap: () async {
                Navigator.pop(ctx);
                final auth = await SecurityPinHelper.authenticate(context, title: 'تقرير الأرباح والمبيعات');
                if (auth && context.mounted) context.push('/reports');
              },
            ),
            const Divider(height: 8),
            _buildHubActionTile(
              icon: Icons.receipt_long_outlined,
              iconColor: Colors.red[700]!,
              title: 'مصاريف ونفقات المحل',
              subtitle: 'تسجيل فواتير الكهرباء، الكراء، ومصاريف العمال',
              onTap: () async {
                Navigator.pop(ctx);
                final auth = await SecurityPinHelper.authenticate(context, title: 'مصاريف ونفقات المحل');
                if (auth && context.mounted) context.push('/expenses');
              },
            ),
            const Divider(height: 8),
            _buildHubActionTile(
              icon: Icons.point_of_sale_rounded,
              iconColor: Colors.brown[700]!,
              title: 'مناوبات الكاسة والصندوق (Shifts)',
              subtitle: 'رصيد البداية والختام وتسليم عهدة الصندوق بين العمال',
              onTap: () {
                Navigator.pop(ctx);
                context.push('/shifts');
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  /// 2. Inventory & Supply Hub Sheet
  void _showInventoryHubSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.inventory_2_rounded, color: Colors.blue, size: 26),
                      SizedBox(width: 8),
                      Text('مركز المخزون والسلع والتوالف 📦', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 10),
              _buildHubActionTile(
                icon: Icons.qr_code_scanner,
                iconColor: Colors.indigo,
                title: 'إدارة المنتجات والأسعار',
                subtitle: 'إضافة، تعديل الأسعار، ومراقبة الكميات',
                onTap: () async {
                  Navigator.pop(ctx);
                  final auth = await SecurityPinHelper.authenticate(context, title: 'إدارة المنتجات والمخزون');
                  if (auth && context.mounted) context.push('/products');
                },
              ),
              const Divider(height: 8),
              _buildHubActionTile(
                icon: Icons.archive_outlined,
                iconColor: Colors.blue,
                title: 'استلام السلع والشحنات (Arrivage)',
                subtitle: 'مسح سريع وإدخال دفعات السلع الجديدة للمخزن',
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/products/stock-in');
                },
              ),
              const Divider(height: 8),
              _buildHubActionTile(
                icon: Icons.auto_awesome,
                iconColor: Colors.amber[900]!,
                title: 'كتالوج السلع الجزائرية (100,000+)',
                subtitle: 'تصفح واستيراد سلع السوبرماركت لمخزونك بضغطة زر',
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/master-catalog');
                },
              ),
              const Divider(height: 8),
              _buildHubActionTile(
                icon: Icons.inventory_rounded,
                iconColor: Colors.teal[700]!,
                title: 'وحدة الجرد السنوي والدوري ورأس المال 📋⚖️',
                subtitle: 'جرد المخزون بالكاميرا، حساب الفوارق، ورأس مال المحل',
                onTap: () async {
                  Navigator.pop(ctx);
                  final auth = await SecurityPinHelper.authenticate(context, title: 'وحدة الجرد ورأس المال');
                  if (auth && context.mounted) context.push('/products/inventory-audit');
                },
              ),
              const Divider(height: 8),
              _buildHubActionTile(
                icon: Icons.remove_shopping_cart_rounded,
                iconColor: Colors.red[800]!,
                title: 'سجل التوالف والكسر والاهتلاك 🗑️📉',
                subtitle: 'شطب السلع المكسورة والتالفة وخصمها من المخزون وحساب الخسائر',
                onTap: () async {
                  Navigator.pop(ctx);
                  final auth = await SecurityPinHelper.authenticate(context, title: 'سجل التوالف والاهتلاك');
                  if (auth && context.mounted) context.push('/products/losses');
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  /// 3. Partners & Customer Credit Hub Sheet
  void _showPartnersHubSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.groups_rounded, color: Colors.orange, size: 26),
                    SizedBox(width: 8),
                    Text('مركز العلاقات والديون والموردين 👥', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const SizedBox(height: 10),
            _buildHubActionTile(
              icon: Icons.menu_book_rounded,
              iconColor: Colors.orange[800]!,
              title: 'دفتر ديون الزبائن (Crédit)',
              subtitle: 'متابعة الديون، التسديدات، وسجل المعاملات والواتساب',
              onTap: () async {
                Navigator.pop(ctx);
                final auth = await SecurityPinHelper.authenticate(context, title: 'دفتر ديون الزبائن (Crédit)');
                if (auth && context.mounted) context.push('/customers');
              },
            ),
            const Divider(height: 8),
            _buildHubActionTile(
              icon: Icons.local_shipping_outlined,
              iconColor: Colors.deepPurple,
              title: 'فواتير الموردين ومشتريات الجملة',
              subtitle: 'تسجيل فواتير الشراء، متابعة الديون، ودفعات الموردين',
              onTap: () async {
                Navigator.pop(ctx);
                final auth = await SecurityPinHelper.authenticate(context, title: 'فواتير الموردين والمشتريات');
                if (auth && context.mounted) context.push('/products/supplier-invoices');
              },
            ),
            const Divider(height: 8),
            _buildHubActionTile(
              icon: Icons.request_quote_outlined,
              iconColor: Colors.teal[700]!,
              title: 'عروض الأسعار والفواتير المبدئية (Devis)',
              subtitle: 'إنشاء Devis رسمي وتحويله لفاتورة بيع بضغطة زر',
              onTap: () {
                Navigator.pop(ctx);
                context.push('/devis');
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildHubActionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: iconColor.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 13, color: Colors.grey),
      onTap: onTap,
    );
  }

  // ==========================================
  // GENERAL HELPER WIDGETS
  // ==========================================

  Widget _buildCardGroup(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(children: children),
      ),
    );
  }

  Widget _buildTile({
    required IconData icon,
    Color? iconColor,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: (iconColor ?? AppTheme.primaryColor).withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor ?? AppTheme.primaryColor, size: 18),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
      ),
      subtitle: subtitle != null ? Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))) : null,
      trailing: trailing ?? const Icon(Icons.arrow_forward_ios, size: 13, color: Color(0xFF94A3B8)),
      onTap: onTap,
    );
  }

  Widget _buildDivider() {
    return const Divider(height: 1, indent: 56, color: Color(0xFFF1F5F9));
  }

  // ==========================================
  // MODAL DIALOGS
  // ==========================================

  void _showLanguageModal(BuildContext context, Locale currentLocale) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('اختر لغة التطبيق (Language)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 14),
            _buildLangChoice(ctx, 'العربية (Arabic)', '🇩🇿', 'ar', currentLocale.languageCode == 'ar'),
            const Divider(height: 1),
            _buildLangChoice(ctx, 'Français (French)', '🇫🇷', 'fr', currentLocale.languageCode == 'fr'),
            const Divider(height: 1),
            _buildLangChoice(ctx, 'English', '🇬🇧', 'en', currentLocale.languageCode == 'en'),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildLangChoice(BuildContext ctx, String name, String flag, String code, bool isSelected) {
    return ListTile(
      leading: Text(flag, style: const TextStyle(fontSize: 22)),
      title: Text(name, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? AppTheme.primaryColor : Colors.black87)),
      trailing: isSelected ? const Icon(Icons.check_circle, color: AppTheme.primaryColor) : null,
      onTap: () {
        context.read<LanguageCubit>().setLanguage(code);
        Navigator.pop(ctx);
      },
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
                      SizedBox(width: 8),
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
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline, size: 48, color: Colors.green),
                          SizedBox(height: 12),
                          Text('لا توجد تنبيهات عاجلة حالياً', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          SizedBox(height: 4),
                          Text('جميع مستويات المخزون والديون في حالة طبيعية', style: TextStyle(color: Colors.grey, fontSize: 12)),
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
              leading: const CircleAvatar(backgroundColor: Color(0xFFE8F5E9), child: Icon(Icons.table_chart, color: Colors.green)),
              title: const Text('تصدير المخزون العام كملف Excel (CSV)'),
              subtitle: const Text('حفظ قائمة السلع والأسعار والكميات وقيمة رأس المال'),
              onTap: () {
                Navigator.pop(ctx);
                final csv = ExcelExportHelper.exportProductsToCsv();
                Clipboard.setData(ClipboardData(text: csv));
                SoundService.playCheckoutSuccess();
                context.showAppSnackBar(
                  '📊 تم نسخ بيانات شيت المخزون ورأس المال بتنسيق Excel بنجاح!',
                  backgroundColor: Colors.green[800]!,
                );
              },
            ),
            const Divider(height: 8),
            ListTile(
              leading: const CircleAvatar(backgroundColor: Color(0xFFFFF3E0), child: Icon(Icons.people_alt_outlined, color: Colors.orange)),
              title: const Text('تصدير دفتر ديون الزبائن كملف Excel (CSV)'),
              subtitle: const Text('كشف حساب بالزبائن، أرقام الهواتف، والديون المعلقة'),
              onTap: () {
                Navigator.pop(ctx);
                final custState = context.read<CustomerCubit>().state;
                final List<Customer> customers = custState is CustomerLoaded
                    ? custState.customers
                    : HiveDatabase.customersBox.values
                        .whereType<Map>()
                        .map((e) => Customer.fromMap(e))
                        .toList();
                final csv = ExcelExportHelper.exportDebtsToCsv(customers);
                Clipboard.setData(ClipboardData(text: csv));
                SoundService.playCheckoutSuccess();
                context.showAppSnackBar(
                  '📊 تم نسخ دفتر ديون الزبائن بتنسيق Excel بنجاح!',
                  backgroundColor: Colors.orange[800]!,
                );
              },
            ),
            const Divider(height: 8),
            ListTile(
              leading: const CircleAvatar(backgroundColor: Color(0xFFE3F2FD), child: Icon(Icons.cloud_upload, color: Colors.blue)),
              title: const Text('إنشاء نسخة احتياطية كاملة (Backup JSON)'),
              subtitle: const Text('حفظ قاعدة بيانات المحل بالكامل في ملف آمن'),
              onTap: () {
                Navigator.pop(ctx);
                final json = BackupHelper.exportDatabaseToJson();
                Clipboard.setData(ClipboardData(text: json));
                SoundService.playCheckoutSuccess();
                context.showAppSnackBar(
                  '💾 تم إنشاء ونسخ النسخة الاحتياطية الكاملة للمحل بنجاح!',
                  backgroundColor: Colors.blue[800]!,
                );
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  void _showSoundThemesModal(BuildContext context) {
    int currentThemeId = SoundService.getSelectedThemeId();
    double currentVol = SoundService.getVolume();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          padding: const EdgeInsets.all(20),
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.music_note_rounded, color: Colors.amber, size: 24),
                      SizedBox(width: 8),
                      Text('معرض نغمات الكاشير (10 نغمات تفاعلية) 🎵',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ],
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.volume_up, size: 20, color: Colors.grey[700]),
                    const SizedBox(width: 8),
                    Text('مستوى الصوت (${(currentVol * 100).toInt()}%):',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    Expanded(
                      child: Slider(
                        value: currentVol,
                        activeColor: AppTheme.primaryColor,
                        onChanged: (v) async {
                          setModalState(() => currentVol = v);
                          await SoundService.setVolume(v);
                        },
                        onChangeEnd: (v) => SoundService.playScanBeep(themeId: currentThemeId),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text('اضغط على "تجربة" للاستماع ثم اختر النغمة المفضلة لك:',
                  style: TextStyle(fontSize: 11.5, color: Colors.grey, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.separated(
                  itemCount: SoundService.themes.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final theme = SoundService.themes[i];
                    final isSelected = currentThemeId == theme.id;

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      leading: Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected ? AppTheme.primaryColor.withOpacity(0.15) : Colors.grey[100],
                          shape: BoxShape.circle,
                        ),
                        child: Text(theme.icon, style: const TextStyle(fontSize: 18)),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              theme.name,
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                fontSize: 13,
                                color: isSelected ? AppTheme.primaryColor : Colors.black87,
                              ),
                            ),
                          ),
                          if (isSelected)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text('المفعلة ⚡',
                                  style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.green)),
                            ),
                        ],
                      ),
                      subtitle: Text(theme.description, style: TextStyle(fontSize: 10.5, color: Colors.grey[600])),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton.filledTonal(
                            icon: const Icon(Icons.play_arrow_rounded, size: 20),
                            tooltip: 'استماع وتجربة',
                            onPressed: () {
                              SoundService.playScanBeep(themeId: theme.id);
                            },
                          ),
                          Radio<int>(
                            value: theme.id,
                            groupValue: currentThemeId,
                            activeColor: AppTheme.primaryColor,
                            onChanged: (v) async {
                              if (v != null) {
                                setModalState(() => currentThemeId = v);
                                await SoundService.setSelectedThemeId(v);
                                SoundService.playCheckoutSuccess(themeId: v);
                                setState(() {});
                              }
                            },
                          ),
                        ],
                      ),
                      onTap: () async {
                        setModalState(() => currentThemeId = theme.id);
                        await SoundService.setSelectedThemeId(theme.id);
                        SoundService.playScanBeep(themeId: theme.id);
                        setState(() {});
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('تأكيد واختيار النغمة 💾', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAboutModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.point_of_sale_rounded, color: AppTheme.primaryColor, size: 36),
            ),
            const SizedBox(height: 12),
            const Text('نايلـي ماركت (Nayli Market)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 4),
            const Text('نظام الكاشير وإدارة السوبرماركت والمخزون الذكي', style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 14),
            const Text('الإصدار: 1.4.0 (Build 2026)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                minimumSize: const Size(double.infinity, 44),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إغلاق', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
