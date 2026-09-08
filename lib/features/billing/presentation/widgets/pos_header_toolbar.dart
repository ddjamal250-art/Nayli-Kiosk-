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

class PosHeaderToolbar extends StatelessWidget {
  final bool isServerRunning;
  final String serverIp;
  final int pendingRemoteCartsCount;
  final VoidCallback onOpenDrawer;
  final VoidCallback onShowRemoteCartsQueue;

  const PosHeaderToolbar({
    super.key,
    required this.isServerRunning,
    required this.serverIp,
    required this.pendingRemoteCartsCount,
    required this.onOpenDrawer,
    required this.onShowRemoteCartsQueue,
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
                        'Nayli Kiosk POS',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16.5,
                          color: textColor,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text('🇩🇿', style: TextStyle(fontSize: 14)),
                    ],
                  ),
                  Text(
                    context.tr('pos_title'),
                    style: TextStyle(
                      fontSize: 11,
                      color: subtextColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 18),

              // Welcome Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: headerState.accentColor.withOpacity(isDarkHeader ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: headerState.accentColor.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.verified_rounded, size: 16, color: headerState.accentColor),
                    const SizedBox(width: 6),
                    Text(
                      context.tr('pos_welcome'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDarkHeader ? Colors.white : headerState.accentColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // Discreet LAN Network Sync Indicator
              Tooltip(
                message: isServerRunning ? 'LAN OK: ' : 'LAN Standby',
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isServerRunning ? Colors.green.withOpacity(0.2) : Colors.amber.withOpacity(0.2),
                    border: Border.all(color: isServerRunning ? Colors.green : Colors.amber),
                  ),
                  child: Icon(
                    isServerRunning ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                    size: 16,
                    color: isServerRunning ? Colors.greenAccent : Colors.amber,
                  ),
                ),
              ),

              if (pendingRemoteCartsCount > 0) ...[
                const SizedBox(width: 8),
                InkWell(
                  onTap: onShowRemoteCartsQueue,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.indigo,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.phonelink_ring_rounded, size: 16, color: Colors.white),
                        const SizedBox(width: 6),
                        Text(
                          'طلبات عن بعد: $pendingRemoteCartsCount (F9)',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const Spacer(),

              // Quick Actions Toolbar Buttons

              // 0. Session Pause (Break Mode) Quick Button
              Tooltip(
                message: Localizations.localeOf(context).languageCode == 'ar'
                    ? 'إيقاف مؤقت للجلسة / استراحة (Pause/Break)'
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
                tooltip: 'درج النقود (F10)',
                icon: const Icon(Icons.account_balance_rounded, color: Colors.amber, size: 22),
                onPressed: onOpenDrawer,
              ),

              // 2. Direct Inventory Access (F4)
              IconButton(
                tooltip: 'إدارة المخزون (F4)',
                icon: Icon(Icons.inventory_2_outlined, color: isDarkHeader ? Colors.lightGreenAccent : Colors.green, size: 22),
                onPressed: () => context.push('/products'),
              ),

              // 3. Theme Toggle (AMOLED Dark / Light)
              BlocBuilder<ThemeCubit, ThemeMode>(
                builder: (context, themeMode) {
                  final isAmoled = themeMode == ThemeMode.dark;
                  return IconButton(
                    tooltip: context.tr('switch_theme_tooltip'),
                    icon: Icon(
                      isAmoled ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                      color: isAmoled ? Colors.amber : (isDarkHeader ? Colors.white : const Color(0xFF475569)),
                      size: 22,
                    ),
                    onPressed: () => context.read<ThemeCubit>().toggleTheme(),
                  );
                },
              ),

              // 4. Custom Header Palette Button
              IconButton(
                tooltip: context.tr('color_palette_tooltip'),
                icon: Icon(
                  Icons.palette_rounded,
                  color: headerState.accentColor,
                  size: 22,
                ),
                onPressed: () => HeaderColorDialog.show(context),
              ),

              // 5. Language Switcher (AR / FR / EN)
              PopupMenuButton<String>(
                tooltip: context.tr('language'),
                icon: Icon(
                  Icons.language_rounded,
                  color: isDarkHeader ? Colors.white : const Color(0xFF0F172A),
                  size: 22,
                ),
                offset: const Offset(0, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                onSelected: (code) => context.read<LanguageCubit>().setLanguage(code),
                itemBuilder: (ctx) => [
                  PopupMenuItem(
                    value: 'ar',
                    child: Row(
                      children: [
                        const Text('🇩🇿', style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                        Text(context.tr('arabic'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'fr',
                    child: Row(
                      children: [
                        const Text('🇫🇷', style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                        Text(context.tr('french'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'en',
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

              // 6. Direct Fullscreen Toggle (F11)
              IconButton(
                tooltip: 'ملء الشاشة (F11)',
                icon: Icon(Icons.fullscreen_rounded, color: isDarkHeader ? Colors.white70 : Colors.indigo, size: 23),
                onPressed: () {
                  final isFull = HiveDatabase.settingsBox.get('is_app_fullscreen', defaultValue: false) == true;
                  if (isFull) {
                    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
                    HiveDatabase.settingsBox.put('is_app_fullscreen', false);
                  } else {
                    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
                    HiveDatabase.settingsBox.put('is_app_fullscreen', true);
                  }
                  SoundService.playKeyTap();
                },
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
                    case 'catalog':
                      context.push('/master-catalog');
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
                    value: 'catalog',
                    child: Row(
                      children: [
                        const Icon(Icons.library_books_rounded, color: Colors.deepOrange, size: 20),
                        const SizedBox(width: 10),
                        Text(context.tr('master_catalog_btn'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
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
                  Icons.settings_suggest_rounded,
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
