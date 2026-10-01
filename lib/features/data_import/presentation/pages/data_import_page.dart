import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/theme/app_theme.dart';
import '../data/import_result.dart';
import '../data/analysis_engine.dart';
import '../data/smart_data_importer.dart';
import '../widgets/live_analysis_console.dart';

enum _ImportStep { selectFile, analyzing, preview, importing, results }

class DataImportPage extends StatefulWidget {
  const DataImportPage({Key? key}) : super(key: key);

  @override
  State<DataImportPage> createState() => _DataImportPageState();
}

class _DataImportPageState extends State<DataImportPage> {
  _ImportStep _currentStep = _ImportStep.selectFile;
  String? _selectedFilePath;
  Stream<AnalysisEvent>? _analysisStream;
  AnalysisSummary? _summary;
  ImportResult? _result;

  bool _importCustomers = true;
  bool _importSuppliers = true;
  bool _importProducts = true;
  bool _importImages = true;

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['sqlite', 'db', 'sqlite3', 'zip'],
      dialogTitle: 'اختر ملف قاعدة البيانات أو ملف ZIP',
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedFilePath = result.files.single.path!;
        _currentStep = _ImportStep.analyzing;
        _analysisStream = AnalysisEngine().analyze(_selectedFilePath!);
      });
    }
  }

  void _onAnalysisComplete(AnalysisSummary summary) {
    setState(() {
      _summary = summary;
      _currentStep = _ImportStep.preview;
    });
  }

  Future<void> _startImport() async {
    setState(() {
      _currentStep = _ImportStep.importing;
    });
    
    final result = await SmartDataImporter().importData(
      _selectedFilePath!,
      _summary!,
      importCustomers: _importCustomers,
      importSuppliers: _importSuppliers,
      importProducts: _importProducts,
      importImages: _importImages,
    );

    setState(() {
      _result = result;
      _currentStep = _ImportStep.results;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('استيراد ذكي للبيانات'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    switch (_currentStep) {
      case _ImportStep.selectFile:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.file_upload_outlined, size: 100, color: AppTheme.primaryColor.withOpacity(0.5)),
              const SizedBox(height: 24),
              const Text(
                'استيراد بيانات من برنامج خارجي',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                'يدعم ملفات قواعد البيانات (SQLite) أو ملفات ZIP المحتوية على قاعدة بيانات وصور.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _pickFile,
                icon: const Icon(Icons.folder_open),
                label: const Text('اختر الملف (SQLite/ZIP)'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  textStyle: const TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
        );
        
      case _ImportStep.analyzing:
        return LiveAnalysisConsole(
          stream: _analysisStream!,
          onComplete: (summary) {
            _onAnalysisComplete(summary);
          },
        );
        
      case _ImportStep.preview:
        if (_summary == null) return const SizedBox();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('☑️ اختر البيانات التي تريد استيرادها', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            Expanded(
              child: ListView(
                children: [
                  CheckboxListTile(
                    value: _importCustomers,
                    onChanged: _summary!.customersFound > 0 ? (v) => setState(() => _importCustomers = v!) : null,
                    title: Text('👤 الزبائن (\${_summary!.customersFound})'),
                    subtitle: Text('يتضمن استيراد \${_summary!.customerDebts.length} ديون حقيقية'),
                    activeColor: AppTheme.primaryColor,
                  ),
                  CheckboxListTile(
                    value: _importSuppliers,
                    onChanged: _summary!.suppliersFound > 0 ? (v) => setState(() => _importSuppliers = v!) : null,
                    title: Text('🏭 الموردين (\${_summary!.suppliersFound})'),
                    subtitle: Text(_summary!.suppliersFound > 0 ? 'يتضمن استيراد الديون والسجلات التجارية' : 'لا توجد بيانات موردين'),
                    activeColor: AppTheme.primaryColor,
                  ),
                  CheckboxListTile(
                    value: _importProducts,
                    onChanged: _summary!.productsFound > 0 ? (v) => setState(() => _importProducts = v!) : null,
                    title: Text('📦 المنتجات (\${_summary!.productsFound})'),
                    subtitle: const Text('يتضمن الأسعار، الأصناف، الوحدات، والكميات'),
                    activeColor: AppTheme.primaryColor,
                  ),
                  CheckboxListTile(
                    value: _importImages,
                    onChanged: _summary!.imagesFound > 0 ? (v) => setState(() => _importImages = v!) : null,
                    title: Text('📸 صور المنتجات (\${_summary!.imagesFound})'),
                    activeColor: AppTheme.primaryColor,
                  ),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => setState(() => _currentStep = _ImportStep.selectFile),
                  child: const Text('◀ تراجع'),
                ),
                ElevatedButton.icon(
                  onPressed: _startImport,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('▶ بدء الاستيراد'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          ],
        );
        
      case _ImportStep.importing:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              const Text('جاري استيراد البيانات، يرجى الانتظار...', style: TextStyle(fontSize: 18)),
            ],
          ),
        );
        
      case _ImportStep.results:
        if (_result == null) return const SizedBox();
        return Column(
          children: [
            const Icon(Icons.check_circle, size: 80, color: Colors.green),
            const SizedBox(height: 16),
            const Text('تم الاستيراد بنجاح!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green)),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    ListTile(leading: const Icon(Icons.person), title: Text('الزبائن: \${_result!.customersImported}')),
                    ListTile(leading: const Icon(Icons.business), title: Text('الموردين: \${_result!.suppliersImported}')),
                    ListTile(leading: const Icon(Icons.inventory), title: Text('المنتجات: \${_result!.productsImported}')),
                    ListTile(leading: const Icon(Icons.image), title: Text('الصور: \${_result!.imagesImported}')),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_result!.skippedCount > 0 || _result!.errorCount > 0)
              Text('تنبيه: تم تخطي \${_result!.skippedCount} مكرر، وفشل \${_result!.errorCount}', style: const TextStyle(color: Colors.orange)),
            const Spacer(),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('العودة للإعدادات'),
            ),
          ],
        );
    }
  }
}
