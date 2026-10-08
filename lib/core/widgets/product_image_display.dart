import 'dart:io';
import 'package:flutter/material.dart';
import '../utils/product_image_helper.dart';

class ProductImageDisplay extends StatelessWidget {
  final String? imageUrl;
  final double width;
  final double height;
  final double borderRadius;
  final IconData placeholderIcon;

  const ProductImageDisplay({
    super.key,
    this.imageUrl,
    this.width = 50,
    this.height = 50,
    this.borderRadius = 8,
    this.placeholderIcon = Icons.inventory_2_outlined,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.trim().isEmpty) {
      return _buildPlaceholder();
    }

    final resolved = ProductImageHelper.resolveImagePathSync(imageUrl);
    final targetPath = (resolved != null && resolved.isNotEmpty) ? resolved : imageUrl!.trim();
    final isNetwork = targetPath.startsWith('http://') || targetPath.startsWith('https://');

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: isNetwork
          ? Image.network(
              targetPath,
              width: width,
              height: height,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildPlaceholder(),
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return SizedBox(
                  width: width,
                  height: height,
                  child: Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                          : null,
                      strokeWidth: 2,
                    ),
                  ),
                );
              },
            )
          : Image.file(
              File(targetPath),
              width: width,
              height: height,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildPlaceholder(),
            ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Center(
        child: Icon(placeholderIcon, color: Colors.grey.shade400, size: width * 0.5),
      ),
    );
  }
}
