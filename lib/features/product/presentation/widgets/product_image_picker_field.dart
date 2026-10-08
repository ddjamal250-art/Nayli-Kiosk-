import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/product_image_search_service.dart';
import '../../../../core/utils/product_image_helper.dart';

enum ProductImageSearchMode { combined, barcodeOnly, nameOnly }

class ProductImagePickerField extends StatefulWidget {
  final String? initialImageUrl;
  final String? initialImagePath;
  final String barcode;
  final String productName;
  final ValueChanged<String?> onImageChanged;

  const ProductImagePickerField({
    super.key,
    this.initialImageUrl,
    this.initialImagePath,
    this.barcode = '',
    this.productName = '',
    required this.onImageChanged,
  });

  @override
  State<ProductImagePickerField> createState() => _ProductImagePickerFieldState();
}

class _ProductImagePickerFieldState extends State<ProductImagePickerField> {
  String? _currentImageUrl;
  bool _isLoading = false;
  bool _isAutoFetching = false;

  @override
  void initState() {
    super.initState();
    _currentImageUrl = widget.initialImageUrl ?? widget.initialImagePath;
  }

  @override
  void didUpdateWidget(covariant ProductImagePickerField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final effectiveUrl = widget.initialImageUrl ?? widget.initialImagePath;
    final oldEffectiveUrl = oldWidget.initialImageUrl ?? oldWidget.initialImagePath;
    if (effectiveUrl != oldEffectiveUrl && effectiveUrl != _currentImageUrl) {
      _currentImageUrl = effectiveUrl;
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

  /// Fast one-click auto-fetch from Master Catalog, Open Food Facts, or Web by Barcode/Name
  Future<void> _autoFetchImage() async {
    final bc = widget.barcode.trim();
    final nm = widget.productName.trim();
    if (bc.isEmpty && nm.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى كتابة أو مسح الباركود أو اسم المنتج أولاً لجلب الصورة تلقائياً ⚠️'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isAutoFetching = true);
    try {
      final localPath = await ProductImageSearchService.instance.autoFetchProductImage(
        barcode: bc,
        name: nm,
      );

      if (!mounted) return;

      if (localPath != null && localPath.isNotEmpty) {
        _setImage(localPath);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.bolt, color: Colors.amber),
                SizedBox(width: 8),
                Expanded(child: Text('تم جلب صورة المنتج وحفظها محلياً بنجاح! ⚡ (يمكنك تعديلها بأي وقت)')),
              ],
            ),
            backgroundColor: Color(0xFF1B5E20),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('لم نجد صورة مطابقة تلقائياً. يمكنك الضغط على "بحث في الإنترنت" لاختيار صورة يدوياً.'),
            action: SnackBarAction(
              label: 'بحث الآن',
              textColor: Colors.amber,
              onPressed: _openWebImageSearch,
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء الجلب التلقائي: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isAutoFetching = false);
    }
  }

  void _openWebImageSearch() {
    final initialBarcode = widget.barcode.trim();
    final initialName = widget.productName.trim();

    ProductImageSearchMode currentMode = ProductImageSearchMode.combined;
    if (initialBarcode.isNotEmpty && initialName.isEmpty) {
      currentMode = ProductImageSearchMode.barcodeOnly;
    } else if (initialName.isNotEmpty && initialBarcode.isEmpty) {
      currentMode = ProductImageSearchMode.nameOnly;
    }

    String computeQuery(ProductImageSearchMode mode) {
      switch (mode) {
        case ProductImageSearchMode.combined:
          return '$initialName $initialBarcode'.trim();
        case ProductImageSearchMode.barcodeOnly:
          return initialBarcode;
        case ProductImageSearchMode.nameOnly:
          return initialName;
      }
    }

    final queryCtrl = TextEditingController(text: computeQuery(currentMode));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final activeQuery = queryCtrl.text.trim();
          final searchBarcode = (currentMode == ProductImageSearchMode.barcodeOnly || currentMode == ProductImageSearchMode.combined)
              ? initialBarcode
              : null;

          return Container(
            height: MediaQuery.of(context).size.height * 0.88,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Handle bar
                Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.image_search_rounded, color: AppTheme.primaryColor, size: 22),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'البحث عن صورة السلعة في الإنترنت 🌐',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'جلب من دليل السلع الجزائري، Open Food Facts، ومحركات الصور العالمية',
                              style: TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                // Quick Mode Selector Chips
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        FilterChip(
                          selected: currentMode == ProductImageSearchMode.combined,
                          label: const Text('⚡ بحث مدمج (الاسم + الباركود)', style: TextStyle(fontSize: 11)),
                          onSelected: (_) {
                            setModalState(() {
                              currentMode = ProductImageSearchMode.combined;
                              queryCtrl.text = computeQuery(ProductImageSearchMode.combined);
                            });
                          },
                        ),
                        const SizedBox(width: 6),
                        if (initialBarcode.isNotEmpty)
                          FilterChip(
                            selected: currentMode == ProductImageSearchMode.barcodeOnly,
                            avatar: const Icon(Icons.qr_code, size: 14),
                            label: Text('بحث بالباركود ($initialBarcode)', style: const TextStyle(fontSize: 11)),
                            onSelected: (_) {
                              setModalState(() {
                                currentMode = ProductImageSearchMode.barcodeOnly;
                                queryCtrl.text = computeQuery(ProductImageSearchMode.barcodeOnly);
                              });
                            },
                          ),
                        const SizedBox(width: 6),
                        if (initialName.isNotEmpty)
                          FilterChip(
                            selected: currentMode == ProductImageSearchMode.nameOnly,
                            avatar: const Icon(Icons.title, size: 14),
                            label: Text('بحث بالاسم ($initialName)', style: const TextStyle(fontSize: 11)),
                            onSelected: (_) {
                              setModalState(() {
                                currentMode = ProductImageSearchMode.nameOnly;
                                queryCtrl.text = computeQuery(ProductImageSearchMode.nameOnly);
                              });
                            },
                          ),
                      ],
                    ),
                  ),
                ),
                // Search Input Field
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
                            suffixIcon: queryCtrl.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 16),
                                    onPressed: () {
                                      queryCtrl.clear();
                                      setModalState(() {});
                                    },
                                  )
                                : null,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          onSubmitted: (_) => setModalState(() {}),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () => setModalState(() {}),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.search, size: 18),
                        label: const Text('بحث'),
                      ),
                    ],
                  ),
                ),
                // Action Chips: Google Image tab & Paste Link
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ActionChip(
                          avatar: const Icon(Icons.open_in_browser, size: 15, color: Colors.blue),
                          label: const Text('فتح بحث صور Google 🌐', style: TextStyle(fontSize: 11)),
                          onPressed: () {
                            final q = queryCtrl.text.trim().isNotEmpty
                                ? queryCtrl.text.trim()
                                : (initialName.isNotEmpty ? initialName : initialBarcode);
                            if (q.isNotEmpty) {
                              final uri = Uri.parse('https://www.google.com/search?tbm=isch&q=${Uri.encodeComponent(q)}');
                              launchUrl(uri, mode: LaunchMode.externalApplication);
                            }
                          },
                        ),
                        const SizedBox(width: 8),
                        ActionChip(
                          avatar: const Icon(Icons.link, size: 15, color: Colors.teal),
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
                                    .downloadAndSaveImageLocally(pasted, barcode: widget.barcode);
                                _setImage(localPath ?? pasted);
                              } finally {
                                if (mounted) setState(() => _isLoading = false);
                              }
                            }
                          },
                        ),
                        const SizedBox(width: 8),
                        ActionChip(
                          avatar: const Icon(Icons.photo_library, size: 15, color: Colors.indigo),
                          label: const Text('اختيار من الجهاز 🖼️', style: TextStyle(fontSize: 11)),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _pickImage(ImageSource.gallery);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 12),
                // Search Results Grid
                Expanded(
                  child: FutureBuilder<List<ProductImageSearchResult>>(
                    future: ProductImageSearchService.instance.searchImages(
                      barcode: searchBarcode,
                      query: activeQuery,
                    ),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 12),
                              Text('جاري البحث السريع في قواعد البيانات ومحركات الصور... 🔎'),
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
                                  'لم نجد صوراً مطابقة مباشرة بالعبارة الحالية',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'جرب البحث باسم المنتج بالفرنسية أو العربية أو لصق رابط صورة مباشرة 🖼️',
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
                        itemBuilder: (context, index) {
                          final item = results[index];
                          return InkWell(
                            onTap: () async {
                              Navigator.pop(ctx);
                              setState(() => _isLoading = true);
                              try {
                                final localPath = await ProductImageSearchService.instance
                                    .downloadAndSaveImageLocally(item.url, barcode: widget.barcode);
                                _setImage(localPath ?? item.url);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('تم حفظ الصورة بنجاح في قاعدة البيانات المحلية! ⚡'),
                                      duration: Duration(seconds: 2),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
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
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
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
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            Icon(Icons.verified, size: 11, color: AppTheme.primaryColor),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                item.source,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(fontSize: 9.5, color: Colors.grey[600]),
                                              ),
                                            ),
                                          ],
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
    if (_isLoading || _isAutoFetching) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(strokeWidth: 2.5),
            SizedBox(height: 6),
            Text('جاري الحفظ...', style: TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      );
    }

    if (_currentImageUrl == null || _currentImageUrl!.isEmpty) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_photo_alternate_outlined, size: 38, color: Colors.grey[400]),
          const SizedBox(height: 4),
          Text(
            'لا توجد صورة',
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          ),
        ],
      );
    }

    final resolved = ProductImageHelper.resolveImagePathSync(_currentImageUrl);
    final targetPath = (resolved != null && resolved.isNotEmpty) ? resolved : _currentImageUrl!;
    final isNetwork = targetPath.startsWith('http://') || targetPath.startsWith('https://');

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: isNetwork
          ? Image.network(
              targetPath,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 36, color: Colors.grey),
            )
          : Image.file(
              File(targetPath),
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 36, color: Colors.grey),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = _currentImageUrl != null && _currentImageUrl!.isNotEmpty;

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
                width: 95,
                height: 95,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: _buildImagePreview(),
              ),
              const SizedBox(width: 12),
              // Buttons
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Auto-fetch button (Fast 1-touch lookup)
                    FilledButton.icon(
                      onPressed: (_isAutoFetching || _isLoading) ? null : _autoFetchImage,
                      icon: _isAutoFetching
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.bolt_rounded, size: 18, color: Colors.amber),
                      label: Text(
                        _isAutoFetching ? 'جاري الجلب التلقائي...' : '⚡ جلب تلقائي للصورة',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0F5B46),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Web Image Search modal
                    OutlinedButton.icon(
                      onPressed: _openWebImageSearch,
                      icon: const Icon(Icons.travel_explore, size: 16),
                      label: const Text('بحث صور بالإنترنت 🌐', style: TextStyle(fontSize: 11)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Gallery pick
                    Row(
                      children: [
                        Expanded(
                          child: TextButton.icon(
                            onPressed: () => _pickImage(ImageSource.gallery),
                            icon: const Icon(Icons.photo_library_outlined, size: 15),
                            label: const Text('من الحاسوب 🖼️', style: TextStyle(fontSize: 11)),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              minimumSize: const Size(40, 28),
                            ),
                          ),
                        ),
                        if (hasImage) ...[
                          const SizedBox(width: 4),
                          TextButton.icon(
                            onPressed: () => _setImage(null),
                            icon: const Icon(Icons.delete_outline, size: 15, color: Colors.red),
                            label: const Text('حذف', style: TextStyle(color: Colors.red, fontSize: 11)),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              minimumSize: const Size(40, 28),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Status indicator info
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: hasImage ? Colors.green.withOpacity(0.08) : Colors.blue.withOpacity(0.06),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: hasImage ? Colors.green.withOpacity(0.2) : Colors.blue.withOpacity(0.15),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  hasImage ? Icons.check_circle_rounded : Icons.info_outline,
                  size: 14,
                  color: hasImage ? Colors.green[700] : Colors.blue[700],
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    hasImage
                        ? 'الصورة محفوظة محلياً في قاعدة البيانات بشكل دائم ولا تُفقد أبداً حتى بدون إنترنت 🔒'
                        : 'يمكنك جلب صورة المنتج تلقائياً بالضغط على زر ⚡ أو كتابة الباركود والاسم.',
                    style: TextStyle(
                      fontSize: 10,
                      color: hasImage ? Colors.green[800] : Colors.blueGrey,
                      fontWeight: FontWeight.w500,
                    ),
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
