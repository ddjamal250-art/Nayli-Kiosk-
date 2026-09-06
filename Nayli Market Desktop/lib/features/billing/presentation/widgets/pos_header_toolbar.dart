import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/data/hive_database.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/utils/app_constants.dart';
import '../../../../core/utils/audit_log_service.dart';
import '../../../../core/utils/sound_service.dart';
import '../../../settings/presentation/pages/advanced_pos_settings_page.dart';
import '../../../product/presentation/pages/expiry_monitor_page.dart';
import 'printer_selection_dialog.dart';

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
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        children: [
          // Brand Logo with rounded container
          Container(
            width: 44,
            height: 44,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.asset(
                AppConstants.appLogoPath,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(Icons.storefront, color: Colors.teal, size: 28),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Text(
                    'Nayli Kiosk POS',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16.5, color: Color(0xFF0F172A), letterSpacing: 0.3),
                  ),
                  SizedBox(width: 6),
                  Text('🇩🇿', style: TextStyle(fontSize: 14)),
                ],
              ),
              Text(
                context.tr('pos_title'),
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(width: 20),

          // Welcome Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.teal.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.teal.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_rounded, size: 16, color: Colors.teal),
                const SizedBox(width: 6),
                Text(context.tr('pos_welcome'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.teal)),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Discreet LAN Network Sync Indicator
          Tooltip(
            message: isServerRunning ? 'LAN OK: $serverIp:8080' : 'LAN Standby',
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isServerRunning ? Colors.green.shade50 : Colors.amber.shade50,
                border: Border.all(color: isServerRunning ? Colors.green : Colors.amber),
              ),
              child: Icon(
                isServerRunning ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                size: 16,
                color: isServerRunning ? Colors.green.shade700 : Colors.amber.shade800,
              ),
            ),
          ),

          if (pendingRemoteCartsCount > 0) ...[
            const SizedBox(width: 8),
            // Incoming Remote Carts Queue Button (F9)
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
                      '${context.tr("pos_incoming_carts")}: $pendingRemoteCartsCount (F9)',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const Spacer(),

          // 1. Direct Cash Drawer Quick Kick (F10)
          IconButton(
            tooltip: '${context.tr("pos_open_drawer")} (F10)',
            icon: const Icon(Icons.account_balance_rounded, color: Colors.amber, size: 22),
            onPressed: onOpenDrawer,
          ),

          // 2. Direct Inventory Access (F4)
          IconButton(
            tooltip: '${context.tr("pos_inventory")} (F4)',
            icon: const Icon(Icons.inventory_2_outlined, color: Colors.green, size: 22),
            onPressed: () => context.push('/products'),
          ),

          // 3. Direct Supervisor Alert
          IconButton(
            tooltip: 'نداء المشرف العام للمساعدة 🔔',
            icon: const Icon(Icons.notifications_active_rounded, color: Colors.redAccent, size: 22),
            onPressed: () {
              AuditLogService.logEvent(
                action: 'supervisor_call',
                station: 'كاشير 01',
                staffName: 'الكاشير',
                details: 'طلب المشرف العام للمساعدة عند الصندوق',
              );
              SoundService.playSupervisorOverride();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('🔔 تم إرسال نداء المشرف العام! سيصلك الدعم فوراً.'),
                  backgroundColor: Colors.redAccent,
                ),
              );
            },
          ),

          // 4. Direct Fullscreen Toggle
          IconButton(
            tooltip: 'ملء الشاشة التام ⛶',
            icon: const Icon(Icons.fullscreen_rounded, color: Colors.indigo, size: 23),
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
          const VerticalDivider(indent: 14, endIndent: 14, width: 16),
          const SizedBox(width: 4),

          // 5. Business & Operations Menu Dropdown
          PopupMenuButton<String>(
            tooltip: 'إدارة المبيعات والنشاط',
            icon: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.teal.shade200),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.dashboard_customize_rounded, size: 18, color: Colors.teal.shade800),
                  const SizedBox(width: 6),
                  Text(
                    'إدارة المبيعات',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.teal.shade900),
                  ),
                  const SizedBox(width: 2),
                  Icon(Icons.arrow_drop_down, size: 18, color: Colors.teal.shade800),
                ],
              ),
            ),
            offset: const Offset(0, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            onSelected: (val) {
              switch (val) {
                case 'docs':
                  context.push('/documents');
                  break;
                case 'reports':
                  context.push('/reports');
                  break;
                case 'shifts':
                  context.push('/shifts');
                  break;
                case 'staff':
                  context.push('/staff-management');
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
              const PopupMenuItem(
                value: 'docs',
                child: Row(
                  children: [
                    Icon(Icons.description_outlined, color: Colors.teal, size: 20),
                    SizedBox(width: 10),
                    Text('المستندات والفواتير التجاريّة', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'reports',
                child: Row(
                  children: [
                    Icon(Icons.analytics_outlined, color: Colors.purple, size: 20),
                    SizedBox(width: 10),
                    Text('التقارير والإحصائيات المالية', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'shifts',
                child: Row(
                  children: [
                    Icon(Icons.badge_rounded, color: Colors.indigo, size: 20),
                    SizedBox(width: 10),
                    Text('الورديات وتقرير Z اليومي', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'staff',
                child: Row(
                  children: [
                    Icon(Icons.people_alt_rounded, color: Colors.blueGrey, size: 20),
                    SizedBox(width: 10),
                    Text('الموظفون وإدارة الرواتب (HR)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'shopping',
                child: Row(
                  children: [
                    Icon(Icons.shopping_cart_checkout, color: Colors.orange, size: 20),
                    SizedBox(width: 10),
                    Text('قائمة النواقص والتسوق 📝', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'expiry',
                child: Row(
                  children: [
                    Icon(Icons.hourglass_bottom_rounded, color: Colors.amber, size: 20),
                    SizedBox(width: 10),
                    Text('مراقبة الصلاحية والتوالف ⏳', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'catalog',
                child: Row(
                  children: [
                    Icon(Icons.library_books_rounded, color: Colors.deepOrange, size: 20),
                    SizedBox(width: 10),
                    Text('الفهرس المرجعي الجزائري 📚', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(width: 8),

          // 6. Devices & Hardware Menu Dropdown
          PopupMenuButton<String>(
            tooltip: 'الأجهزة والإعدادات',
            icon: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blueGrey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blueGrey.shade200),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.settings_outlined, size: 18, color: Colors.blueGrey.shade800),
                  const SizedBox(width: 6),
                  Text(
                    'الأجهزة والإعدادات',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey.shade900),
                  ),
                  const SizedBox(width: 2),
                  Icon(Icons.arrow_drop_down, size: 18, color: Colors.blueGrey.shade800),
                ],
              ),
            ),
            offset: const Offset(0, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            onSelected: (val) {
              switch (val) {
                case 'printers':
                  PrinterSelectionDialog.show(context);
                  break;
                case 'lan':
                  context.push('/lan-sync');
                  break;
                case 'kiosk':
                  context.push('/kiosk');
                  break;
                case 'kiosk_settings':
                  context.push('/kiosk-settings');
                  break;
                case 'advanced_pos':
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AdvancedPosSettingsPage()));
                  break;
                case 'backups':
                  context.push('/backups');
                  break;
                case 'settings':
                  context.push('/settings');
                  break;
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'printers',
                child: Row(
                  children: [
                    Icon(Icons.print_outlined, color: Colors.teal, size: 20),
                    SizedBox(width: 10),
                    Text('طابعات الفواتير والملصقات 🖨️', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'lan',
                child: Row(
                  children: [
                    Icon(Icons.wifi_tethering_rounded, color: Colors.indigo, size: 20),
                    SizedBox(width: 10),
                    Text('إدارة الشبكة والمزامنة المحلية (LAN)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'kiosk',
                child: Row(
                  children: [
                    Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF4F46E5), size: 20),
                    SizedBox(width: 10),
                    Text('كشك فاحص الأسعار للزبائن 🛍️', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'kiosk_settings',
                child: Row(
                  children: [
                    Icon(Icons.tv_rounded, color: Colors.blueGrey, size: 20),
                    SizedBox(width: 10),
                    Text('إعدادات شاشة الكشك والعروض ⚙️', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'advanced_pos',
                child: Row(
                  children: [
                    Icon(Icons.tune_rounded, color: Colors.blueGrey, size: 20),
                    SizedBox(width: 10),
                    Text('إعدادات التشغيل المتقدمة والموازين 🎛️', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'backups',
                child: Row(
                  children: [
                    Icon(Icons.cloud_sync_rounded, color: Colors.blueAccent, size: 20),
                    SizedBox(width: 10),
                    Text('النسخ الاحتياطي السحابي والمحلي', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings_suggest_rounded, color: Colors.grey, size: 20),
                    SizedBox(width: 10),
                    Text('إعدادات المتجر العامة ⚙️', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

