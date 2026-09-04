import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:window_manager/window_manager.dart';

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
                    'Nayli Market POS',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16.5, color: Color(0xFF0F172A), letterSpacing: 0.3),
                  ),
                  SizedBox(width: 6),
                  Text('', style: TextStyle(fontSize: 14)),
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

          // Cash Drawer Quick Kick (F10)
          IconButton(
            tooltip: context.tr('pos_open_drawer'),
            icon: const Icon(Icons.account_balance_rounded, color: Colors.amber, size: 22),
            onPressed: onOpenDrawer,
          ),

          // Navigation Shortcuts
          IconButton(
            tooltip: context.tr('pos_commercial_docs'),
            icon: const Icon(Icons.description_outlined, color: Colors.teal),
            onPressed: () => context.push('/documents'),
          ),
          IconButton(
            tooltip: context.tr('pos_backup_sync'),
            icon: const Icon(Icons.cloud_sync_rounded, color: Colors.blueAccent),
            onPressed: () => context.push('/backups'),
          ),
          IconButton(
            tooltip: context.tr('pos_shifts_zreport'),
            icon: const Icon(Icons.badge_rounded, color: Colors.indigo),
            onPressed: () => context.push('/shifts'),
          ),
          IconButton(
            tooltip: 'إدارة الموارد البشرية والرواتب (HR & Paie)',
            icon: const Icon(Icons.people_alt_rounded, color: Colors.teal),
            onPressed: () => context.push('/staff-management'),
          ),
          IconButton(
            tooltip: 'نداء المشرف العام للمساعدة 🔔',
            icon: const Icon(Icons.notifications_active_rounded, color: Colors.redAccent),
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
          IconButton(
            tooltip: context.tr('pos_master_catalog'),
            icon: const Icon(Icons.library_books_rounded, color: Colors.deepOrange),
            onPressed: () => context.push('/master-catalog'),
          ),
          IconButton(
            tooltip: context.tr('pos_inventory'),
            icon: const Icon(Icons.inventory_2_outlined, color: Colors.green),
            onPressed: () => context.push('/products'),
          ),
          IconButton(
            tooltip: context.tr('pos_reports'),
            icon: const Icon(Icons.analytics_outlined, color: Colors.purple),
            onPressed: () => context.push('/reports'),
          ),
          IconButton(
            tooltip: 'طابعات ويندوز (الوصولات والمستندات)',
            icon: const Icon(Icons.print_outlined, color: Colors.teal),
            onPressed: () => PrinterSelectionDialog.show(context),
          ),
          IconButton(
            tooltip: 'إدارة الشبكة والمزامنة المحلية (LAN & Wi-Fi)',
            icon: const Icon(Icons.wifi_tethering_rounded, color: Colors.indigo),
            onPressed: () => context.push('/lan-sync'),
          ),
          IconButton(
            tooltip: 'كشك فاحص الأسعار للزبائن 🛍️',
            icon: const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF4F46E5)),
            onPressed: () => context.push('/kiosk'),
          ),
          IconButton(
            tooltip: 'إعدادات كشك الأسعار والعروض ⚙️',
            icon: const Icon(Icons.tv_rounded, color: Colors.blueGrey),
            onPressed: () => context.push('/kiosk-settings'),
          ),
          IconButton(
            tooltip: 'مراقبة الصلاحية والتوالف ⏳',
            icon: const Icon(Icons.hourglass_bottom_rounded, color: Colors.amber),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExpiryMonitorPage())),
          ),
          IconButton(
            tooltip: 'إعدادات التشغيل المتقدمة والموازين 🎛️',
            icon: const Icon(Icons.tune_rounded, color: Colors.blueGrey),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdvancedPosSettingsPage())),
          ),
          IconButton(
            tooltip: 'ملء الشاشة التام (Plein Écran) ⛶',
            icon: const Icon(Icons.fullscreen_rounded, color: Colors.cyanAccent, size: 24),
            onPressed: () async {
              bool isFull = false;
              if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
                isFull = await windowManager.isMaximized();
              } else {
                isFull = HiveDatabase.settingsBox.get('is_app_fullscreen', defaultValue: false) == true;
              }

              if (isFull) {
                if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
                  await windowManager.unmaximize();
                } else {
                  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
                }
                HiveDatabase.settingsBox.put('is_app_fullscreen', false);
              } else {
                if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
                  await windowManager.maximize();
                } else {
                  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
                }
                HiveDatabase.settingsBox.put('is_app_fullscreen', true);
              }
              SoundService.playKeyTap();
            },
          ),
          IconButton(
            tooltip: context.tr('pos_settings'),
            icon: const Icon(Icons.settings_outlined, color: Colors.grey),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
    );
  }
}

