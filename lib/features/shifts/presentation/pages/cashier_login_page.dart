import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/data/hive_database.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/security_pin_helper.dart';
import '../../../../core/utils/sound_service.dart';
import '../../../../core/utils/license_service.dart';
import '../../data/staff_member_model.dart';
import '../../data/staff_service.dart';
import '../../data/shift_service.dart';

class CashierLoginPage extends StatefulWidget {
  const CashierLoginPage({super.key});

  @override
  State<CashierLoginPage> createState() => _CashierLoginPageState();
}

class _CashierLoginPageState extends State<CashierLoginPage> {
  List<StaffMember> _staffList = [];
  StaffMember? _selectedStaff;
  String _pin = '';
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _loadStaff();
    _checkActiveShift();
  }

  Future<void> _checkActiveShift() async {
    final activeShift = await ShiftService.getActiveShift();
    if (activeShift != null && mounted) {
      context.go('/');
    }
  }

  Future<void> _loadStaff() async {
    await StaffService.seedInitialAdminIfEmpty();
    final loaded = StaffService.getActiveStaff();
    if (mounted) {
      setState(() {
        _staffList = loaded;
      });
    }
  }

  bool _doesStaffHaveConfiguredPin(StaffMember staff) {
    final cleanPin = staff.pin.trim();
    if (staff.isAdmin) {
      if (SecurityPinHelper.isPinEnabled()) return true;
      return cleanPin.isNotEmpty && cleanPin != '9999' && cleanPin != '0000';
    }
    return cleanPin.isNotEmpty;
  }

  void _onSelectStaff(StaffMember staff) {
    SoundService.playTabSwitch();
    if (!_doesStaffHaveConfiguredPin(staff)) {
      if (staff.isAdmin) {
        _showFirstTimePinChoiceDialog(staff);
      } else {
        setState(() {
          _selectedStaff = staff;
          _pin = '';
          _errorMsg = null;
        });
        _promptForFloatAmount(staffOverride: staff);
      }
      return;
    }

    setState(() {
      _selectedStaff = staff;
      _pin = '';
      _errorMsg = null;
    });
  }

  Future<void> _showFirstTimePinChoiceDialog(StaffMember adminStaff) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.verified_user_rounded, color: Colors.amber, size: 28),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'إعداد الحماية الأول للمدير',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'مرحباً بك! لم تقم بإنشاء رمز قفل سري (PIN) للمدير بعد.',
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'يمكنك الآن إما إنشاء رمز القفل الخاص بك أولاً (4 أرقام) ليطلبه البرنامج مستقبلاً، أو الدخول مباشرة لفتح المناوبة وتعيين الرمز لاحقاً من الإعدادات.',
              style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('رجوع', style: TextStyle(color: Colors.grey)),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.amberAccent,
                  side: const BorderSide(color: Colors.amberAccent),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.lock_outline_rounded, size: 18),
                label: const Text('إنشاء رمز القفل الآن 🔐', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () {
                  Navigator.pop(ctx);
                  _showCreateInitialPinDialog(adminStaff);
                },
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.login_rounded, size: 18),
                label: const Text('دخول مباشر بدون رمز 🚀', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () {
                  Navigator.pop(ctx);
                  _promptForFloatAmount(staffOverride: adminStaff);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showCreateInitialPinDialog(StaffMember adminStaff) async {
    final pinCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    String? localError;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.pin_rounded, color: Colors.amber, size: 26),
              SizedBox(width: 8),
              Text('تعيين رمز القفل السري للمدير', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'اختر رمزاً سرياً مكوناً من 4 أرقام لحماية الإدارة والمناوبات:',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: pinCtrl,
                autofocus: true,
                maxLength: 4,
                obscureText: true,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 22, letterSpacing: 10, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  labelText: 'الرمز السري الجديد (4 أرقام)',
                  labelStyle: const TextStyle(color: Colors.white70, fontSize: 13, letterSpacing: 0),
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: confirmCtrl,
                maxLength: 4,
                obscureText: true,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 22, letterSpacing: 10, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  labelText: 'تأكيد الرمز السري',
                  labelStyle: const TextStyle(color: Colors.white70, fontSize: 13, letterSpacing: 0),
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              if (localError != null) ...[
                const SizedBox(height: 8),
                Text(localError!, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
              icon: const Icon(Icons.check_circle_outline, size: 18),
              label: const Text('حفظ الرمز ومتابعة فتح المناوبة', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () async {
                final p1 = pinCtrl.text.trim();
                final p2 = confirmCtrl.text.trim();
                if (p1.length != 4 || int.tryParse(p1) == null) {
                  setDlgState(() => localError = 'يرجى إدخال 4 أرقام صحيحة!');
                  return;
                }
                if (p1 != p2) {
                  setDlgState(() => localError = 'الرمزان غير متطابقين!');
                  return;
                }
                await SecurityPinHelper.setPin(p1);
                final updatedAdmin = adminStaff.copyWith(pin: p1);
                await StaffService.saveStaff(updatedAdmin);
                await _loadStaff();
                if (ctx.mounted) Navigator.pop(ctx);
                SoundService.playSaveSuccess();
                if (mounted) {
                  _promptForFloatAmount(staffOverride: updatedAdmin);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _onPinKey(String key) {
    if (_pin.length < 4) {
      setState(() {
        _pin += key;
        _errorMsg = null;
      });
      if (_pin.length == 4) {
        _verifyPin();
      }
    }
  }

  void _onBackspace() {
    if (_pin.isNotEmpty) {
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
        _errorMsg = null;
      });
    }
  }

  Future<void> _verifyPin() async {
    if (_selectedStaff == null) return;
    
    final enteredPinClean = _pin.trim();
    final staffPinClean = _selectedStaff!.pin.trim();
    
    final bool isStaffMatch = staffPinClean.isNotEmpty && enteredPinClean == staffPinClean;
    final bool isManagerOverride = SecurityPinHelper.isPinEnabled() && SecurityPinHelper.verifyPin(enteredPinClean);
    
    if (isStaffMatch || isManagerOverride) {
      SoundService.playSaveSuccess();
      _promptForFloatAmount(staffOverride: _selectedStaff);
    } else {
      SoundService.playVoidWarning();
      setState(() {
        _errorMsg = 'الرمز السري غير صحيح!';
        _pin = '';
      });
    }
  }

  Future<void> _promptForFloatAmount({StaffMember? staffOverride}) async {
    final targetStaff = staffOverride ?? _selectedStaff;
    if (targetStaff == null) return;

    double floatAmount = 0.0;
    final ctrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.point_of_sale_rounded, color: Colors.greenAccent),
            SizedBox(width: 8),
            Text('تأكيد رصيد الصندوق', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'مرحباً ${targetStaff.name}! شحال كاين صرف في لاكيس حالياً (Fond de caisse)؟',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.greenAccent, fontSize: 20, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF0F172A),
                hintText: '0.0',
                hintStyle: const TextStyle(color: Colors.white38),
                suffixText: 'دج',
                suffixStyle: const TextStyle(color: Colors.white),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onSubmitted: (val) {
                floatAmount = double.tryParse(val) ?? 0.0;
                Navigator.pop(ctx, true);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx, false);
              setState(() {
                _selectedStaff = null;
                _pin = '';
              });
            },
            child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () {
              floatAmount = double.tryParse(ctrl.text) ?? 0.0;
              Navigator.pop(ctx, true);
            },
            child: const Text('فتح المناوبة 🚀', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (result == true) {
      await ShiftService.openShift(
        workerName: targetStaff.name,
        floatAmount: floatAmount,
        staffId: targetStaff.id,
      );
      
      if (mounted) {
        context.go('/');
      }
    }
  }

  void _showForgotPinDialog() {
    SoundService.playTabSwitch();
    final codeCtrl = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.admin_panel_settings, color: Colors.amber),
            SizedBox(width: 8),
            Text('استعادة رمز الدخول', style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'أدخل كود تفعيل المحل (Activation Code) لإعادة تعيين الرمز السري:',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: codeCtrl,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                filled: true,
                fillColor: Color(0xFF0F172A),
                prefixIcon: Icon(Icons.key, color: Colors.amber),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
            onPressed: () async {
              final val = codeCtrl.text.trim();
              if (val.isEmpty) return;
              
              final res = await LicenseService.verifyAndApplyDouchetteToken(val);
              if (res['success'] == true || val == LicenseService.getCleanMachineId()) {
                Navigator.pop(ctx);
                _showResetPinScreen();
              } else {
                SoundService.playVoidWarning();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('الكود غير صحيح!'), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('تحقق 🔓', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showResetPinScreen() {
    final newPinCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('تعيين رمز جديد', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: newPinCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          maxLength: 4,
          style: const TextStyle(color: Colors.white, fontSize: 20, letterSpacing: 8),
          decoration: const InputDecoration(
            filled: true,
            fillColor: Color(0xFF0F172A),
            hintText: '****',
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () async {
              if (newPinCtrl.text.length == 4) {
                final cleanNewPin = newPinCtrl.text.trim();
                if (_selectedStaff != null) {
                  if (_selectedStaff!.isAdmin) {
                    await SecurityPinHelper.setPin(cleanNewPin);
                  }
                  final updated = _selectedStaff!.copyWith(pin: cleanNewPin);
                  await HiveDatabase.staffBox.put(updated.id, updated.toMap());
                  setState(() {
                    final idx = _staffList.indexWhere((s) => s.id == updated.id);
                    if (idx >= 0) _staffList[idx] = updated;
                    _selectedStaff = updated;
                  });
                } else {
                  await SecurityPinHelper.setPin(cleanNewPin);
                }
                if (ctx.mounted) Navigator.pop(ctx);
                SoundService.playSaveSuccess();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم تغيير الرمز السري بنجاح!'), backgroundColor: Colors.green),
                  );
                }
              }
            },
            child: const Text('حفظ الرمز 💾'),
          ),
        ],
      ),
    );
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'admin':
        return 'مدير النظام';
      case 'supervisor':
        return 'مشرف';
      case 'cashier':
        return 'كاشير';
      default:
        return 'عامل';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedStaff != null) {
      return _buildPinScreen();
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.point_of_sale_rounded, size: 68, color: Color(0xFF818CF8)),
                  const SizedBox(height: 16),
                  const Text(
                    'مرحباً بك في نقطة البيع',
                    style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'الرجاء اختيار حساب العامل أو المدير لفتح المناوبة وبدء العمل',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 36),
                  Center(
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      runAlignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 20,
                      runSpacing: 20,
                      children: _staffList.map((staff) {
                        final hasPin = _doesStaffHaveConfiguredPin(staff);
                        return SizedBox(
                          width: 190,
                          height: 210,
                          child: InkWell(
                            onTap: () => _onSelectStaff(staff),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFF334155), width: 1.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.25),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircleAvatar(
                                    radius: 34,
                                    backgroundColor: staff.isAdmin ? Colors.indigo : Colors.teal,
                                    child: Text(
                                      staff.name.isNotEmpty ? staff.name[0].toUpperCase() : '?',
                                      style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                    child: Text(
                                      staff.name,
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: staff.isAdmin ? Colors.indigo.withOpacity(0.2) : Colors.teal.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      _roleLabel(staff.role),
                                      style: TextStyle(
                                        color: staff.isAdmin ? Colors.indigoAccent : Colors.tealAccent,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        hasPin ? Icons.lock_rounded : Icons.lock_open_rounded,
                                        size: 13,
                                        color: hasPin ? Colors.amberAccent : Colors.greenAccent,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        hasPin ? 'محمي برمز PIN' : 'دخول مباشر',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: hasPin ? Colors.amberAccent : Colors.greenAccent,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 32),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Color(0xFF334155)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.manage_accounts_rounded, size: 20, color: Color(0xFF818CF8)),
                    label: const Text('إدارة العمال وإضافة كاشير / مناوب جديد', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () async {
                      final ok = await SecurityPinHelper.authenticate(
                        context,
                        title: 'إدارة العمال والمناوبات',
                        message: 'أدخل رمز المدير لإدارة حسابات العمال',
                      );
                      if (ok && mounted) {
                        await context.push('/staff-management');
                        _loadStaff();
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPinScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: Container(
          width: 380,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 30)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: _selectedStaff!.isAdmin ? Colors.indigo : Colors.teal,
                child: Text(
                  _selectedStaff!.name.isNotEmpty ? _selectedStaff!.name[0].toUpperCase() : '?',
                  style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'مرحباً ${_selectedStaff!.name}',
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Text('أدخل الرمز السري', style: TextStyle(color: Colors.grey, fontSize: 14)),
              const SizedBox(height: 24),
              
              // PIN Dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (i) {
                  final filled = i < _pin.length;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: filled ? AppTheme.primaryColor : Colors.transparent,
                      border: Border.all(color: filled ? AppTheme.primaryColor : Colors.grey),
                    ),
                  );
                }),
              ),
              
              if (_errorMsg != null) ...[
                const SizedBox(height: 12),
                Text(_errorMsg!, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
              ],
              
              const SizedBox(height: 24),
              
              // Numpad
              _buildNumpadRow(['1', '2', '3']),
              const SizedBox(height: 12),
              _buildNumpadRow(['4', '5', '6']),
              const SizedBox(height: 12),
              _buildNumpadRow(['7', '8', '9']),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildNumpadBtn('رجوع', color: Colors.grey.withOpacity(0.2), textColor: Colors.white, onTap: () {
                    setState(() {
                      _selectedStaff = null;
                      _pin = '';
                      _errorMsg = null;
                    });
                  }),
                  _buildNumpadBtn('0', onTap: () => _onPinKey('0')),
                  _buildNumpadBtn('مسح', color: Colors.red.withOpacity(0.2), textColor: Colors.redAccent, onTap: _onBackspace),
                ],
              ),
              
              const SizedBox(height: 24),
              TextButton.icon(
                onPressed: _showForgotPinDialog,
                icon: const Icon(Icons.help_outline, color: Colors.grey, size: 16),
                label: const Text('نسيت الرمز؟', style: TextStyle(color: Colors.grey, decoration: TextDecoration.underline)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNumpadRow(List<String> keys) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: keys.map((k) => _buildNumpadBtn(k, onTap: () => _onPinKey(k))).toList(),
    );
  }

  Widget _buildNumpadBtn(String label, {Color? color, Color? textColor, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 75,
        height: 60,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color ?? const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: textColor ?? Colors.white,
            fontSize: label.length > 1 ? 16 : 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
