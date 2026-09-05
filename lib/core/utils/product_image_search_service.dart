import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class ProductImageSearchResult {
  final String url;
  final String title;
  final String source;

  const ProductImageSearchResult({
    required this.url,
    required this.title,
    required this.source,
  });
}

class ProductImageSearchService {
  static final ProductImageSearchService instance = ProductImageSearchService._();
  ProductImageSearchService._();

  final HttpClient _httpClient = HttpClient()
    ..connectionTimeout = const Duration(seconds: 5);

  /// Search images by barcode first (Open Food Facts), then fallback to text query
  Future<List<ProductImageSearchResult>> searchImages({
    String? barcode,
    String? query,
    int maxResults = 8,
  }) async {
    final List<ProductImageSearchResult> results = [];
    final cleanBarcode = barcode?.trim() ?? '';
    final cleanQuery = query?.trim() ?? '';

    // 1. Try exact barcode match from Open Food Facts
    if (cleanBarcode.isNotEmpty) {
      try {
        final barcodeResults = await _searchOpenFoodFactsByBarcode(cleanBarcode);
        results.addAll(barcodeResults);
      } catch (e) {
        debugPrint('⚠️ OpenFoodFacts barcode search error: $e');
      }
    }

    // 2. Try Open Food Facts search by name/keywords
    if (results.length < maxResults && (cleanQuery.isNotEmpty || cleanBarcode.isNotEmpty)) {
      final term = cleanQuery.isNotEmpty ? cleanQuery : cleanBarcode;
      try {
        final queryResults = await _searchOpenFoodFactsByText(term);
        for (final r in queryResults) {
          if (!results.any((existing) => existing.url == r.url)) {
            results.add(r);
          }
          if (results.length >= maxResults) break;
        }
      } catch (e) {
        debugPrint('⚠️ OpenFoodFacts text search error: $e');
      }
    }

    // 3. Fallback: Wikimedia / Wikipedia Commons image search
    if (results.length < maxResults && cleanQuery.isNotEmpty) {
      try {
        final wikiResults = await _searchWikimediaImages(cleanQuery);
        for (final r in wikiResults) {
          if (!results.any((existing) => existing.url == r.url)) {
            results.add(r);
          }
          if (results.length >= maxResults) break;
        }
      } catch (e) {
        debugPrint('⚠️ Wikimedia search error: $e');
      }
    }

    return results;
  }

  Future<List<ProductImageSearchResult>> _searchOpenFoodFactsByBarcode(String barcode) async {
    final List<ProductImageSearchResult> results = [];
    try {
      final uri = Uri.parse('https://world.openfoodfacts.org/api/v2/product/$barcode.json?fields=product_name,image_url,image_front_url,image_front_small_url,brands');
      final request = await _httpClient.getUrl(uri);
      request.headers.set('User-Agent', 'NayliPOS-Algeria-Kiosk/1.4 (admin@naylipos.dz)');
      final response = await request.close().timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final data = jsonDecode(body);
        if (data is Map && data['status'] == 1) {
          final product = data['product'] as Map?;
          if (product != null) {
            final name = product['product_name']?.toString() ?? barcode;
            final brand = product['brands']?.toString() ?? '';
            final title = brand.isNotEmpty ? '$brand $name' : name;

            final mainImg = product['image_url']?.toString() ?? product['image_front_url']?.toString();
            final smallImg = product['image_front_small_url']?.toString();

            if (mainImg != null && mainImg.startsWith('http')) {
              results.add(ProductImageSearchResult(
                url: mainImg,
                title: title,
                source: 'Open Food Facts (HQ)',
              ));
            } else if (smallImg != null && smallImg.startsWith('http')) {
              results.add(ProductImageSearchResult(
                url: smallImg,
                title: title,
                source: 'Open Food Facts',
              ));
            }
          }
        }
      }
    } catch (_) {}
    return results;
  }

  Future<List<ProductImageSearchResult>> _searchOpenFoodFactsByText(String term) async {
    final List<ProductImageSearchResult> results = [];
    try {
      final uri = Uri.parse(
        'https://world.openfoodfacts.org/cgi/search.pl?search_terms=${Uri.encodeComponent(term)}&search_simple=1&action=process&json=1&page_size=10',
      );
      final request = await _httpClient.getUrl(uri);
      request.headers.set('User-Agent', 'NayliPOS-Algeria-Kiosk/1.4 (admin@naylipos.dz)');
      final response = await request.close().timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final data = jsonDecode(body);
        if (data is Map && data['products'] is List) {
          for (final item in data['products']) {
            if (item is Map) {
              final img = item['image_url']?.toString() ??
                  item['image_front_url']?.toString() ??
                  item['image_front_small_url']?.toString();
              if (img != null && img.startsWith('http')) {
                final name = item['product_name']?.toString() ?? term;
                final brand = item['brands']?.toString() ?? '';
                results.add(ProductImageSearchResult(
                  url: img,
                  title: brand.isNotEmpty ? '$brand - $name' : name,
                  source: 'Open Food Facts',
                ));
              }
            }
          }
        }
      }
    } catch (_) {}
    return results;
  }

  Future<List<ProductImageSearchResult>> _searchWikimediaImages(String query) async {
    final List<ProductImageSearchResult> results = [];
    try {
      final uri = Uri.parse(
        'https://ar.wikipedia.org/w/api.php?action=query&prop=pageimages&format=json&piprop=thumbnail&pithumbsize=400&generator=prefixsearch&gpssearch=${Uri.encodeComponent(query)}&gpslimit=8',
      );
      final request = await _httpClient.getUrl(uri);
      final response = await request.close().timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final data = jsonDecode(body);
        if (data is Map && data['query'] is Map && data['query']['pages'] is Map) {
          final pages = data['query']['pages'] as Map;
          for (final p in pages.values) {
            if (p is Map && p['thumbnail'] is Map) {
              final source = p['thumbnail']['source']?.toString();
              final title = p['title']?.toString() ?? query;
              if (source != null && source.startsWith('http')) {
                results.add(ProductImageSearchResult(
                  url: source,
                  title: title,
                  source: 'ويكيبيديا والموسوعة الحرة',
                ));
              }
            }
          }
        }
      }
    } catch (_) {}
    return results;
  }

  /// Take a photo using camera or pick from gallery, and save locally in app storage
  Future<String?> pickAndSaveImage({required ImageSource source}) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile == null) return null;

      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory('${appDir.path}/product_images');
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }

      final fileName = 'prod_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final savedFile = File('${imagesDir.path}/$fileName');
      await File(pickedFile.path).copy(savedFile.path);

      return savedFile.path;
    } catch (e) {
      debugPrint('⚠️ pickAndSaveImage error: $e');
      return null;
    }
  }

  /// Download a selected web image and store it locally for persistent offline access
  Future<String?> downloadAndSaveImageLocally(String webUrl) async {
    try {
      final uri = Uri.parse(webUrl);
      final request = await _httpClient.getUrl(uri);
      final response = await request.close().timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final bytes = await consolidateHttpClientResponseBytes(response);
        final appDir = await getApplicationDocumentsDirectory();
        final imagesDir = Directory('${appDir.path}/product_images');
        if (!await imagesDir.exists()) {
          await imagesDir.create(recursive: true);
        }

        final ext = webUrl.contains('.png') ? 'png' : 'jpg';
        final fileName = 'web_${DateTime.now().millisecondsSinceEpoch}.$ext';
        final localFile = File('${imagesDir.path}/$fileName');
        await localFile.writeAsBytes(bytes);
        return localFile.path;
      }
    } catch (e) {
      debugPrint('⚠️ Error caching web image locally: $e, using remote URL as fallback');
    }
    return webUrl; // Fallback to remote URL
  }
}
