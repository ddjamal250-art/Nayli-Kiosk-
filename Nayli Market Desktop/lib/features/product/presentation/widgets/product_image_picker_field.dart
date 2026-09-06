import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/product_image_search_service.dart';

class ProductImagePickerField extends StatefulWidget {
  final String? initialImageUrl;
  final String barcode;
  final String productName;
  final ValueChanged<String?> onImageChanged;

  const ProductImagePickerField({
    super.key,
    this.initialImageUrl,
    required this.barcode,
    required this.productName,
    required this.onImageChanged,
  });

  @override
  State<ProductImagePickerField> createState() => _ProductImagePickerFieldState();
}

class _ProductImagePickerFieldState extends State<ProductImagePickerField> {
  String? _currentImageUrl;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _currentImageUrl = widget.initialImageUrl;
  }

  @override
  void didUpdateWidget(covariant ProductImagePickerField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialImageUrl != oldWidget.initialImageUrl && widget.initialImageUrl != _currentImageUrl) {
      _currentImageUrl = widget.initialImageUrl;
    }
  }

  void _setImage(String? path) {
    setState(() => _currentImageUrl = path);
    widget.onImageChanged(path);
  }

  Future<void> _pickImage(ImageSource source) async {
    setState(() => _isLoading = true);
    try {
      final path = await ProductImageSearchService.instance.pickAndSaveImage(source: source);
      if (path != null) {
        _setImage(path);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openWebImageSearch() {
    final queryCtrl = TextEditingController(
      text: widget.productName.isNotEmpty ? widget.productName : widget.barcode,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const Icon(Icons.cloud_download_outlined, color: AppTheme.primaryColor),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'البحث عن صورة السلعة في الإنترنت 🌐',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: queryCtrl,
                          decoration: InputDecoration(
                            hintText: 'اكتب اسم المنتج بدقة...',
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          onSubmitted: (_) => setModalState(() {}),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => setModalState(() {}),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        child: const Text('بحث 🔍', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ),
                // External Google Search & URL Paste Quick Actions
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ActionChip(
                          avatar: const Icon(Icons.travel_explore, size: 16, color: Colors.blue),
                          label: const Text('فتح بحث صور Google 🌐', style: TextStyle(fontSize: 12)),
                          backgroundColor: Colors.blue.shade50,
                          onPressed: () async {
                            final q = queryCtrl.text.trim().isNotEmpty
                                ? queryCtrl.text.trim()
                                : widget.productName;
                            if (q.isNotEmpty) {
                              final googleUrl = Uri.parse(
                                'https://www.google.com/search?tbm=isch&q=${Uri.encodeComponent(q)}',
                              );
                              if (await canLaunchUrl(googleUrl)) {
                                await launchUrl(googleUrl, mode: LaunchMode.externalApplication);
                              }
                            }
                          },
                        ),
                        const SizedBox(width: 8),
                        ActionChip(
                          avatar: const Icon(Icons.link, size: 16, color: Colors.green),
                          label: const Text('لصق رابط صورة 🔗', style: TextStyle(fontSize: 12)),
                          backgroundColor: Colors.green.shade50,
                          onPressed: () async {
                            final linkCtrl = TextEditingController();
                            final pasted = await showDialog<String>(
                              context: context,
                              builder: (dCtx) => AlertDialog(
                                title: const Text('لصق رابط الصورة مباشرة'),
                                content: TextField(
                                  controller: linkCtrl,
                                  decoration: const InputDecoration(
                                    hintText: 'https://example.com/image.jpg',
                                    prefixIcon: Icon(Icons.link),
                                  ),
                                  autofocus: true,
                                ),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('إلغاء')),
                                  ElevatedButton(
                                    onPressed: () => Navigator.pop(dCtx, linkCtrl.text.trim()),
                                    child: const Text('حفظ واستخدام'),
                                  ),
                                ],
                              ),
                            );
                            if (pasted != null && pasted.startsWith('http')) {
                              Navigator.pop(ctx);
                              setState(() => _isLoading = true);
                              try {
                                final localPath = await ProductImageSearchService.instance
                                    .downloadAndSaveImageLocally(pasted);
                                _setImage(localPath ?? pasted);
                              } finally {
                                if (mounted) setState(() => _isLoading = false);
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 16),
                Expanded(
                  child: FutureBuilder<List<ProductImageSearchResult>>(
                    future: ProductImageSearchService.instance.searchImages(
                      barcode: widget.barcode,
                      query: queryCtrl.text.trim(),
                    ),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 12),
                              Text('جاري جلب الصور من قواعد البيانات والمصادر... 🔎'),
                            ],
                          ),
                        );
                      }

                      final results = snapshot.data ?? [];
                      if (results.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.image_not_supported_outlined, size: 54, color: Colors.grey[400]),
                                const SizedBox(height: 12),
                                const Text(
                                  'لم نجد صوراً مطابقة مباشرة في الإنترنت',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'يمكنك تغيير كلمات البحث أعلاه، أو استخدام زر بحث صور Google، أو التقاط صورة بالهاتف مباشرة 📷',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return GridView.builder(
                        padding: const EdgeInsets.all(12),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 0.82,
                        ),
                        itemCount: results.length,
                        itemBuilder: (ctx, i) {
                          final item = results[i];
                          return Card(
                            elevation: 2,
                            clipBehavior: Clip.antiAlias,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.grey.shade200),
                            ),
                            child: InkWell(
                              onTap: () async {
                                Navigator.pop(ctx);
                                setState(() => _isLoading = true);
                                try {
                                  final localPath = await ProductImageSearchService.instance
                                      .downloadAndSaveImageLocally(item.url);
                                  _setImage(localPath ?? item.url);
                                } finally {
                                  if (mounted) setState(() => _isLoading = false);
                                }
                              },
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        Image.network(
                                          item.url,
                                          fit: BoxFit.contain,
                                          errorBuilder: (_, __, ___) => Center(
                                            child: Icon(Icons.broken_image, color: Colors.grey[400], size: 36),
                                          ),
                                          loadingBuilder: (context, child, progress) {
                                            if (progress == null) return child;
                                            return const Center(
                                              child: SizedBox(
                                                width: 24,
                                                height: 24,
                                                child: CircularProgressIndicator(strokeWidth: 2),
                                              ),
                                            );
                                          },
                                        ),
                                        Positioned(
                                          top: 6,
                                          right: 6,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withOpacity(0.65),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              item.source,
                                              style: const TextStyle(color: Colors.white, fontSize: 9.5),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    color: Colors.grey.shade50,
                                    padding: const EdgeInsets.all(6),
                                    child: Text(
                                      item.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildImagePreview() {
    if (_currentImageUrl == null || _currentImageUrl!.trim().isEmpty) {
      return Container(
        height: 140,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey[300]!, style: BorderStyle.solid),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_photo_alternate_outlined, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 6),
              Text(
                'لم يتم تحديد صورة للمنتج بعد',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    return FutureBuilder<String?>(
      future: _resolveImagePath(_currentImageUrl),
      builder: (context, snapshot) {
        final resolvedPath = snapshot.data;
        final isWeb = resolvedPath != null && resolvedPath.startsWith('http');
        final isFile = resolvedPath != null && !isWeb && File(resolvedPath).existsSync();

        return Container(
          height: 160,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.primaryColor.withOpacity(0.4)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (isWeb)
                Image.network(
                  resolvedPath,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Center(
                    child: Icon(Icons.broken_image, size: 40, color: Colors.grey),
                  ),
                )
              else if (isFile)
                Image.file(
                  File(resolvedPath),
                  fit: BoxFit.contain,
                )
              else
                const Center(
                  child: Icon(Icons.image_not_supported, size: 40, color: Colors.grey),
                ),
              Positioned(
                top: 8,
                right: 8,
                child: CircleAvatar(
                  backgroundColor: Colors.red.withOpacity(0.85),
                  radius: 16,
                  child: IconButton(
                    icon: const Icon(Icons.delete_outline, size: 16, color: Colors.white),
                    onPressed: () => _setImage(null),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<String?> _resolveImagePath(String? path) async {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http')) return path;
    
    // We assume the user has a cross-platform synced path like "images/xyz.jpg" or "C:\\xyz"
    final filename = path.split(RegExp(r'[\\/]')).last;
    if (filename.isEmpty) return null;
    
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final imgDir = Directory('${docDir.path}/NayliMarket/images');
      final newPath = '${imgDir.path}/$filename';
      if (File(newPath).existsSync()) return newPath;
      if (File(path).existsSync()) return path;
    } catch (_) {}
    return path;
  }


  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildImagePreview(),
        const SizedBox(height: 10),
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(child: CircularProgressIndicator()),
          )
        else
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _openWebImageSearch,
                  icon: const Icon(Icons.cloud_download, size: 18),
                  label: const Text('جلب من الإنترنت 🌐', style: TextStyle(fontSize: 12.5)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                icon: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: const Icon(Icons.camera_alt_outlined, color: Colors.black87),
                ),
                tooltip: 'خيارات أخرى للصور',
                onSelected: (val) {
                  if (val == 'camera') {
                    _pickImage(ImageSource.camera);
                  } else if (val == 'gallery') {
                    _pickImage(ImageSource.gallery);
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'camera',
                    child: Row(
                      children: [
                        Icon(Icons.camera_alt, size: 18, color: Colors.blue),
                        SizedBox(width: 8),
                        Text('التقاط صورة بالكاميرا 📷'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'gallery',
                    child: Row(
                      children: [
                        Icon(Icons.photo_library, size: 18, color: Colors.deepPurple),
                        SizedBox(width: 8),
                        Text('اختيار من المعرض 🖼️'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
      ],
    );
  }
}
