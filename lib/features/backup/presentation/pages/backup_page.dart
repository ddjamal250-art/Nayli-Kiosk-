import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/data/hive_database.dart';
import '../../../../core/utils/snackbar_helper.dart';
import '../../../../core/utils/sound_service.dart';
import '../../../../core/utils/telegram_service.dart';
import '../../data/backup_service.dart';

class BackupPage extends StatefulWidget {
  const BackupPage({super.key});

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  List<BackupSnapshotInfo> _backups = [];
  bool _isLoading = true;

  // Telegram & WhatsApp Settings
  final TextEditingController _telegramTokenController = TextEditingController();
  final TextEditingController _telegramChatIdController = TextEditingController();
  final TextEditingController _whatsAppPhoneController = TextEditingController();
  bool _autoBackupOnShiftClose = true;
  bool _isDiscoveringChatId = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadBackups();
  }

  @override
  void dispose() {
    _telegramTokenController.dispose();
    _telegramChatIdController.dispose();
    _whatsAppPhoneController.dispose();
    super.dispose();
  }

  void _loadSettings() {
    final box = HiveDatabase.settingsBox;
    _telegramTokenController.text = box.get('telegram_bot_token', defaultValue: '');
    _telegramChatIdController.text = box.get('telegram_chat_id', defaultValue: '');
    _whatsAppPhoneController.text = box.get('merchant_whatsapp_phone', defaultValue: '');
    _autoBackupOnShiftClose = box.get('auto_backup_on_shift_close', defaultValue: true);
  }

  Future<void> _saveSettings() async {
    final box = HiveDatabase.settingsBox;
    await box.put('telegram_bot_token', _telegramTokenController.text.trim());
    await box.put('telegram_chat_id', _telegramChatIdController.text.trim());
    await box.put('merchant_whatsapp_phone', _whatsAppPhoneController.text.trim());
    await box.put('auto_backup_on_shift_close', _autoBackupOnShiftClose);
    SoundService.playSaveSuccess();
    if (mounted) {
      SnackbarHelper.showSuccess(context, '✅ تم حفظ إعدادات التيليجرام والواتساب بنجاح');
    }
  }

  Future<void> _autoDiscoverTelegramChatId() async {
    setState(() => _isDiscoveringChatId = true);
    SoundService.playTabSwitch();

    // 1. فتح رابط البوت للتاجر
    await TelegramService.launchBotChat();

    if (mounted) {
      SnackbarHelper.showInfo(
        context,
        '⏳ جاري كشف معرفك... يرجى الضغط على Start أو إرسال أي رسالة للبوت في التلغرام الآن',
      );
    }

    // 2. محاولة جلب التحديثات لعدة ثوانٍ
    Map<String, dynamic>? discovered;
    for (int attempt = 0; attempt < 5; attempt++) {
      await Future.delayed(const Duration(seconds: 2));
      discovered = await TelegramService.autoDiscoverChatId(
        customToken: _telegramTokenController.text.trim(),
      );
      if (discovered != null) break;
    }

    if (mounted) {
      setState(() => _isDiscoveringChatId = false);
      if (discovered != null) {
        _telegramChatIdController.text = discovered['chatId']?.toString() ?? '';
        await _saveSettings();
        SoundService.playCheckoutSuccess();
        SnackbarHelper.showSuccess(
          context,
          '🎉 رائع! تم كشف وربط التيليجرام بنجاح: ' +
              (discovered['name']?.toString() ?? '') +
              ' (ID: ' +
              (discovered['chatId']?.toString() ?? '') +
              ')',
        );
      } else {
        SoundService.playWarning();
        SnackbarHelper.showWarning(
          context,
          '⚠️ لم نتمكن من كشف الرسالة بعد. تأكد من فتح البوت والضغط على Start ثم حاول مجدداً',
        );
      }
    }
  }

  Future<void> _sendTestTelegramMessage() async {
    final chatId = _telegramChatIdController.text.trim();
    if (chatId.isEmpty) {
      SnackbarHelper.showWarning(context, 'يرجى تحديد أو كشف Chat ID أولاً');
      return;
    }

    final sent = await TelegramService.sendTextMessage(
      text: '🔔 <b>نايل ماركت POS</b>\n\n'
          '✅ تهانينا! تم ربط برنامج المحل بحسابك على تلغرام بنجاح.\n'
          '📅 التاريخ: ' +
          DateFormat('yyyy/MM/dd HH:mm').format(DateTime.now()),
      customToken: _telegramTokenController.text.trim(),
      customChatId: chatId,
    );

    if (mounted) {
      if (sent) {
        SoundService.playCheckoutSuccess();
        SnackbarHelper.showSuccess(context, '✅ تم إرسال الرسالة التجريبية إلى تلغرامك بنجاح!');
      } else {
        SoundService.playVoidWarning();
        SnackbarHelper.showError(context, '❌ تعذر الإرسال. تأكد من اتصال الإنترنت وصحة المعرف');
      }
    }
  }

  Future<void> _sendTestWhatsAppMessage() async {
    final phone = _whatsAppPhoneController.text.trim();
    if (phone.isEmpty) {
      SnackbarHelper.showWarning(context, 'يرجى إدخال رقم هاتف الواتساب أولاً (مثال: 0661xxxxxx)');
      return;
    }

    final now = DateTime.now();
    final sampleMessage = '🏪 *نايل ماركت - تقرير تجريبي مباشر* 📊\n\n'
        '📅 التاريخ: ' +
        DateFormat('yyyy/MM/dd HH:mm').format(now) +
        '\n'
        '💵 إجمالي مبيعات اليوم: 45,800.00 دج\n'
        '🧾 عدد الزبائن: 34 زبون\n'
        '💳 مدفوعات TPE: 12,000.00 دج\n'
        '💾 تم أخذ نسخة احتياطية سحابية بنجاح ✅\n\n'
        'Nayli Market POS 🇩🇿';

    final launched = await TelegramService.sendWhatsAppReport(
      phone: phone,
      message: sampleMessage,
    );

    if (mounted) {
      if (launched) {
        SoundService.playSaveSuccess();
        SnackbarHelper.showSuccess(context, '✅ تم فتح واتساب لإرسال التقرير');
      } else {
        SnackbarHelper.showError(context, 'تعذر فتح واتساب، تأكد من تثبيته على الجهاز');
      }
    }
  }

  Future<void> _loadBackups() async {
    setState(() => _isLoading = true);
    final list = await BackupService.listLocalBackups();
    if (mounted) {
      setState(() {
        _backups = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleCreateBackup() async {
    SoundService.playTabSwitch();
    setState(() => _isLoading = true);
    try {
      final file = await BackupService.createFullBackupZip();
      SoundService.playSaveSuccess();

      // Check telegram sending if enabled
      final token = TelegramService.getBotToken();
      final chatId = TelegramService.getChatId();
      if (token.isNotEmpty && chatId.isNotEmpty) {
        await BackupService.sendToTelegramBot(
          backupFile: file,
          botToken: token,
          chatId: chatId,
        );
      }

      await _loadBackups();
      if (mounted) {
        SnackbarHelper.showSuccess(context, '✅ تم إنشاء وحفظ النسخة الاحتياطية بنجاح!');
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'فشل إنشاء النسخة الاحتياطية: ' + e.toString());
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 700;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isWide ? 'النسخ الاحتياطي والمزامنة السحابية ☁️' : 'النسخ الاحتياطي ☁️',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadBackups,
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Quick Action Button
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF0F766E), Color(0xFF14B8A6)]),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: isWide
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('إنشاء نسخة احتياطية محلية وسحابية فورية',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                SizedBox(height: 4),
                                Text('تجميع كافة المنتجات، الفواتير، ديون الزبائن وسندات الموردين في ملف واحد مضغوط',
                                    style: TextStyle(color: Colors.white70, fontSize: 12)),
                              ],
                            ),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFF0F766E),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.save_rounded),
                              label: const Text('أخذ نسخة الآن', style: TextStyle(fontWeight: FontWeight.bold)),
                              onPressed: _handleCreateBackup,
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text('إنشاء نسخة احتياطية محلية وسحابية',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                            const SizedBox(height: 4),
                            const Text('تجميع كافة المنتجات، الفواتير، ديون الزبائن وسندات الموردين في ملف واحد',
                                style: TextStyle(color: Colors.white70, fontSize: 11.5)),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFF0F766E),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.save_rounded),
                              label: const Text('أخذ نسخة الآن', style: TextStyle(fontWeight: FontWeight.bold)),
                              onPressed: _handleCreateBackup,
                            ),
                          ],
                        ),
                ),

                const SizedBox(height: 20),

                // بطاقة ربط التلغرام الذكية بكشف تلقائي بنقرة واحدة
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isWide)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.send_rounded, color: Colors.blueAccent, size: 24),
                                  SizedBox(width: 8),
                                  Text('1. النسخ السحابي والتقارير عبر Telegram 🤖',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                ],
                              ),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(foregroundColor: Colors.blueAccent),
                                icon: _isDiscoveringChatId
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Icon(Icons.auto_awesome, size: 16),
                                label: Text(
                                  _isDiscoveringChatId ? 'جاري الكشف...' : 'كشف معرفي تلقائياً 🔍',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                                onPressed: _isDiscoveringChatId ? null : _autoDiscoverTelegramChatId,
                              ),
                            ],
                          )
                        else
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.send_rounded, color: Colors.blueAccent, size: 22),
                                  SizedBox(width: 8),
                                  Text('1. النسخ عبر Telegram 🤖',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(foregroundColor: Colors.blueAccent),
                                icon: _isDiscoveringChatId
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Icon(Icons.auto_awesome, size: 16),
                                label: Text(
                                  _isDiscoveringChatId ? 'جاري الكشف...' : 'كشف معرفي تلقائياً 🔍',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                                onPressed: _isDiscoveringChatId ? null : _autoDiscoverTelegramChatId,
                              ),
                            ],
                          ),
                        const SizedBox(height: 6),
                        const Text(
                          '💡 لا تحتاج لإنشاء بوت بنفسك! فقط اضغط زر (كشف معرفي تلقائياً) وافتح البوت واضغط Start ليرتبط البرنامج بهاتفك في ثانية واحدة:',
                          style: TextStyle(fontSize: 12, color: Colors.black87),
                        ),
                        const SizedBox(height: 14),

                        // Simplified UI for Telegram Status
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: _telegramChatIdController.text.isNotEmpty ? Colors.green.shade50 : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: _telegramChatIdController.text.isNotEmpty ? Colors.green.shade200 : Colors.grey.shade300),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _telegramChatIdController.text.isNotEmpty ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                                color: _telegramChatIdController.text.isNotEmpty ? Colors.green : Colors.grey,
                                size: 28,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'حالة الربط بحسابك في تليجرام:',
                                      style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                                    ),
                                    Text(
                                      _telegramChatIdController.text.isNotEmpty
                                          ? '✅ متصل وجاهز للعمل (ID: ${_telegramChatIdController.text})'
                                          : '❌ غير متصل بعد',
                                      style: TextStyle(
                                        color: _telegramChatIdController.text.isNotEmpty ? Colors.green.shade800 : Colors.red.shade700,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_telegramChatIdController.text.isNotEmpty)
                                TextButton.icon(
                                  onPressed: _sendTestTelegramMessage,
                                  icon: const Icon(Icons.mark_email_read_rounded, size: 18),
                                  label: const Text('فحص الاتصال'),
                                  style: TextButton.styleFrom(foregroundColor: Colors.teal),
                                ),
                              if (_telegramChatIdController.text.isNotEmpty)
                                TextButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _telegramChatIdController.clear();
                                    });
                                    _saveSettings();
                                  },
                                  icon: const Icon(Icons.link_off_rounded, size: 18),
                                  label: const Text('إلغاء الربط'),
                                  style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // بطاقة ربط الواتساب للتقارير وفواتير المبيعات
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.chat_bubble_rounded, color: Colors.green, size: 24),
                            SizedBox(width: 8),
                            Text('2. التقارير وفواتير اليومية عبر WhatsApp 💬',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'أدخل رقم هاتفك لتصلك تقارير المبيعات اليومية وتنبيهات الأرباح مباشرة في محادثة الواتساب العادية دون أي تعقيد:',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 14),

                        if (isWide)
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _whatsAppPhoneController,
                                  keyboardType: TextInputType.phone,
                                  decoration: const InputDecoration(
                                    labelText: 'رقم هاتف صاحب المحل (WhatsApp)',
                                    hintText: 'مثال: 0661234567 أو 0550123456',
                                    prefixIcon: Icon(Icons.phone_iphone_rounded, color: Colors.green),
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green.shade700,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                ),
                                icon: const Icon(Icons.send_rounded, size: 16),
                                label: const Text('تجربة إرسال للواتساب', style: TextStyle(fontWeight: FontWeight.bold)),
                                onPressed: _sendTestWhatsAppMessage,
                              ),
                            ],
                          )
                        else
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextField(
                                controller: _whatsAppPhoneController,
                                keyboardType: TextInputType.phone,
                                decoration: const InputDecoration(
                                  labelText: 'رقم هاتف صاحب المحل (WhatsApp)',
                                  hintText: 'مثال: 0661234567 أو 0550123456',
                                  prefixIcon: Icon(Icons.phone_iphone_rounded, color: Colors.green),
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                              const SizedBox(height: 10),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green.shade700,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                icon: const Icon(Icons.send_rounded, size: 16),
                                label: const Text('تجربة إرسال للواتساب', style: TextStyle(fontWeight: FontWeight.bold)),
                                onPressed: _sendTestWhatsAppMessage,
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // بطاقة خيارات الحفظ التلقائي عند ختام الصندوق
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('نسخ احتياطي تلقائي عند ختام الصندوق ونهاية الوردية (Z-Report)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                      subtitle: const Text('يقوم بحفظ قاعدة البيانات وإرسال التقرير السحابي للمدير فور إغلاق اليومية'),
                      value: _autoBackupOnShiftClose,
                      activeColor: Colors.teal,
                      onChanged: (val) {
                        setState(() => _autoBackupOnShiftClose = val);
                        _saveSettings();
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // History of Local Backups
                const Row(
                  children: [
                    Icon(Icons.history_rounded, color: Colors.teal),
                    SizedBox(width: 8),
                    Text('سجل النسخ الاحتياطية المحفوظة محلياً',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 10),

                if (_backups.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(32),
                    alignment: Alignment.center,
                    child: const Text('لا توجد نسخ احتياطية محفوظة حالياً.', style: TextStyle(color: Colors.grey)),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _backups.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = _backups[index];
                      return ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: Colors.teal.shade50, shape: BoxShape.circle),
                          child: const Icon(Icons.archive_rounded, color: Colors.teal),
                        ),
                        title: Text(item.fileName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                        subtitle: Text(
                          DateFormat('yyyy/MM/dd HH:mm').format(item.createdAt) +
                              ' • ' +
                              item.readableSize +
                              ' • ' +
                              item.productsCount.toString() +
                              ' منتج',
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.restore_page_rounded, color: Colors.orange, size: 20),
                              tooltip: 'استرجاع البيانات من هذه النسخة',
                              onPressed: () async {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('تحذير الاسترجاع ⚠️'),
                                    content: const Text(
                                        'هل أنت متأكد من استرجاع البيانات؟\n\nهذه العملية ستقوم بحذف المنتجات الحالية واستبدالها بالمنتجات الموجودة في هذه النسخة الاحتياطية.'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                                        onPressed: () => Navigator.pop(ctx, true),
                                        child: const Text('نعم، استرجاع الآن', style: TextStyle(color: Colors.white)),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmed == true && mounted) {
                                  setState(() => _isLoading = true);
                                  final success = await BackupService.restoreDatabaseFromFile(File(item.filePath));
                                  setState(() => _isLoading = false);
                                  if (success && mounted) {
                                    SoundService.playSaveSuccess();
                                    SnackbarHelper.showSuccess(context, '✅ تم استرجاع البيانات بنجاح!');
                                    // reload app if needed
                                  } else if (mounted) {
                                    SoundService.playWarning();
                                    SnackbarHelper.showError(context, '❌ فشل في استرجاع البيانات، تأكد من صحة الملف.');
                                  }
                                }
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.share_rounded, color: Colors.blueAccent, size: 20),
                              tooltip: 'مشاركة الملف',
                              onPressed: () => Share.shareXFiles([XFile(item.filePath)]),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                              tooltip: 'حذف',
                              onPressed: () async {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('تأكيد الحذف'),
                                    content: const Text('هل أنت متأكد من رغبتك في حذف هذه النسخة الاحتياطية؟'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                        onPressed: () => Navigator.pop(ctx, true),
                                        child: const Text('حذف', style: TextStyle(color: Colors.white)),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmed == true) {
                                  await BackupService.deleteBackup(item.filePath);
                                  _loadBackups();
                                }
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
    );
  }
}
