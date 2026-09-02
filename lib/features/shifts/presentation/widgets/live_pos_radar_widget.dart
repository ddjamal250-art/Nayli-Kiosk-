import 'package:flutter/material.dart';
import '../../../../core/utils/sound_service.dart';

class StationInfo {
  final String id;
  final String label; // 'كاشير 01', 'كاشير 02'
  final String status; // 'active', 'paused', 'closed', 'calling_supervisor'
  final String workerName;
  final double currentSales;
  final int invoicesCount;
  final DateTime? openedAt;
  final String? supervisorNote;

  StationInfo({
    required this.id,
    required this.label,
    required this.status,
    required this.workerName,
    this.currentSales = 0.0,
    this.invoicesCount = 0,
    this.openedAt,
    this.supervisorNote,
  });
}

class KioskInfo {
  final String id;
  final String name; // e.g. 'كشك 01 (جناح المشروبات)'
  final String status; // 'online', 'idle'
  final int totalScans;
  final String ip;

  KioskInfo({
    required this.id,
    required this.name,
    this.status = 'online',
    this.totalScans = 0,
    this.ip = '',
  });
}

class LivePosRadarWidget extends StatelessWidget {
  final List<StationInfo> stations;
  final List<KioskInfo> kiosks;
  final VoidCallback? onRefresh;

  const LivePosRadarWidget({
    super.key,
    required this.stations,
    this.kiosks = const [],
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.radar_rounded, color: Colors.teal, size: 26),
                    SizedBox(width: 10),
                    Text(
                      'رادار الشبكة والمزامنة الحية (Live POS & Kiosk Cockpit)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                if (onRefresh != null)
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: Colors.teal),
                    onPressed: onRefresh,
                    tooltip: 'تحديث الرادار',
                  ),
              ],
            ),
            const SizedBox(height: 14),

            // SECTION 1: CASHIER REGISTERS (الكاشيرات المالية والصناديق)
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.teal.shade300),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.point_of_sale_rounded, color: Colors.teal, size: 16),
                      SizedBox(width: 6),
                      Text('صناديق الكاشير المالية (POS Registers)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Colors.teal)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text('(${stations.where((s) => s.status == "active").length} نشط من ${stations.length})',
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 10),

            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 700;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: isWide ? 5 : 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: isWide ? 1.05 : 1.3,
                  ),
                  itemCount: stations.length,
                  itemBuilder: (context, index) {
                    return _buildStationCard(context, stations[index]);
                  },
                );
              },
            ),

            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // SECTION 2: CUSTOMER PRICE CHECKER KIOSKS (أكشاك فحص الأسعار للزبائن - مجانية وغير محدودة)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.indigo.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.indigo.shade300),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.tv_rounded, color: Colors.indigo, size: 16),
                          SizedBox(width: 6),
                          Text('أكشاك فاحص الأسعار للزبائن (Customer Kiosks)',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Colors.indigo)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('غير محدودة ومجانية 🛍️',
                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.green)),
                    ),
                  ],
                ),
                Text('عدد الأكشاك المتصلة: ${kiosks.length}',
                    style: TextStyle(fontSize: 11.5, color: Colors.indigo.shade900, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 10),

            if (kiosks.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300, width: 1.2),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.grey, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'لا توجد أكشاك فحص أسعار متصلة حالياً. يمكنك تثبيت البرنامج ككشك زبائن على أي تابلت أو شاشة في ممرات السوبرماركت وسيتصل فوراً بدون استهلاك رخص الكاشير.',
                        style: TextStyle(color: Colors.grey, fontSize: 11.5),
                      ),
                    ),
                  ],
                ),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 700;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: isWide ? 4 : 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: isWide ? 1.6 : 1.4,
                    ),
                    itemCount: kiosks.length,
                    itemBuilder: (context, index) {
                      return _buildKioskCard(context, kiosks[index]);
                    },
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStationCard(BuildContext context, StationInfo s) {
    Color cardColor;
    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (s.status == 'calling_supervisor') {
      cardColor = Colors.red.shade50;
      statusColor = Colors.red;
      statusText = 'نداء المشرف 🔔';
      statusIcon = Icons.notifications_active_rounded;
    } else if (s.status == 'active') {
      cardColor = Colors.green.shade50;
      statusColor = Colors.green.shade800;
      statusText = 'نشط وأونلاين';
      statusIcon = Icons.check_circle_rounded;
    } else if (s.status == 'paused') {
      cardColor = Colors.amber.shade50;
      statusColor = Colors.amber.shade900;
      statusText = 'استراحة ⏸️';
      statusIcon = Icons.pause_circle_filled_rounded;
    } else {
      cardColor = Colors.grey.shade100;
      statusColor = Colors.grey.shade700;
      statusText = 'مغلق ⏹️';
      statusIcon = Icons.do_not_disturb_on_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.4), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(s.label, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
              Icon(statusIcon, color: statusColor, size: 18),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.workerName.isEmpty ? 'لا يوجد كاشير' : s.workerName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(statusText, style: TextStyle(color: statusColor, fontSize: 10.5, fontWeight: FontWeight.bold)),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${s.currentSales.toStringAsFixed(0)} دج',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.teal.shade900)),
              Text('${s.invoicesCount} وصل', style: const TextStyle(color: Colors.grey, fontSize: 10.5)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKioskCard(BuildContext context, KioskInfo k) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF818CF8).withOpacity(0.5), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  k.name,
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFF312E81)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.check_circle_rounded, color: Colors.green, size: 16),
            ],
          ),
          Row(
            children: [
              const Icon(Icons.qr_code_scanner_rounded, size: 15, color: Color(0xFF4F46E5)),
              const SizedBox(width: 6),
              Text('${k.totalScans} استعلام سعر',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Color(0xFF4F46E5))),
            ],
          ),
          Text(k.ip.isEmpty ? 'شبكة محلية' : 'IP: ${k.ip}',
              style: const TextStyle(color: Colors.grey, fontSize: 10)),
        ],
      ),
    );
  }
}
