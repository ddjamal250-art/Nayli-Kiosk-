import 'package:intl/intl.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/data/hive_database.dart';
import '../../../../core/theme/theme_cubit.dart';
import '../../../../core/theme/header_branding_cubit.dart';
import '../../../../core/utils/app_constants.dart';
import '../../../../core/utils/sound_service.dart';
import '../../../../core/utils/audit_log_service.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/language_cubit.dart';
import '../../../../core/utils/security_pin_helper.dart';
import '../../../product/presentation/pages/expiry_monitor_page.dart';
import 'header_color_dialog.dart';
import 'session_lock_overlay.dart';
import 'cash_drawer_action_dialog.dart';
import 'package:window_manager/window_manager.dart';
import '../../../shifts/data/shift_service.dart';
import '../../../../core/services/github_update_service.dart';
import '../../../../core/utils/snackbar_helper.dart';

class PosHeaderToolbar extends StatelessWidget {
  final bool isServerRunning;
  final String serverIp;
  final int pendingRemoteCartsCount;
  final CashierShift? activeShift;
  final VoidCallback onOpenDrawer;
  final VoidCallback onShowRemoteCartsQueue;
  final VoidCallback? onOpenSmartScale;
  final VoidCallback? onSwitchShift;
  final VoidCallback? onShiftUpdated;

  const PosHeaderToolbar({
    super.key,
    required this.isServerRunning,
    required this.serverIp,
    required this.pendingRemoteCartsCount,
    this.activeShift,
    required this.onOpenDrawer,
    required this.onShowRemoteCartsQueue,
    this.onOpenSmartScale,
    this.onSwitchShift,
    this.onShiftUpdated,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HeaderBrandingCubit, HeaderBrandingState>(
      builder: (context, headerState) {
        final isDarkHeader = headerState.isDarkHeader;
        final textColor = isDarkHeader ? Colors.white : const Color(0xFF0F172A);
        final subtextColor = isDarkHeader ? Colors.white70 : const Color(0xFF64748B);

        return Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: headerState.headerColor,
            border: Border(
              bottom: BorderSide(
                color: isDarkHeader ? Colors.white12 : const Color(0xFFE5E7EB),
                width: 1,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: headerState.headerColor.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Large Brand Logo with Custom Accent Container
              Tooltip(
                message: context.tr('color_palette_tooltip'),
                child: InkWell(
                  onTap: () => HeaderColorDialog.show(context),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 48,
                    height: 48,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: headerState.logoContainerColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: headerState.accentColor.withOpacity(0.5),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: headerState.accentColor.withOpacity(0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: (() {
                      final customLogoPath = HiveDatabase.settingsBox.get('shop_logo_path') as String?;
                      if (customLogoPath != null && customLogoPath.isNotEmpty && File(customLogoPath).existsSync()) {
                        return Image.file(
                          File(customLogoPath),
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Icon(Icons.storefront, color: headerState.accentColor, size: 28),
                        );
                      }
                      return Image.asset(
                        AppConstants.appLogoPath,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Icon(Icons.storefront, color: headerState.accentColor, size: 28),
                      );
                    })(),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        activeShift != null ? 'الكاشير: ${activeShift!.workerName}' : 'Nayli Kiosk POS',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15.5,
                          color: textColor,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (activeShift != null) 
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('متصل', style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                        )
                      else 
                        const Text('🇩🇿', style: TextStyle(fontSize: 14)),
                    ],
                  ),
                  Text(
                    activeShift != null ? 'مناوبة مفتوحة' : context.tr('pos_title'),
                    style: TextStyle(
                      fontSize: 11,
                      color: subtextColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const Spacer(),

              // Quick Actions Toolbar Buttons
              
              if (onSwitchShift != null)
                Tooltip(
                  message: 'إنهاء المناوبة الحالية وتبديل العامل',
                  child: InkWell(
                    onTap: onSwitchShift,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.blue.shade600, width: 1.2),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.swap_horiz_rounded, color: Colors.blueAccent, size: 20),
                          const SizedBox(width: 5),
                          Text(
                            'تبديل المناوبة',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDarkHeader ? Colors.blueAccent : Colors.blue.shade900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // 0. Session Pause (Break Mode) Quick Button
              Tooltip(
                message: Localizations.localeOf(context).languageCode == 'ar'
                    ? 'إيقاف مؤقت للجلسة / استراحة الكاشير'
                    : 'Session Pause / Break Mode',
                child: InkWell(
                  onTap: () => SessionLockOverlay.show(context),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.amber.shade600, width: 1.2),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.pause_circle_filled_rounded, color: Colors.amber, size: 20),
                        const SizedBox(width: 5),
                        Text(
                          Localizations.localeOf(context).languageCode == 'ar' ? 'استراحة' : 'Break',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDarkHeader ? Colors.amberAccent : Colors.amber.shade900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 1. Direct Cash Drawer Quick Kick (F10)
              IconButton(
                tooltip: context.tr('درج النقود (F10)'),
                icon: const Icon(Icons.account_balance_rounded, color: Colors.amber, size: 22),
                onPressed: onOpenDrawer,
              ),

              // 1.1 Cash Drawer Movements (إيداع / سحب كاش)
              IconButton(
                tooltip: context.tr('حركة الصندوق - إيداع / سحب كاش'),
                icon: const Icon(Icons.payments_rounded, color: Colors.tealAccent, size: 22),
                onPressed: () => CashDrawerActionDialog.show(context, onDone: onShiftUpdated),
              ),
              
              // 1.2 Check Drawer Status (حالة الصندوق اللحظية)
              if (activeShift != null)
                Tooltip(
                  message: 'حالة الصندوق اللحظية ومراقبة حركات الدرج',
                  child: InkWell(
                    onTap: () {
                      LiveCashDrawerStatusDialog.show(
                        context,
                        initialShift: activeShift!,
                        onShiftUpdated: onShiftUpdated,
                      );
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.green.shade900.withOpacity(0.45),
                            Colors.teal.shade900.withOpacity(0.45),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.greenAccent.shade400, width: 1.2),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.account_balance_wallet_rounded, color: Colors.greenAccent, size: 18),
                          const SizedBox(width: 5),
                          Text(
                            '${activeShift!.expectedTotalCashInDrawer.toStringAsFixed(0)} دج | حالة الصندوق',
                            style: const TextStyle(
                              color: Colors.greenAccent,
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // 2. Direct Inventory Access (F4)
              IconButton(
                tooltip: context.tr('إدارة المخزون (F4)'),
                icon: Icon(Icons.inventory_2_outlined, color: isDarkHeader ? Colors.lightGreenAccent : Colors.green, size: 22),
                onPressed: () => context.push('/products'),
              ),

              // 3. Direct Virtual Scale Access (F8)
              if (onOpenSmartScale != null)
                IconButton(
                  tooltip: Localizations.localeOf(context).languageCode == 'ar'
                      ? 'الميزان الافتراضي وتجزئة السلع (F8) ⚖️'
                      : 'Virtual Scale (F8)',
                  icon: const Icon(Icons.scale_rounded, color: Colors.tealAccent, size: 22),
                  onPressed: onOpenSmartScale,
                ),



              // 4. Combined Display & Language Settings
              PopupMenuButton<String>(
                tooltip: Localizations.localeOf(context).languageCode == 'ar' ? 'إعدادات العرض واللغة' : 'Display & Language Settings',
                icon: Icon(
                  Icons.display_settings_rounded,
                  color: isDarkHeader ? Colors.white : const Color(0xFF0F172A),
                  size: 23,
                ),
                offset: const Offset(0, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                onSelected: (action) {
                  if (action == 'palette') {
                    HeaderColorDialog.show(context);
                  } else if (action == 'fullscreen') {
                    final isFull = HiveDatabase.settingsBox.get('is_app_fullscreen', defaultValue: false) == true;
                    if (isFull) {
                      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
                      HiveDatabase.settingsBox.put('is_app_fullscreen', false);
                    } else {
                      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
                      HiveDatabase.settingsBox.put('is_app_fullscreen', true);
                    }
                    SoundService.playKeyTap();
                  } else if (action.startsWith('lang_')) {
                    context.read<LanguageCubit>().setLanguage(action.split('_')[1]);
                  }
                },
                itemBuilder: (ctx) => [
                  PopupMenuItem(
                    value: 'fullscreen',
                    child: Row(
                      children: [
                        const Icon(Icons.fullscreen_rounded, color: Colors.indigo, size: 20),
                        const SizedBox(width: 8),
                        Text(context.tr('ملء الشاشة (F11)'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'palette',
                    child: Row(
                      children: [
                        Icon(Icons.palette_rounded, color: headerState.accentColor, size: 20),
                        const SizedBox(width: 8),
                        Text(context.tr('color_palette_tooltip'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'lang_ar',
                    child: Row(
                      children: [
                        const Text('🇩🇿', style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                        Text(context.tr('arabic'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'lang_fr',
                    child: Row(
                      children: [
                        const Text('🇫🇷', style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                        Text(context.tr('french'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'lang_en',
                    child: Row(
                      children: [
                        const Text('🇬🇧', style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                        Text(context.tr('english'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(width: 4),
              VerticalDivider(
                indent: 14,
                endIndent: 14,
                width: 16,
                color: isDarkHeader ? Colors.white24 : Colors.grey.shade300,
              ),
              const SizedBox(width: 4),

              // 7. Business & Operations Menu Dropdown
              PopupMenuButton<String>(
                tooltip: context.tr('business_hubs_title'),
                icon: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDarkHeader ? Colors.white12 : Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isDarkHeader ? Colors.white24 : Colors.teal.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.dashboard_customize_rounded, size: 18, color: isDarkHeader ? Colors.white : Colors.teal.shade800),
                      const SizedBox(width: 6),
                      Text(
                        context.tr('business_hubs_title'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDarkHeader ? Colors.white : Colors.teal.shade900,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(Icons.arrow_drop_down, size: 18, color: isDarkHeader ? Colors.white : Colors.teal.shade800),
                    ],
                  ),
                ),
                offset: const Offset(0, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                onSelected: (val) async {
                  switch (val) {
                    case 'docs':
                      context.push('/documents');
                      break;
                    case 'reports':
                      if (SecurityPinHelper.isPinEnabled()) {
                        final ok = await SecurityPinHelper.authenticate(
                          context,
                          title: Localizations.localeOf(context).languageCode == 'ar'
                              ? 'التقارير والأرباح محمية'
                              : 'Reports Protected',
                          message: Localizations.localeOf(context).languageCode == 'ar'
                              ? 'يرجى إدخال رمز الأمان للمدير للاطلاع على التقارير'
                              : 'Please enter Manager PIN to view reports',
                        );
                        if (!ok) break;
                      }
                      if (context.mounted) context.push('/reports');
                      break;
                    case 'shifts':
                      context.push('/shifts');
                      break;
                    case 'staff':
                      if (SecurityPinHelper.isPinEnabled()) {
                        final ok = await SecurityPinHelper.authenticate(
                          context,
                          title: Localizations.localeOf(context).languageCode == 'ar'
                              ? 'إدارة الموظفين محمية'
                              : 'Staff Management Protected',
                          message: Localizations.localeOf(context).languageCode == 'ar'
                              ? 'يرجى إدخال رمز الأمان للمدير للوصول لبيانات الموظفين'
                              : 'Please enter Manager PIN to access Staff Management',
                        );
                        if (!ok) break;
                      }
                      if (context.mounted) context.push('/staff-management');
                      break;
                    case 'shopping':
                      context.push('/products/shopping-list');
                      break;
                    case 'expiry':
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const ExpiryMonitorPage()));
                      break;
                    case 'scale':
                      if (onOpenSmartScale != null) {
                        onOpenSmartScale!();
                      }
                      break;
                    case 'update':
                      GitHubUpdateService.checkForUpdates(context, silent: false);
                      break;
                  }
                },
                itemBuilder: (ctx) => [
                  PopupMenuItem(
                    value: 'docs',
                    child: Row(
                      children: [
                        const Icon(Icons.description_outlined, color: Colors.teal, size: 20),
                        const SizedBox(width: 10),
                        Text(context.tr('commercial_docs_btn'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'reports',
                    child: Row(
                      children: [
                        const Icon(Icons.analytics_outlined, color: Colors.purple, size: 20),
                        const SizedBox(width: 10),
                        Text(context.tr('reports_hub_btn'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'shifts',
                    child: Row(
                      children: [
                        const Icon(Icons.badge_rounded, color: Colors.indigo, size: 20),
                        const SizedBox(width: 10),
                        Text(context.tr('open_shifts_btn'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'staff',
                    child: Row(
                      children: [
                        const Icon(Icons.people_alt_rounded, color: Colors.blueGrey, size: 20),
                        const SizedBox(width: 10),
                        Text(context.tr('staff_management_title'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'shopping',
                    child: Row(
                      children: [
                        const Icon(Icons.shopping_cart_checkout, color: Colors.orange, size: 20),
                        const SizedBox(width: 10),
                        Text(context.tr('shopping_list_title'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'expiry',
                    child: Row(
                      children: [
                        const Icon(Icons.hourglass_bottom_rounded, color: Colors.amber, size: 20),
                        const SizedBox(width: 10),
                        Text(context.tr('expiry_title'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'scale',
                    child: Row(
                      children: [
                        const Icon(Icons.scale_rounded, color: Colors.teal, size: 20),
                        const SizedBox(width: 10),
                        Text(
                          Localizations.localeOf(context).languageCode == 'ar'
                              ? 'الميزان الافتراضي وتجزئة السلع (F8)'
                              : 'Virtual Scale (F8)',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'update',
                    child: Row(
                      children: [
                        const Icon(Icons.system_update_rounded, color: Colors.blueAccent, size: 20),
                        const SizedBox(width: 10),
                        Text(
                          Localizations.localeOf(context).languageCode == 'ar'
                              ? 'التحقق من التحديثات الرسمية'
                              : 'Check for Official Updates',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(width: 8),

              // 8. Direct System Settings Button
              IconButton(
                tooltip: context.tr('settings'),
                icon: Icon(
                  Icons.settings_rounded,
                  color: isDarkHeader ? Colors.white70 : Colors.blueGrey.shade700,
                  size: 24,
                ),
                onPressed: () async {
                  if (SecurityPinHelper.isPinEnabled()) {
                    final ok = await SecurityPinHelper.authenticate(
                      context,
                      title: Localizations.localeOf(context).languageCode == 'ar'
                          ? 'إعدادات النظام محمية'
                          : 'Settings Protected',
                      message: Localizations.localeOf(context).languageCode == 'ar'
                          ? 'يرجى إدخال رمز الأمان للمدير للدخول إلى الإعدادات'
                          : 'Please enter Manager Security PIN to access Settings',
                    );
                    if (!ok) return;
                  }
                  if (context.mounted) {
                    context.push('/settings');
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}



// ============================================================================
// الحوار المتقدم لمراقبة حركة الصندوق اللحظية (Real-Time Live Cash Drawer Dialog)
// ============================================================================
class LiveCashDrawerStatusDialog extends StatefulWidget {
  final CashierShift initialShift;
  final VoidCallback? onShiftUpdated;

  const LiveCashDrawerStatusDialog({
    super.key,
    required this.initialShift,
    this.onShiftUpdated,
  });

  static Future<void> show(
    BuildContext context, {
    required CashierShift initialShift,
    VoidCallback? onShiftUpdated,
  }) {
    SoundService.playTabSwitch();
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => LiveCashDrawerStatusDialog(
        initialShift: initialShift,
        onShiftUpdated: onShiftUpdated,
      ),
    );
  }

  @override
  State<LiveCashDrawerStatusDialog> createState() => _LiveCashDrawerStatusDialogState();
}

class _LiveCashDrawerStatusDialogState extends State<LiveCashDrawerStatusDialog> {
  late CashierShift _shift;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _shift = widget.initialShift;
    _refreshData();
  }

  Future<void> _refreshData({bool showSuccessMessage = false}) async {
    setState(() => _isLoading = true);
    try {
      final res = await ShiftService.repairHistoricalData();
      final updated = await ShiftService.getActiveShift(computeLive: true);
      if (mounted && updated != null) {
        setState(() {
          _shift = updated;
          _isLoading = false;
        });
        widget.onShiftUpdated?.call();
        if (showSuccessMessage && mounted) {
          SnackbarHelper.showSuccess(
            context,
            '✅ تم تدقيق وتصحيح الحسابات بأثر رجعي بنجاح (${res['repairedInvoices']} فاتورة و ${res['repairedShifts']} وردية)!',
          );
        }
      }
    } catch (e) {
      debugPrint('Error refreshing live drawer status: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final exp = _shift.expectedTotalCashInDrawer;
    final timeStr = DateFormat('HH:mm').format(_shift.openedAt);

    return AlertDialog(
      backgroundColor: const Color(0xFF0F172A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.teal.shade700, width: 1.5),
      ),
      titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.teal.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.tealAccent.shade400, width: 1),
            ),
            child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.tealAccent, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'مراقبة حركة الصندوق اللحظية 💼',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  'المناوبة: ${_shift.workerName} | فتح الصندوق: $timeStr',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'تدقيق وتصحيح الحسابات بأثر رجعي',
            icon: const Icon(Icons.auto_fix_high_rounded, color: Colors.tealAccent, size: 20),
            onPressed: _isLoading ? null : () {
              SoundService.playSaveSuccess();
              _refreshData(showSuccessMessage: true);
            },
          ),
          IconButton(
            tooltip: 'تحديث فوري للحسابات',
            icon: _isLoading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.tealAccent, strokeWidth: 2))
                : const Icon(Icons.refresh_rounded, color: Colors.tealAccent),
            onPressed: _isLoading ? null : () {
              SoundService.playKeyTap();
              _refreshData();
            },
          ),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. المستطيل البارز اللحظي (The Prominent Real-time Rectangle)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.teal.shade900.withOpacity(0.85),
                      const Color(0xFF064E3B),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.tealAccent.shade400, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.tealAccent.withOpacity(0.12),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.monetization_on_rounded, color: Colors.amberAccent, size: 18),
                        SizedBox(width: 6),
                        Text(
                          'المبلغ الفعلي المتوقع في الدرج الآن',
                          style: TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${exp.toStringAsFixed(2)} دج',
                      style: const TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'محدّث لحظة بلحظة مع كل عملية (${_shift.invoiceCount} فاتورة منجزة)',
                      style: const TextStyle(color: Colors.white60, fontSize: 11),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 2. بطاقة تفاصيل الحركة النقدية
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  children: [
                    _buildRowItem('صرف البداية (Fond initial)', _shift.floatAmount, Colors.white, isPositive: true),
                    const Divider(color: Colors.white12, height: 16),
                    _buildRowItem('مبيعات نقدية مقبوضة (${_shift.invoiceCount} فاتورة)', _shift.cashSales, Colors.greenAccent, isPositive: true),
                    const Divider(color: Colors.white12, height: 16),
                    _buildRowItem('إيداعات نقدية إضافية بالدرج', _shift.cashIn, Colors.tealAccent, isPositive: true),
                    const Divider(color: Colors.white12, height: 16),
                    _buildRowItem('تحصيلات ديون الزبائن نقداً', _shift.debtCollections, Colors.cyanAccent, isPositive: true),
                    const Divider(color: Colors.white12, height: 16),
                    _buildRowItem('سحوبات نقدية مباشرة من الدرج', _shift.cashOut, Colors.orangeAccent, isNegative: true),
                    const Divider(color: Colors.white12, height: 16),
                    _buildRowItem('مصاريف المحل النقدية المسجلة', _shift.expenses, Colors.redAccent, isNegative: true),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // 3. ملخص المبيعات الإلكترونية والآجلة (للعلم والإحاطة)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B).withOpacity(0.6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.credit_card_rounded, color: Colors.blueAccent, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'TPE / بنك: ${_shift.tpeSales.toStringAsFixed(0)} دج',
                          style: const TextStyle(color: Colors.white70, fontSize: 11.5),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(Icons.receipt_long_rounded, color: Colors.amberAccent, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'كريدي (آجل): ${_shift.creditSales.toStringAsFixed(0)} دج',
                          style: const TextStyle(color: Colors.white70, fontSize: 11.5),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal.shade800,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.payments_rounded, size: 18),
              label: const Text('حركة إيداع / سحب كاش', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              onPressed: () async {
                await CashDrawerActionDialog.show(
                  context,
                  onDone: () async {
                    await _refreshData();
                  },
                );
              },
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.tealAccent,
                side: BorderSide(color: Colors.teal.shade600),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.auto_fix_high_rounded, size: 16),
              label: const Text('تصحيح بأثر رجعي 🔄', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              onPressed: _isLoading ? null : () {
                SoundService.playSaveSuccess();
                _refreshData(showSuccessMessage: true);
              },
            ),
          ],
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إغلاق', style: TextStyle(color: Colors.white70, fontSize: 13)),
        ),
      ],
    );
  }

  Widget _buildRowItem(String label, double amount, Color color, {bool isPositive = false, bool isNegative = false}) {
    final prefix = isPositive && amount > 0 ? '+' : (isNegative && amount > 0 ? '-' : '');
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        Text(
          '$prefix${amount.toStringAsFixed(2)} دج',
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ],
    );
  }
}
