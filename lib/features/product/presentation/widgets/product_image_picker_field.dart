import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: queryCtrl,
                          decoration: InputDecoration(
                            hintText: 'ابحث بالاسم، الماركة، أو الباركود...',
                            prefixIcon: const Icon(Icons.search, size: 20),
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
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('بحث'),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ActionChip(
                          avatar: const Icon(Icons.open_in_browser, size: 16, color: Colors.blue),
                          label: const Text('فتح بحث صور Google 🌐', style: TextStyle(fontSize: 11)),
                          onPressed: () {
                            final q = queryCtrl.text.trim().isNotEmpty ? queryCtrl.text.trim() : widget.barcode;
                            if (q.isNotEmpty) {
                              final uri = Uri.parse('https://www.google.com/search?tbm=isch&q=${Uri.encodeComponent(q)}');
                              launchUrl(uri, mode: LaunchMode.externalApplication);
                            }
                          },
                        ),
                        const SizedBox(width: 8),
                        ActionChip(
                          avatar: const Icon(Icons.link, size: 16, color: Colors.teal),
                          label: const Text('لصق رابط صورة 🔗', style: TextStyle(fontSize: 11)),
                          onPressed: () async {
                            final urlCtrl = TextEditingController();
                            final pasted = await showDialog<String>(
                              context: context,
                              builder: (dialogCtx) => AlertDialog(
                                title: const Text('لصق رابط صورة مباشرة 🔗', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                                content: TextField(
                                  controller: urlCtrl,
                                  decoration: const InputDecoration(
                                    hintText: 'https://example.com/image.jpg',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('إلغاء')),
                                  ElevatedButton(
                                    onPressed: () => Navigator.pop(dialogCtx, urlCtrl.text.trim()),
                                    child: const Text('استخدام الصورة'),
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
                const Divider(height: 1),
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
                              Text('جاري جلب الصور من قواعد البيانات المفتوحة... 🔎'),
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
                                  'يمكنك تغيير كلمات البحث أعلاه أو التقاط صورة بالهاتف مباشرة 📷',
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
                          childAspectRatio: 0.85,
                        ),
                        itemCount: results.length,
                        itemBuilder: (context, index) {
                          final item = results[index];
                          return InkWell(
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
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey[300]!),
                                color: Colors.grey[50],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                      child: Image.network(
                                        item.url,
                                        fit: BoxFit.contain,
                                        errorBuilder: (_, __, ___) => const Center(
                                          child: Icon(Icons.broken_image, color: Colors.grey),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                        ),
                                        Text(
                                          item.source,
                                          style: TextStyle(fontSize: 9.5, color: Colors.grey[600]),
                                        ),
                                      ],
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
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_currentImageUrl == null || _currentImageUrl!.isEmpty) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_photo_alternate_outlined, size: 42, color: Colors.grey[400]),
          const SizedBox(height: 6),
          Text(
            'لا توجد صورة للمنتج',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      );
    }

    final isLocal = !_currentImageUrl!.startsWith('http');
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: isLocal
          ? Image.file(
              File(_currentImageUrl!),
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 40, color: Colors.grey),
            )
          : Image.network(
              _currentImageUrl!,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 40, color: Colors.grey),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image container
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: _buildImagePreview(),
              ),
              const SizedBox(width: 14),
              // Buttons
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: _openWebImageSearch,
                      icon: const Icon(Icons.travel_explore, size: 18),
                      label: const Text('بحث صورة بالإنترنت 🌐', style: TextStyle(fontSize: 12)),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickImage(ImageSource.camera),
                            icon: const Icon(Icons.camera_alt_outlined, size: 16),
                            label: const Text('كاميرا 📷', style: TextStyle(fontSize: 11)),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickImage(ImageSource.gallery),
                            icon: const Icon(Icons.photo_library_outlined, size: 16),
                            label: const Text('معرض 🖼️', style: TextStyle(fontSize: 11)),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_currentImageUrl != null && _currentImageUrl!.isNotEmpty)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => _setImage(null),
                          icon: const Icon(Icons.delete_outline, size: 15, color: Colors.red),
                          label: const Text('إزالة الصورة', style: TextStyle(color: Colors.red, fontSize: 11)),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(50, 26),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.06),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, size: 13, color: Colors.blue),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'الصور تظهر في الشاشة وكتالوج المحل فقط، ولا تُطبع نهائياً على إيصال الزبون الورقي.',
                    style: TextStyle(fontSize: 10, color: Colors.blueGrey, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
