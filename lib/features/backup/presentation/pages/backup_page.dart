import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/data/hive_database.dart';
import '../../../../core/utils/snackbar_helper.dart';
import '../../../../core/utils/sound_service.dart';
import '../data/backup_service.dart';

class BackupPage extends StatefulWidget {
  const BackupPage({super.key});

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  List<BackupSnapshotInfo> _backups = [];
  bool _isLoading = true;

  // Settings
  final TextEditingController _telegramTokenController = TextEditingController();
  final TextEditingController _telegramChatIdController = TextEditingController();
  bool _autoBackupOnShiftClose = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadBackups();
  }

  void _loadSettings() {
    final box = HiveDatabase.settingsBox;
    _telegramTokenController.text = box.get('telegram_bot_token', defaultValue: '');
    _telegramChatIdController.text = box.get('telegram_chat_id', defaultValue: '');
    _autoBackupOnShiftClose = box.get('auto_backup_on_shift_close', defaultValue: true);
  }

  Future<void> _saveSettings() async {
    final box = HiveDatabase.settingsBox;
    await box.put('telegram_bot_token', _telegramTokenController.text.trim());
    await box.put('telegram_chat_id', _telegramChatIdController.text.trim());
    await box.put('auto_backup_on_shift_close', _autoBackupOnShiftClose);
    SoundService.playSaveSuccess();
    if (mounted) {
      SnackbarHelper.showSuccess(context, 'تم حفظ إعدادات النسخ الاحتياطي السحابي بنجاح');
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

  Future<void> _createBackupNow() async {
    setState(() => _isLoading = true);
    try {
      final file = await BackupService.createFullBackupZip(customNote: 'نسخة يدوية فورية');
      
      // If Telegram is configured, send
      final token = _telegramTokenController.text.trim();
      final chatId = _telegramChatIdController.text.trim();
      if (token.isNotEmpty && chatId.isNotEmpty) {
        await BackupService.sendToTelegramBot(backupFile: file, botToken: token, chatId: chatId);
      }

      await _loadBackups();
      SoundService.playSaveSuccess();
      if (mounted) {
        SnackbarHelper.showSuccess(context, 'تم إنشاء وتأمين النسخة الاحتياطية بنجاح!');
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'فشل النسخ الاحتياطي: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _confirmRestore(BackupSnapshotInfo backup) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text('استرجاع قاعدة البيانات'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('أنت على وشك استرجاع النسخة المؤرخة في: ${DateFormat('yyyy/MM/dd HH:mm').format(backup.createdAt)}'),
            const SizedBox(height: 8),
            Text('المحتويات: ${backup.productsCount} سلعة • ${backup.invoicesCount} فاتورة • ${backup.customersCount} عميل'),
            const SizedBox(height: 12),
            const Text('⚠️ تحذير: سيتم استبدال البيانات الحالية بالكامل بالبيانات المسترجعة من هذه النسخة.',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isLoading = true);
              final success = await BackupService.restoreDatabaseFromFile(File(backup.filePath));
              setState(() => _isLoading = false);
              if (success) {
                SoundService.playCheckoutSuccess();
                if (mounted) {
                  SnackbarHelper.showSuccess(context, 'تم استرجاع قاعدة البيانات بنجاح 100%!');
                }
              } else {
                if (mounted) {
                  SnackbarHelper.showError(context, 'فشل استرجاع قاعدة البيانات، الملف تالف.');
                }
              }
            },
            child: const Text('نعم، استرجاع الكل', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.cloud_sync_rounded, color: Colors.teal),
            SizedBox(width: 8),
            Text('النسخ الاحتياطي والمزامنة السحابية (3-2-1 Backup Engine)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        actions: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, padding: const EdgeInsets.symmetric(horizontal: 16)),
            icon: const Icon(Icons.backup_rounded, color: Colors.white),
            label: const Text('إنشاء نسخة احتياطية الآن (+)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            onPressed: _createBackupNow,
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
                  // Top Overview Card
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(10)),
                                child: const Icon(Icons.security_rounded, color: Colors.teal, size: 32),
                              ),
                              const SizedBox(width: 14),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('نظام الحماية والمزامنة الهجين (Nayli Vault 3-2-1)',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  Text(
                                    _backups.isEmpty
                                        ? 'لم يتم إنشاء أي نسخة احتياطية بعد'
                                        : 'آخر نسخة محفوظة: ${DateFormat('yyyy/MM/dd HH:mm').format(_backups.first.createdAt)} • إجمالي النسخ: ${_backups.length}',
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.green),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.check_circle, color: Colors.green, size: 16),
                                SizedBox(width: 6),
                                Text('النسخ التلقائي للـ USB مفعل', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Cloud Telegram Vault Configuration Card
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.send_rounded, color: Colors.blueAccent),
                              SizedBox(width: 8),
                              Text('النسخ السحابي التلقائي إلى Telegram (Cloud Vault)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Text('عند تفعيل هذا الخيار، سيتم إرسال نسخة احتياطية مشفرة تلقائياً إلى حساب المدير على تيليجرام عند نهاية كل وردية.',
                              style: TextStyle(fontSize: 12, color: Colors.grey)),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  controller: _telegramTokenController,
                                  decoration: const InputDecoration(
                                    labelText: 'Telegram Bot Token (توكن بوت المدير)',
                                    hintText: '123456789:ABCdefGhIJKlmNoPQRsTUVwxyZ',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: _telegramChatIdController,
                                  decoration: const InputDecoration(
                                    labelText: 'Chat ID (معرف المحادثة)',
                                    hintText: '987654321',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
                                icon: const Icon(Icons.save, color: Colors.white),
                                label: const Text('حفظ الإعدادات', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                onPressed: _saveSettings,
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('نسخ احتياطي تلقائي عند ختام الصندوق ونهاية الوردية (Z-Report)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            subtitle: const Text('يقوم بحفظ قاعدة البيانات وإرسال التقرير للمدير فور إغلاق اليومية'),
                            value: _autoBackupOnShiftClose,
                            onChanged: (val) {
                              setState(() => _autoBackupOnShiftClose = val);
                              _saveSettings();
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // History of Local Backups
                  const Row(
                    children: [
                      Icon(Icons.history_rounded, color: Colors.teal),
                      SizedBox(width: 8),
                      Text('سجل النسخ الاحتياطية المحفوظة محلياً', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 10),

                  if (_backups.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(32),
                      alignment: Alignment.center,
                      child: const Text('لا توجد نسخ احتياطية مسجلة بعد. اضغط على "إنشاء نسخة احتياطية الآن" لحفظ بياناتك.', style: TextStyle(color: Colors.grey)),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _backups.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final b = _backups[index];
                        final sizeKb = (b.fileSize / 1024).toStringAsFixed(1);

                        return Card(
                          elevation: 1,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(8)),
                              child: const Icon(Icons.archive_outlined, color: Colors.teal),
                            ),
                            title: Text(b.fileName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            subtitle: Text(
                              '📅 ${DateFormat('yyyy/MM/dd HH:mm').format(b.createdAt)} • الحجم: $sizeKb KB • المحتوى: ${b.productsCount} سلعة، ${b.invoicesCount} مبيعات، ${b.documentsCount} وثيقة',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'مشاركة أو نقل الملف (Share / USB)',
                                  icon: const Icon(Icons.share_rounded, color: Colors.blueAccent),
                                  onPressed: () {
                                    Share.shareXFiles([XFile(b.filePath)], text: 'نسخة احتياطية نايل ماركت: ${b.fileName}');
                                  },
                                ),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade700),
                                  icon: const Icon(Icons.restore_rounded, color: Colors.white, size: 16),
                                  label: const Text('استرجاع (Restore)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                  onPressed: () => _confirmRestore(b),
                                ),
                                IconButton(
                                  tooltip: 'حذف النسخة',
                                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                                  onPressed: () {
                                    try {
                                      File(b.filePath).deleteSync();
                                      _loadBackups();
                                      SoundService.playDeleteSound();
                                    } catch (_) {}
                                  },
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
}

