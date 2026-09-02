import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/snackbar_helper.dart';
import '../../../../core/utils/sound_service.dart';
import '../../data/staff_member_model.dart';
import '../../data/staff_service.dart';
import '../../data/payroll_record_model.dart';
import '../../data/payroll_service.dart';
import '../../data/attendance_service.dart';
import '../../data/attendance_record_model.dart';

class StaffManagementPage extends StatefulWidget {
  const StaffManagementPage({super.key});

  @override
  State<StaffManagementPage> createState() => _StaffManagementPageState();
}

class _StaffManagementPageState extends State<StaffManagementPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<StaffMember> _staffList = [];
  String _selectedMonth = DateFormat('yyyy-MM').format(DateTime.now());
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await StaffService.seedInitialAdminIfEmpty();
    final staff = StaffService.getAllStaff();
    if (mounted) {
      setState(() {
        _staffList = staff;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.badge_rounded, color: Colors.teal),
            SizedBox(width: 8),
            Text('إدارة الموارد البشرية والرواتب (HR & Payroll)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.teal,
          indicatorWeight: 3,
          labelColor: Colors.teal,
          unselectedLabelColor: Colors.grey,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(icon: Icon(Icons.people_alt_rounded), text: 'دليل العمال والصلاحيات'),
            Tab(icon: Icon(Icons.account_balance_wallet_rounded), text: 'الرواتب والسلفيات (Paie)'),
            Tab(icon: Icon(Icons.access_time_filled_rounded), text: 'سجل الحضور (Pointage)'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildStaffDirectoryTab(),
                _buildPayrollTab(),
                _buildAttendanceTab(),
              ],
            ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton.extended(
              backgroundColor: Colors.teal,
              icon: const Icon(Icons.person_add_rounded, color: Colors.white),
              label: const Text('إضافة موظف جديد', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              onPressed: _showAddEditStaffDialog,
            )
          : null,
    );
  }

  // ==========================================
  // TAB 1: STAFF DIRECTORY & PERMISSIONS
  // ==========================================
  Widget _buildStaffDirectoryTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _staffList.length,
      itemBuilder: (context, index) {
        final member = _staffList[index];
        return Card(
          elevation: 1.5,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: member.isAdmin
                              ? Colors.indigo.shade100
                              : (member.isActive ? Colors.teal.shade100 : Colors.grey.shade200),
                          child: Icon(
                            member.isAdmin ? Icons.admin_panel_settings_rounded : Icons.person_rounded,
                            color: member.isAdmin ? Colors.indigo : (member.isActive ? Colors.teal : Colors.grey),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(member.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            Text(
                              '${_formatDepartment(member.department)} • ${_formatRole(member.role)}',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: member.isActive ? Colors.green.shade50 : Colors.red.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: member.isActive ? Colors.green : Colors.red),
                          ),
                          child: Text(
                            member.isActive ? 'نشط' : 'معطل',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: member.isActive ? Colors.green.shade800 : Colors.red.shade800),
                          ),
                        ),
                        const SizedBox(width: 8),
                        PopupMenuButton<String>(
                          onSelected: (val) => _handleStaffMenuAction(val, member),
                          itemBuilder: (ctx) => [
                            const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('تعديل البيانات')])),
                            const PopupMenuItem(value: 'permissions', child: Row(children: [Icon(Icons.security, size: 18), SizedBox(width: 8), Text('تعديل الصلاحيات')])),
                            const PopupMenuItem(value: 'advance', child: Row(children: [Icon(Icons.payments_outlined, size: 18), SizedBox(width: 8), Text('تسجيل تسبيق / سلفة')])),
                            PopupMenuItem(
                              value: 'toggle_active',
                              child: Row(children: [
                                Icon(member.isActive ? Icons.block : Icons.check_circle, size: 18),
                                const SizedBox(width: 8),
                                Text(member.isActive ? 'تعطيل الحساب' : 'تفعيل الحساب'),
                              ]),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('الراتب: ${member.baseSalary.toStringAsFixed(0)} دج (${member.salaryType == 'daily' ? 'يومي' : 'شهري'})',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.teal)),
                    Text('الكاشير المفضل: ${member.preferredStation}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                    Text('رمز الـ PIN: ${member.isAdmin ? '****' : member.pin}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.indigo)),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatDepartment(String dept) {
    switch (dept) {
      case 'caisse':
        return 'الكاشير والاستقبال 🛒';
      case 'stock':
        return 'المستودع وترتيب الرفوف 📦';
      case 'boucherie':
        return 'الملحمة والأجبان 🥩';
      case 'fruits':
        return 'الخضر والفواكه 🍎';
      case 'securite':
        return 'الأمن والمراقبة 🛡️';
      case 'entretien':
        return 'النظافة والخدمات 🧹';
      case 'admin':
        return 'الإدارة والمحاسبة 💼';
      default:
        return dept;
    }
  }

  String _formatRole(String role) {
    switch (role) {
      case 'admin':
        return 'مدير عام 👑';
      case 'supervisor':
        return 'مشرف وردية ⭐';
      case 'cashier':
        return 'كاشير بائع';
      default:
        return 'عامل';
    }
  }

  void _handleStaffMenuAction(String action, StaffMember member) {
    if (action == 'edit') {
      _showAddEditStaffDialog(member: member);
    } else if (action == 'permissions') {
      _showPermissionsDialog(member);
    } else if (action == 'advance') {
      _showAddAdvanceDialog(member);
    } else if (action == 'toggle_active') {
      if (member.isAdmin) {
        SnackbarHelper.showError(context, 'لا يمكن تعطيل حساب المدير العام الرئيسي!');
        return;
      }
      StaffService.toggleActive(member.id);
      _loadData();
    }
  }

  // ==========================================
  // TAB 2: PAYROLL & ADVANCES
  // ==========================================
  Widget _buildPayrollTab() {
    double totalSalaries = 0.0;
    double totalAdvances = 0.0;

    for (var s in _staffList.where((m) => m.isActive)) {
      final breakdown = PayrollService.calculateMonthlySettlement(s, _selectedMonth);
      totalSalaries += (breakdown['baseSalary'] as num?)?.toDouble() ?? 0.0;
      totalAdvances += (breakdown['totalAdvances'] as num?)?.toDouble() ?? 0.0;
    }

    return Column(
      children: [
        // Summary Header Banner
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.teal.shade200),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('مسير رواتب شهر: $_selectedMonth',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_month, size: 18),
                    label: const Text('تغيير الشهر'),
                    onPressed: _pickMonth,
                  ),
                ],
              ),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildPayrollStat('إجمالي الرواتب الأساسية', '${totalSalaries.toStringAsFixed(0)} دج', Colors.teal),
                  _buildPayrollStat('إجمالي التسبيقات المسحوبة', '${totalAdvances.toStringAsFixed(0)} دج', Colors.orange),
                  _buildPayrollStat('الصافي المتبقي للصرف', '${(totalSalaries - totalAdvances).toStringAsFixed(0)} دج', Colors.indigo),
                ],
              ),
            ],
          ),
        ),

        // Staff Payroll List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _staffList.where((m) => m.isActive).length,
            itemBuilder: (context, index) {
              final staff = _staffList.where((m) => m.isActive).toList()[index];
              final data = PayrollService.calculateMonthlySettlement(staff, _selectedMonth);
              final isSettled = data['alreadySettled'] == true;

              return Card(
                elevation: 1,
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: isSettled ? Colors.green.shade50 : Colors.teal.shade50,
                        child: Icon(isSettled ? Icons.check_circle : Icons.wallet,
                            color: isSettled ? Colors.green : Colors.teal),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(staff.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            Text('الأساسي: ${(data['baseSalary'] as double).toStringAsFixed(0)} دج  •  التسبيقات: ${(data['totalAdvances'] as double).toStringAsFixed(0)} دج',
                                style: const TextStyle(fontSize: 11.5, color: Colors.grey)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('الصافي: ${(data['netPayable'] as double).toStringAsFixed(0)} دج',
                              style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                  color: isSettled ? Colors.green.shade800 : Colors.teal.shade900)),
                          Text(isSettled ? 'تمت التصفية والدفع ✔️' : 'مستحق الدفع',
                              style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: isSettled ? Colors.green : Colors.orange.shade800)),
                        ],
                      ),
                      const SizedBox(width: 10),
                      IconButton(
                        icon: const Icon(Icons.receipt_long_rounded, color: Colors.teal),
                        tooltip: 'تصفية وطباعة كشف الراتب',
                        onPressed: () => _showSalarySettlementDialog(staff, data),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPayrollStat(String title, String val, MaterialColor color) {
    return Column(
      children: [
        Text(title, style: TextStyle(fontSize: 11, color: color.shade800, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(val, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: color.shade900)),
      ],
    );
  }

  Future<void> _pickMonth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) {
      setState(() {
        _selectedMonth = DateFormat('yyyy-MM').format(picked);
      });
    }
  }

  // ==========================================
  // TAB 3: ATTENDANCE (POINTAGE)
  // ==========================================
  Widget _buildAttendanceTab() {
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('سجل حضور اليوم: $todayStr',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                icon: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 18),
                label: const Text('تسجيل حضور بمسح الباركود 🔫',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                onPressed: _showBarcodePointageDialog,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: _staffList.where((m) => m.isActive).length,
              itemBuilder: (context, index) {
                final staff = _staffList.where((m) => m.isActive).toList()[index];
                final records = AttendanceService.getMonthlyAttendance(staff.id, _selectedMonth);
                final todayRecord = records.where((r) => r.dateStr == todayStr).firstOrNull;

                return Card(
                  elevation: 1,
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: todayRecord != null ? Colors.green.shade100 : Colors.grey.shade200,
                      child: Icon(
                        todayRecord != null ? Icons.check : Icons.person_outline,
                        color: todayRecord != null ? Colors.green : Colors.grey,
                      ),
                    ),
                    title: Text(staff.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      todayRecord != null
                          ? 'الدخول: ${todayRecord.checkInTime != null ? DateFormat('HH:mm').format(todayRecord.checkInTime!) : "-"}  •  الخروج: ${todayRecord.checkOutTime != null ? DateFormat('HH:mm').format(todayRecord.checkOutTime!) : "مستمر بالعمل"}'
                          : 'لم يسجل الحضور اليوم بعد',
                      style: TextStyle(fontSize: 12, color: todayRecord != null ? Colors.green.shade800 : Colors.grey),
                    ),
                    trailing: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: todayRecord == null ? Colors.teal : Colors.blueGrey,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      ),
                      onPressed: () async {
                        await AttendanceService.recordPointage(
                          staffId: staff.id,
                          staffName: staff.name,
                        );
                        _loadData();
                        SoundService.playSaveSuccess();
                      },
                      child: Text(
                        todayRecord == null ? 'تسجيل دخول' : 'تسجيل خروج',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showBarcodePointageDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تسجيل الحضور بالباركود (Pointage)'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'امسح بطاقة العامل أو اكتب الكود (مثال: STAFF-1001)...',
            prefixIcon: Icon(Icons.qr_code),
            border: OutlineInputBorder(),
          ),
          onSubmitted: (code) async {
            Navigator.pop(ctx);
            final staff = StaffService.findByBarcode(code);
            if (staff != null) {
              await AttendanceService.recordPointage(staffId: staff.id, staffName: staff.name);
              SoundService.playCheckoutSuccess();
              SnackbarHelper.showSuccess(context, '✅ تم تسجيل حضور العامل: ${staff.name}');
              _loadData();
            } else {
              SoundService.playVoidWarning();
              SnackbarHelper.showError(context, '❌ لم يتم العثور على موظف بهذا الباركود');
            }
          },
        ),
      ),
    );
  }

  // ==========================================
  // MODALS & DIALOGS
  // ==========================================
  void _showAddEditStaffDialog({StaffMember? member}) {
    final isEdit = member != null;
    final nameCtrl = TextEditingController(text: member?.name ?? '');
    final phoneCtrl = TextEditingController(text: member?.phone ?? '');
    final nationalIdCtrl = TextEditingController(text: member?.nationalId ?? '');
    final salaryCtrl = TextEditingController(text: member?.baseSalary.toStringAsFixed(0) ?? '40000');
    final pinCtrl = TextEditingController(text: member?.pin ?? StaffService.generateUniquePin());
    final stationCtrl = TextEditingController(text: member?.preferredStation ?? 'كاشير 01');

    String selectedDept = member?.department ?? 'caisse';
    String selectedRole = member?.role ?? 'cashier';
    String selectedSalaryType = member?.salaryType ?? 'monthly';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(isEdit ? 'تعديل بيانات الموظف' : 'إضافة موظف جديد (+)',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'اسم الموظف الكامل *', border: OutlineInputBorder())),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'رقم الهاتف', border: OutlineInputBorder()))),
                        const SizedBox(width: 10),
                        Expanded(child: TextField(controller: nationalIdCtrl, decoration: const InputDecoration(labelText: 'رقم التعريف الوطني', border: OutlineInputBorder()))),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedDept,
                            decoration: const InputDecoration(labelText: 'القسم', border: OutlineInputBorder()),
                            items: const [
                              DropdownMenuItem(value: 'caisse', child: Text('كاشير واستقبال')),
                              DropdownMenuItem(value: 'stock', child: Text('مستودع ورفوف')),
                              DropdownMenuItem(value: 'boucherie', child: Text('ملحمة وأجبان')),
                              DropdownMenuItem(value: 'fruits', child: Text('خضر وفواكه')),
                              DropdownMenuItem(value: 'securite', child: Text('أمن ومراقبة')),
                              DropdownMenuItem(value: 'entretien', child: Text('نظافة وخدمات')),
                              DropdownMenuItem(value: 'admin', child: Text('إدارة ومحاسبة')),
                            ],
                            onChanged: (v) => setModalState(() => selectedDept = v!),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedRole,
                            decoration: const InputDecoration(labelText: 'الرتبة', border: OutlineInputBorder()),
                            items: const [
                              DropdownMenuItem(value: 'cashier', child: Text('كاشير')),
                              DropdownMenuItem(value: 'supervisor', child: Text('مشرف وردية')),
                              DropdownMenuItem(value: 'admin', child: Text('مدير عام')),
                              DropdownMenuItem(value: 'worker', child: Text('عامل عام')),
                            ],
                            onChanged: (v) => setModalState(() => selectedRole = v!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: TextField(controller: salaryCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الأجر الأساسي (دج)', border: OutlineInputBorder()))),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedSalaryType,
                            decoration: const InputDecoration(labelText: 'نوع الأجر', border: OutlineInputBorder()),
                            items: const [
                              DropdownMenuItem(value: 'monthly', child: Text('شهري')),
                              DropdownMenuItem(value: 'daily', child: Text('يومي')),
                            ],
                            onChanged: (v) => setModalState(() => selectedSalaryType = v!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: pinCtrl,
                            keyboardType: TextInputType.number,
                            maxLength: 4,
                            decoration: const InputDecoration(labelText: 'رمز الـ PIN (4 أرقام فريدة) *', border: OutlineInputBorder()),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.casino, color: Colors.teal),
                          tooltip: 'توليد رمز فريد آلياً 🎲',
                          onPressed: () {
                            setModalState(() {
                              pinCtrl.text = StaffService.generateUniquePin();
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: TextField(controller: stationCtrl, decoration: const InputDecoration(labelText: 'الكاشير المفضل', border: OutlineInputBorder()))),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                onPressed: () async {
                  final name = nameCtrl.text.trim();
                  final pin = pinCtrl.text.trim();
                  if (name.isEmpty) {
                    SnackbarHelper.showError(context, 'اسم الموظف مطلوب');
                    return;
                  }
                  if (pin.length != 4) {
                    SnackbarHelper.showError(context, 'رمز الـ PIN يجب أن يتكون من 4 أرقام');
                    return;
                  }
                  if (!StaffService.isPinUnique(pin, excludeId: member?.id)) {
                    SnackbarHelper.showError(context, '❌ هذا الرمز السري مستخدم مسبقاً لعامل آخر! يرجى اختيار رمز فريد.');
                    return;
                  }

                  final id = member?.id ?? 'staff_' + const Uuid().v4().substring(0, 8);
                  final barcode = member?.barcode ?? 'STAFF-' + (1000 + _staffList.length + 1).toString();
                  final salary = double.tryParse(salaryCtrl.text.trim()) ?? 0.0;

                  final newMember = StaffMember(
                    id: id,
                    name: name,
                    phone: phoneCtrl.text.trim(),
                    nationalId: nationalIdCtrl.text.trim(),
                    department: selectedDept,
                    role: selectedRole,
                    pin: pin,
                    barcode: barcode,
                    baseSalary: salary,
                    salaryType: selectedSalaryType,
                    preferredStation: stationCtrl.text.trim(),
                    isActive: member?.isActive ?? true,
                    permissions: member?.permissions,
                  );

                  await StaffService.saveStaff(newMember);
                  Navigator.pop(ctx);
                  SoundService.playSaveSuccess();
                  _loadData();
                },
                child: const Text('حفظ الموظف 💾', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showPermissionsDialog(StaffMember member) {
    final perms = Map<String, dynamic>.from(member.permissions);
    final maxDiscountCtrl = TextEditingController(text: (perms['maxDiscountAmount'] as num?)?.toStringAsFixed(0) ?? '500');
    final maxCreditCtrl = TextEditingController(text: (perms['maxCreditLimit'] as num?)?.toStringAsFixed(0) ?? '3000');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.security, color: Colors.teal),
                const SizedBox(width: 8),
                Text('تخصيص صلاحيات: ${member.name}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            content: SizedBox(
              width: 520,
              child: ListView(
                shrinkWrap: true,
                children: [
                  SwitchListTile(
                    title: const Text('تطبيق التخفيضات (Remise)'),
                    subtitle: const Text('السماح للكاشير بتطبيق تخفيض بالسقف المحدد أسفله'),
                    value: perms['canApplyDiscount'] == true,
                    onChanged: (v) => setModalState(() => perms['canApplyDiscount'] = v),
                  ),
                  if (perms['canApplyDiscount'] == true)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: TextField(
                        controller: maxDiscountCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'سقف التخفيض الأقصى المسموح (دج)', border: OutlineInputBorder()),
                      ),
                    ),
                  const Divider(),
                  SwitchListTile(
                    title: const Text('إلغاء الفواتير والسلع (Void)'),
                    subtitle: const Text('إلغاء السلة بعد المسح (يوصى بإبقائها معطلة للحماية من السرقة)'),
                    value: perms['canVoidInvoice'] == true,
                    onChanged: (v) => setModalState(() => perms['canVoidInvoice'] = v),
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: const Text('البيع بالكريدي (الديون)'),
                    subtitle: const Text('السماح بتسجيل ديون للزبائن بالسقف المحدد'),
                    value: perms['canSellOnCredit'] == true,
                    onChanged: (v) => setModalState(() => perms['canSellOnCredit'] = v),
                  ),
                  if (perms['canSellOnCredit'] == true)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: TextField(
                        controller: maxCreditCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'سقف الدين الأقصى للفاتورة (دج)', border: OutlineInputBorder()),
                      ),
                    ),
                  const Divider(),
                  SwitchListTile(
                    title: const Text('رؤية أسعار الشراء وهوامش الربح'),
                    subtitle: const Text('إخفاء أو إظهار تكلفة السلع وأرباح المتجر'),
                    value: perms['canViewCostPrice'] == true,
                    onChanged: (v) => setModalState(() => perms['canViewCostPrice'] = v),
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: const Text('فتح درج النقود يدوياً'),
                    subtitle: const Text('فتح القجر بزر بدون إتمام عملية بيع'),
                    value: perms['canOpenCashDrawerManually'] == true,
                    onChanged: (v) => setModalState(() => perms['canOpenCashDrawerManually'] = v),
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: const Text('تعديل سعر البيع المباشر'),
                    subtitle: const Text('تغيير سعر بيع السلعة في الكاشير مباشرة'),
                    value: perms['canModifyProductPrice'] == true,
                    onChanged: (v) => setModalState(() => perms['canModifyProductPrice'] = v),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                onPressed: () async {
                  perms['maxDiscountAmount'] = double.tryParse(maxDiscountCtrl.text.trim()) ?? 500.0;
                  perms['maxCreditLimit'] = double.tryParse(maxCreditCtrl.text.trim()) ?? 3000.0;
                  final updated = member.copyWith(permissions: perms);
                  await StaffService.saveStaff(updated);
                  Navigator.pop(ctx);
                  SoundService.playSaveSuccess();
                  _loadData();
                },
                child: const Text('حفظ الصلاحيات 💾', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddAdvanceDialog(StaffMember member) {
    final amountCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String type = 'advance_cash';
    bool deductFromCash = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text('تسجيل تسبيق / سلفة: ${member.name}', style: const TextStyle(fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: type,
                  decoration: const InputDecoration(labelText: 'نوع الحركة المالية', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'advance_cash', child: Text('تسبيق نقدي (Avance Espèces)')),
                    DropdownMenuItem(value: 'advance_goods', child: Text('سحب سلع استهلاك من المتجر')),
                    DropdownMenuItem(value: 'bonus', child: Text('منحة / مكافأة (+) (+ Prime)')),
                    DropdownMenuItem(value: 'deduction', child: Text('خصم / غياب (-) (- Retenue)')),
                  ],
                  onChanged: (v) => setModalState(() => type = v!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'المبلغ (د.ج) *', prefixIcon: Icon(Icons.payments), border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(labelText: 'ملاحظة أو سبب التسبيق...', border: OutlineInputBorder()),
                ),
                if (type == 'advance_cash') ...[
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    title: const Text('صرف من صندوق الكاشير (يخصم من نقدية المتجر)', style: TextStyle(fontSize: 12.5)),
                    value: deductFromCash,
                    onChanged: (v) => setModalState(() => deductFromCash = v ?? true),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                onPressed: () async {
                  final amount = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                  if (amount <= 0) {
                    SnackbarHelper.showError(context, 'المبلغ يجب أن يكون أكبر من الصفر');
                    return;
                  }
                  await PayrollService.addRecord(
                    staff: member,
                    type: type,
                    amount: amount,
                    notes: notesCtrl.text.trim(),
                    deductFromCashDrawer: deductFromCash,
                  );
                  Navigator.pop(ctx);
                  SoundService.playSaveSuccess();
                  SnackbarHelper.showSuccess(context, 'تم تسجيل الحركة المالية وترحيلها بنجاح!');
                  _loadData();
                },
                child: const Text('تأكيد وحفظ 💾', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showSalarySettlementDialog(StaffMember staff, Map<String, dynamic> data) {
    final net = (data['netPayable'] as double);
    final isSettled = data['alreadySettled'] == true;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.receipt_long, color: Colors.teal),
            const SizedBox(width: 8),
            Text('تصفية راتب: ${staff.name}', style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('الشهر: $_selectedMonth'),
            const Divider(),
            _buildDialogRow('الراتب الأساسي:', '${(data['baseSalary'] as double).toStringAsFixed(2)} دج'),
            _buildDialogRow('(+) المكافآت:', '${(data['bonuses'] as double).toStringAsFixed(2)} دج', color: Colors.green),
            _buildDialogRow('(-) التسبيقات النقدية:', '${(data['advancesCash'] as double).toStringAsFixed(2)} دج', color: Colors.red),
            _buildDialogRow('(-) سحب سلع للمنزل:', '${(data['advancesGoods'] as double).toStringAsFixed(2)} دج', color: Colors.orange),
            _buildDialogRow('(-) الخصومات:', '${(data['deductions'] as double).toStringAsFixed(2)} دج', color: Colors.red),
            const Divider(thickness: 1.5),
            _buildDialogRow('الصافي المستحق للصرف:', '${net.toStringAsFixed(2)} دج', isBold: true, color: Colors.teal.shade900),
            if (isSettled)
              Container(
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 18),
                    SizedBox(width: 6),
                    Text('تمت تصفية هذا الشهر ودفع الراتب مسبقاً', style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق')),
          if (!isSettled)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
              icon: const Icon(Icons.payments, color: Colors.white),
              label: const Text('تأكيد الدفع وترحيل المصروف 💵', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              onPressed: () async {
                await PayrollService.settleMonthlySalary(
                  staff: staff,
                  monthStr: _selectedMonth,
                  netPaidAmount: net,
                );
                Navigator.pop(ctx);
                SoundService.playCheckoutSuccess();
                SnackbarHelper.showSuccess(context, '🎉 تم دفع الراتب وترحيل المصروف بنجاح!');
                _loadData();
              },
            ),
        ],
      ),
    );
  }

  Widget _buildDialogRow(String title, String val, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(fontSize: 13, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(val, style: TextStyle(fontSize: 13, fontWeight: isBold ? FontWeight.bold : FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}
