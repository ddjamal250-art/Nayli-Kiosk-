import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';

import '../../../../core/data/hive_database.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/security_pin_helper.dart';
import '../../../../core/utils/sound_service.dart';
import '../../../../core/utils/license_service.dart';
import '../../data/staff_member_model.dart';
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
      // إذا كاين مناوبة مفتوحة ديجا، يدخل مباشرة لنقطة البيع
      context.go('/');
    }
  }

  void _loadStaff() {
    final box = HiveDatabase.staffBox;
    final List<StaffMember> loaded = [];
    for (var key in box.keys) {
      final val = box.get(key);
      if (val is Map) {
        final staff = StaffMember.fromMap(val);
        if (staff.isActive && staff.hasPosAccess) {
          loaded.add(staff);
        }
      }
    }
    
    // إذا مكانش حتى عامل مسجل، نزيدو مدير افتراضي
    if (loaded.isEmpty) {
      final defaultAdmin = StaffMember(
        id: 'admin_01',
        name: 'المدير العام',
        role: 'admin',
        pin: '0000',
        barcode: 'ADMIN',
      );
      box.put(defaultAdmin.id, defaultAdmin.toMap());
      loaded.add(defaultAdmin);
    }
    
    setState(() {
      _staffList = loaded;
    });
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
    
    // التحقق من الـ PIN (للعامل أو المدير العام)
    if (_pin == _selectedStaff!.pin || SecurityPinHelper.verifyPin(_pin)) {
      SoundService.playSaveSuccess();
      _promptForFloatAmount();
    } else {
      SoundService.playVoidWarning();
      setState(() {
        _errorMsg = 'الرمز السري غير صحيح!';
        _pin = '';
      });
    }
  }

  Future<void> _promptForFloatAmount() async {
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
              'مرحباً ${_selectedStaff!.name}! شحال كاين صرف في لاكيس حالياً (Fond de caisse)؟',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: const const TextInputType.numberWithOptions(decimal: true)WithOptions(decimal: true),
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
      // فتح المناوبة
      await ShiftService.openShift(
        workerName: _selectedStaff!.name,
        floatAmount: floatAmount,
      );
      
      // التوجه لنقطة البيع
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
              
              // Verify activation code
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
                if (_selectedStaff != null) {
                  final updated = _selectedStaff!.copyWith(pin: newPinCtrl.text);
                  await HiveDatabase.staffBox.put(updated.id, updated.toMap());
                  setState(() {
                    final idx = _staffList.indexWhere((s) => s.id == updated.id);
                    if (idx >= 0) _staffList[idx] = updated;
                    _selectedStaff = updated;
                  });
                } else {
                  await SecurityPinHelper.setPin(newPinCtrl.text);
                }
                Navigator.pop(ctx);
                SoundService.playSaveSuccess();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم تغيير الرمز السري بنجاح!'), backgroundColor: Colors.green),
                );
              }
            },
            child: const Text('حفظ الرمز 💾'),
          ),
        ],
      ),
    );
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
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.point_of_sale_rounded, size: 64, color: Color(0xFF818CF8)),
                const SizedBox(height: 16),
                const Text(
                  'مرحباً بك في نقطة البيع',
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const Text(
                  'الرجاء اختيار اسمك لفتح المناوبة وبدء العمل',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
                const SizedBox(height: 40),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 200,
                      childAspectRatio: 1.1,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: _staffList.length,
                    itemBuilder: (context, index) {
                      final staff = _staffList[index];
                      return InkWell(
                        onTap: () {
                          SoundService.playTabSwitch();
                          setState(() {
                            _selectedStaff = staff;
                            _pin = '';
                            _errorMsg = null;
                          });
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFF334155)),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircleAvatar(
                                radius: 30,
                                backgroundColor: staff.isAdmin ? Colors.indigo : Colors.teal,
                                child: Text(
                                  staff.name.isNotEmpty ? staff.name[0].toUpperCase() : '?',
                                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                staff.name,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                textAlign: TextAlign.center,
                              ),
                              Text(
                                staff.role == 'admin' ? 'مدير النظام' : 'كاشير',
                                style: TextStyle(color: staff.isAdmin ? Colors.indigoAccent : Colors.tealAccent, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
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
