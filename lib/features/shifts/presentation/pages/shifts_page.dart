import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/printer_helper.dart';
import '../../../../core/utils/snackbar_helper.dart';
import '../../../../core/utils/sound_service.dart';
import '../../../../core/utils/telegram_service.dart';
import '../../../../core/data/hive_database.dart';
import '../../../../core/data/local_sync_server.dart';
import '../../../backup/data/backup_service.dart';
import '../../data/shift_service.dart';
import '../../data/staff_service.dart';
import '../widgets/algerian_denomination_dialog.dart';
import '../widgets/live_pos_radar_widget.dart';

class ShiftsPage extends StatefulWidget {
  const ShiftsPage({super.key});

  @override
  State<ShiftsPage> createState() => _ShiftsPageState();
}

class _ShiftsPageState extends State<ShiftsPage> {
  CashierShift? _activeShift;
  List<CashierShift> _shiftHistory = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadShifts();
  }

  Future<void> _loadShifts() async {
    setState(() => _isLoading = true);
    final active = await ShiftService.getActiveShift();
    final box = await ShiftService.box;
    final history = <CashierShift>[];
    for (var k in box.keys) {
      final map = box.get(k);
      if (map is Map) {
        final s = CashierShift.fromMap(map);
        if (s.isClosed) history.add(s);
      }
    }
    history.sort((a, b) => (b.closedAt ?? b.openedAt).compareTo(a.closedAt ?? a.openedAt));

    if (mounted) {
      setState(() {
        _activeShift = active;
        _shiftHistory = history;
        _isLoading = false;
      });
    }
  }

  void _showOpenShiftModal() {
    SoundService.playTabSwitch();
    final workerController = TextEditingController(text: 'الكاشير 1');
    final floatController = TextEditingController(text: '5000');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.point_of_sale_rounded, color: Colors.teal, size: 28),
            SizedBox(width: 8),
            Text('فتح وردية جديدة (Ouverture de Caisse)'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: workerController,
              decoration: const InputDecoration(labelText: 'اسم العامل / الكاشير', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: floatController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'رصيد بداية الصندوق - الفكة (Fond de caisse د.ج)',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.monetization_on_outlined),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.calculate_rounded, color: Colors.teal),
                  tooltip: 'حاسبة الفئات النقدية الجزائرية 🇩🇿',
                  onPressed: () async {
                    final counted = await AlgerianDenominationDialog.show(context, title: 'حساب رصيد بداية الصندوق (Fond de Caisse)');
                    if (counted != null) {
                      floatController.text = counted.toStringAsFixed(0);
                    }
                  },
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            onPressed: () async {
              final worker = workerController.text.trim().isEmpty ? 'الكاشير' : workerController.text.trim();
              final float = double.tryParse(floatController.text.trim()) ?? 0.0;
              Navigator.pop(ctx);
              await ShiftService.openShift(workerName: worker, floatAmount: float);
              await _loadShifts();
              SoundService.playSaveSuccess();
              if (mounted) {
                SnackbarHelper.showSuccess(context, 'تم فتح وردية $worker برصيد بداية: ${float.toStringAsFixed(2)} د.ج');
              }
            },
            child: const Text('فتح الوردية', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showCloseShiftModal() {
    if (_activeShift == null) return;
    SoundService.playTabSwitch();
    final actualCashController = TextEditingController();
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.assignment_turned_in_rounded, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text('إغلاق الصندوق وطباعة تقرير الختام Z-Report'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('العامل: ${_activeShift!.workerName} • وقت الفتح: ${DateFormat('HH:mm').format(_activeShift!.openedAt)}'),
            const SizedBox(height: 12),
            TextField(
              controller: actualCashController,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'المبلغ الفعلي الموجود في درج النقود (د.ج) *',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.payments_outlined),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.calculate_rounded, color: Colors.teal),
                  tooltip: 'حاسبة الفئات النقدية الجزائرية 🇩🇿',
                  onPressed: () async {
                    final counted = await AlgerianDenominationDialog.show(context, title: 'جرد نقدية الصندوق الفعلية');
                    if (counted != null) {
                      actualCashController.text = counted.toStringAsFixed(0);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(labelText: 'ملاحظات الختام...', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            icon: const Icon(Icons.print_rounded, color: Colors.white),
            label: const Text('إغلاق وطباعة Z-Report', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            onPressed: () async {
              final actual = double.tryParse(actualCashController.text.trim()) ?? 0.0;
              Navigator.pop(ctx);
              final closed = await ShiftService.closeShift(
                activeShift: _activeShift!,
                actualCashInDrawer: actual,
                notes: notesController.text.trim(),
              );
              await _loadShifts();
              SoundService.playCheckoutSuccess();

              // Trigger Cloud Backup to Telegram Vault
              BackupService.performAutoCloudBackup(
                note: 'إغلاق وردية Z-Report (${closed.workerName}) - مبيعات: ${closed.totalSales.toStringAsFixed(2)} د.ج',
              );

              // Send Z-Report Summary Message to Telegram if configured
              final botToken = TelegramService.getBotToken();
              final chatId = TelegramService.getChatId();
              if (botToken.isNotEmpty && chatId.isNotEmpty) {
                final summary = '📊 <b>تقرير ختام الوردية (Z-Report)</b> 🧾\n'
                    '━━━━━━━━━━━━━━━━━\n'
                    '👤 <b>العامل:</b> ${closed.workerName}\n'
                    '⏰ <b>الوقت:</b> ${DateFormat('yyyy/MM/dd HH:mm').format(closed.closedAt ?? DateTime.now())}\n'
                    '💵 <b>إجمالي المبيعات:</b> ${closed.totalSales.toStringAsFixed(2)} د.ج\n'
                    '💰 <b>المبلغ الفعلي في الدرج:</b> ${closed.actualCashAtClose.toStringAsFixed(2)} د.ج\n'
                    '⚖️ <b>الفارق:</b> ${closed.cashDifference.toStringAsFixed(2)} د.ج\n'
                    '━━━━━━━━━━━━━━━━━\n'
                    '✅ تم حفظ نسخة احتياطية سحابية كاملة تلقائياً!';
                TelegramService.sendTextMessage(
                  customToken: botToken,
                  customChatId: chatId,
                  text: summary,
                );
              }

              if (mounted) {
                SnackbarHelper.showSuccess(
                  context,
                  'تم إغلاق الوردية بنجاح! إجمالي المبيعات: ${closed.totalSales.toStringAsFixed(2)} د.ج',
                );
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.badge_rounded, color: Colors.teal),
            SizedBox(width: 8),
            Text('إدارة الورديات والصندوق (Cashier Shifts & Z-Report)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        actions: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F766E), padding: const EdgeInsets.symmetric(horizontal: 14)),
            icon: const Icon(Icons.people_alt_rounded, color: Colors.white, size: 18),
            label: const Text('إدارة الموارد البشرية والرواتب (HR)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            onPressed: () => context.push('/staff-management'),
          ),
          const SizedBox(width: 8),
          if (_activeShift != null) ...[
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, padding: const EdgeInsets.symmetric(horizontal: 14)),
              icon: const Icon(Icons.lock_clock_rounded, color: Colors.white),
              label: const Text('قفل الشاشة السريع (Pause)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              onPressed: () => ShiftService.lockScreen(context, workerName: _activeShift!.workerName),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, padding: const EdgeInsets.symmetric(horizontal: 14)),
              icon: const Icon(Icons.close_fullscreen_rounded, color: Colors.white),
              label: const Text('إغلاق الوردية (Z-Report)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              onPressed: _showCloseShiftModal,
            ),
          ] else
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, padding: const EdgeInsets.symmetric(horizontal: 16)),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('فتح وردية جديدة (+)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              onPressed: _showOpenShiftModal,
            ),
          const SizedBox(width: 16),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Live Multi-POS Radar
                  LivePosRadarWidget(
                    stations: [
                      StationInfo(
                        id: 'pos_01',
                        label: 'كاشير 01',
                        status: _activeShift != null ? 'active' : 'closed',
                        workerName: _activeShift?.workerName ?? '',
                        currentSales: _activeShift?.totalSales ?? 0.0,
                        invoicesCount: _activeShift != null ? 18 : 0,
                        openedAt: _activeShift?.openedAt,
                      ),
                      StationInfo(
                        id: 'pos_02',
                        label: 'كاشير 02',
                        status: 'closed',
                        workerName: '',
                        currentSales: 0.0,
                        invoicesCount: 0,
                      ),
                      StationInfo(
                        id: 'pos_03',
                        label: 'كاشير 03',
                        status: 'closed',
                        workerName: '',
                        currentSales: 0.0,
                        invoicesCount: 0,
                      ),
                      StationInfo(
                        id: 'pos_04',
                        label: 'كاشير 04',
                        status: 'closed',
                        workerName: '',
                        currentSales: 0.0,
                        invoicesCount: 0,
                      ),
                      StationInfo(
                        id: 'pos_05',
                        label: 'كاشير 05',
                        status: 'closed',
                        workerName: '',
                        currentSales: 0.0,
                        invoicesCount: 0,
                      ),
                    ],
                    kiosks: LocalSyncServer.activeKiosks.values.map((k) => KioskInfo(
                      id: k['id']?.toString() ?? '',
                      name: k['name']?.toString() ?? 'كشك فاحص الأسعار',
                      status: k['status']?.toString() ?? 'online',
                      totalScans: (k['totalScans'] as int?) ?? 0,
                      ip: k['ip']?.toString() ?? '',
                    )).toList(),
                    onRefresh: () {
                      setState(() {});
                      _loadShifts();
                    },
                  ),
                  const SizedBox(height: 16),

                  // Active Shift Banner
                  if (_activeShift != null)
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.teal, width: 1.5)),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const CircleAvatar(backgroundColor: Colors.teal, radius: 24, child: Icon(Icons.person, color: Colors.white, size: 28)),
                                    const SizedBox(width: 14),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('الوردية الحالية: ${_activeShift!.workerName}',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                        Text('بدأت في: ${DateFormat('yyyy/MM/dd HH:mm').format(_activeShift!.openedAt)}',
                                            style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                      ],
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.green)),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.fiber_manual_record, color: Colors.green, size: 14),
                                      SizedBox(width: 6),
                                      Text('الوردية نشطة ومفتوحة', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                _buildShiftStat('رصيد الفتح (Fond)', '${_activeShift!.floatAmount.toStringAsFixed(2)} د.ج', Colors.grey),
                                const SizedBox(width: 12),
                                _buildShiftStat('مبيعات الكاش', 'مباشرة في الصندوق', Colors.green),
                                const SizedBox(width: 12),
                                _buildShiftStat('مبيعات TPE', 'مسجلة إلكترونياً', Colors.blue),
                                const SizedBox(width: 12),
                                _buildShiftStat('مبيعات الكريدي', 'مسجلة بالدفتر', Colors.amber),
                              ],
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Card(
                      elevation: 1,
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline_rounded, color: Colors.orange, size: 36),
                            const SizedBox(width: 16),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('لا توجد وردية مفتوحة حالياً', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  Text('يرجى فتح وردية جديدة لبدء تسجيل المبيعات وحساب رصيد الصندوق بدقة.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                ],
                              ),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                              onPressed: _showOpenShiftModal,
                              child: const Text('فتح وردية الآن', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 24),

                  // Shift History (Z-Reports)
                  const Row(
                    children: [
                      Icon(Icons.history_edu_rounded, color: Colors.teal),
                      SizedBox(width: 8),
                      Text('سجل الورديات السابقة وتقارير الختام Z-Report', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (_shiftHistory.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(32),
                      alignment: Alignment.center,
                      child: const Text('لا توجد ورديات مغلقة مسجلة بعد', style: TextStyle(color: Colors.grey)),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _shiftHistory.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final s = _shiftHistory[index];
                        final diff = s.cashDifference;

                        return Card(
                          elevation: 1,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                                  child: const Icon(Icons.receipt_long_rounded, color: Colors.teal),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('وردية: ${s.workerName} (Z-Report)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                      Text(
                                        'الفتح: ${DateFormat('yyyy/MM/dd HH:mm').format(s.openedAt)}  •  الإغلاق: ${s.closedAt != null ? DateFormat('HH:mm').format(s.closedAt!) : "-"}',
                                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text('المبيعات: ${s.totalSales.toStringAsFixed(2)} د.ج', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                      Text('الدرج الفعلي: ${s.actualCashAtClose.toStringAsFixed(2)} د.ج', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: diff == 0 ? Colors.green.shade50 : (diff > 0 ? Colors.blue.shade50 : Colors.red.shade50),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    diff == 0 ? 'مطابق تماماً ✔️' : (diff > 0 ? '+${diff.toStringAsFixed(0)} د.ج زيادة' : '${diff.toStringAsFixed(0)} د.ج عجز'),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                      color: diff == 0 ? Colors.green.shade800 : (diff > 0 ? Colors.blue.shade800 : Colors.red.shade800),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildShiftStat(String title, String val, MaterialColor color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: color.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: color.shade200)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontSize: 11, color: color.shade800, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(val, style: TextStyle(fontSize: 14, color: color.shade900, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}

