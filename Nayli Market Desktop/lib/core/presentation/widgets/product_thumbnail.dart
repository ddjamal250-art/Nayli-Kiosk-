import 'dart:io';
import 'package:flutter/material.dart';
import '../../utils/image_helper.dart';

class ProductThumbnail extends StatelessWidget {
  final String? imageUrl;
  final String category;
  final double size;
  final double borderRadius;

  const ProductThumbnail({
    Key? key,
    required this.imageUrl,
    required this.category,
    this.size = 50.0,
    this.borderRadius = 8.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return _buildPlaceholder();
    }

    return FutureBuilder<String?>(
      future: ImageHelper.resolveImagePath(imageUrl!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            width: size,
            height: size,
            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }

        final path = snapshot.data;
        if (path == null || path.isEmpty) {
          return _buildPlaceholder();
        }

        Widget imageWidget;
        if (path.startsWith('http')) {
          imageWidget = Image.network(
            path,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildPlaceholder(),
          );
        } else {
          final file = File(path);
          if (file.existsSync()) {
            imageWidget = Image.file(
              file,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildPlaceholder(),
            );
          } else {
            imageWidget = _buildPlaceholder();
          }
        }

        return ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: imageWidget,
        );
      },
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.blueGrey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: Colors.blueGrey.withOpacity(0.2)),
      ),
      alignment: Alignment.center,
      child: Text(
        _getEmojiFromCategory(category),
        style: TextStyle(fontSize: size * 0.45),
      ),
    );
  }

  String _getEmojiFromCategory(String cat) {
    final match = RegExp(r'([\u2600-\u27BF]|[\uD83C][\uDF00-\uDFFF]|[\uD83D][\uDC00-\uDE4F]|[\uD83D][\uDE80-\uDEFF]|[\uD83E][\uDD00-\uDDFF])').firstMatch(cat);
    if (match != null) {
      return match.group(0) ?? '📦';
    }
    return '📦';
  }
}
