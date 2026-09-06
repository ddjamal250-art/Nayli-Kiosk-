import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../data/master_catalog_service.dart';

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

  /// Search images across:
  /// 1. Master Catalog (Algerian local products catalog - instant & offline)
  /// 2. Open Food Facts by Barcode
  /// 3. Open Food Facts by Keywords
  /// 4. Web & Bing Images Search
  /// 5. Wikimedia Commons & Wikipedia
  Future<List<ProductImageSearchResult>> searchImages({
    String? barcode,
    String? query,
    int maxResults = 12,
  }) async {
    final List<ProductImageSearchResult> results = [];
    final cleanBarcode = barcode?.trim() ?? '';
    final cleanQuery = query?.trim() ?? '';

    // 1. Master Catalog (instant match from verified Algerian goods)
    try {
      if (cleanBarcode.isNotEmpty) {
        final m = MasterCatalogService.searchByBarcode(cleanBarcode);
        if (m != null && m.imageUrl != null && m.imageUrl!.isNotEmpty) {
          results.add(ProductImageSearchResult(
            url: m.imageUrl!,
            title: m.name,
            source: 'الكتالوج الجزائري الشامل 🇩🇿',
          ));
        }
      }
      if (cleanQuery.isNotEmpty && results.length < maxResults) {
        final matches = MasterCatalogService.instance.search(cleanQuery);
        for (final m in matches) {
          if (m.imageUrl != null &&
              m.imageUrl!.isNotEmpty &&
              !results.any((r) => r.url == m.imageUrl)) {
            results.add(ProductImageSearchResult(
              url: m.imageUrl!,
              title: m.name,
              source: 'الكتالوج الجزائري الشامل 🇩🇿',
            ));
            if (results.length >= 4) break;
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ Master Catalog search error: $e');
    }

    // 2. Open Food Facts (Barcode)
    if (results.length < maxResults && cleanBarcode.isNotEmpty) {
      try {
        final barcodeResults = await _searchOpenFoodFactsByBarcode(cleanBarcode);
        results.addAll(barcodeResults);
      } catch (e) {
        debugPrint('⚠️ OpenFoodFacts barcode search error: $e');
      }
    }

    // 3. Open Food Facts (Text)
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

    // 4. Web & Google Image Search
    if (results.length < maxResults && cleanQuery.isNotEmpty) {
      try {
        final googleResults = await _searchGoogleImages(cleanQuery);
        for (final r in googleResults) {
          if (!results.any((existing) => existing.url == r.url)) {
            results.add(r);
          }
          if (results.length >= maxResults) break;
        }
      } catch (e) {
        debugPrint('⚠️ Google search error: $e');
      }
    }

    // 5. Wikimedia Commons Image search
    if (results.length < maxResults && cleanQuery.isNotEmpty) {
      try {
        final commonsResults = await _searchWikimediaCommonsImages(cleanQuery);
        for (final r in commonsResults) {
          if (!results.any((existing) => existing.url == r.url)) {
            results.add(r);
          }
          if (results.length >= maxResults) break;
        }
      } catch (e) {
        debugPrint('⚠️ Wikimedia Commons search error: $e');
      }
    }

    // 6. Wikipedia Fallback
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
      request.headers.set('User-Agent', 'NayliPOS-Algeria/1.4 (admin@naylipos.dz)');
      final response = await request.close().timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final data = jsonDecode(body);
        if (data is Map && data['status'] == 1) {
          final product = data['product'] as Map?;
          if (product != null) {
            final name = product['product_name']?.toString() ?? 'منتج غذائي';
            final brand = product['brands']?.toString() ?? '';
            final title = brand.isNotEmpty ? '$brand - $name' : name;
            final img = product['image_front_url'] ?? product['image_url'] ?? product['image_front_small_url'];
            if (img != null && img.toString().startsWith('http')) {
              results.add(ProductImageSearchResult(
                url: img.toString(),
                title: title,
                source: 'Open Food Facts (قاعدة باركود الأغذية)',
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
        'https://world.openfoodfacts.org/cgi/search.pl?search_terms=${Uri.encodeComponent(term)}&search_simple=1&action=process&json=1&page_size=6&fields=product_name,image_front_url,image_url,brands',
      );
      final request = await _httpClient.getUrl(uri);
      request.headers.set('User-Agent', 'NayliPOS-Algeria/1.4 (admin@naylipos.dz)');
      final response = await request.close().timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final data = jsonDecode(body);
        if (data is Map && data['products'] is List) {
          for (final p in (data['products'] as List)) {
            if (p is Map) {
              final img = p['image_front_url'] ?? p['image_url'];
              final name = p['product_name']?.toString() ?? term;
              final brand = p['brands']?.toString() ?? '';
              final title = brand.isNotEmpty ? '$brand - $name' : name;
              if (img != null && img.toString().startsWith('http')) {
                results.add(ProductImageSearchResult(
                  url: img.toString(),
                  title: title,
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

  Future<List<ProductImageSearchResult>> _searchGoogleImages(String query) async {
    final List<ProductImageSearchResult> results = [];
    try {
      final uri = Uri.parse('https://www.google.com/search?tbm=isch&q=${Uri.encodeComponent(query)}');
      final request = await _httpClient.getUrl(uri);
      // Using a standard User-Agent so Google returns the older, simpler HTML structure with direct thumbnails
      request.headers.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/100.0.0.0 Safari/537.36');
      request.headers.set('Accept', 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8');
      request.headers.set('Accept-Language', 'ar,fr;q=0.9,en;q=0.8');

      final response = await request.close().timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final html = await response.transform(utf8.decoder).join();
        
        // Extract thumbnails from image tags (this relies on the fallback HTML version of Google Images)
        final regex = RegExp(r'<img[^>]+src="([^">]+)"');
        final matches = regex.allMatches(html);
        
        for (final match in matches) {
          final src = match.group(1);
          if (src != null && src.startsWith('http') && !src.contains('branding/googlelogo') && !src.contains('text/html')) {
            results.add(ProductImageSearchResult(
              url: src,
              title: query,
              source: 'صور جوجل 🌐 (Google)',
            ));
          }
        }
      }
    } catch (e) {
      debugPrint('Google Images scraping error: $e');
    }
    return results;
  }

  Future<List<ProductImageSearchResult>> _searchWikimediaCommonsImages(String query) async {
    final List<ProductImageSearchResult> results = [];
    try {
      final uri = Uri.parse(
        'https://commons.wikimedia.org/w/api.php?action=query&generator=search&gsrsearch=${Uri.encodeComponent(query)}&gsrnamespace=6&prop=imageinfo&iiprop=url|size&format=json&gsrlimit=8',
      );
      final request = await _httpClient.getUrl(uri);
      request.headers.set('User-Agent', 'NayliPOS/2.0 (contact@naylipos.dz)');
      final response = await request.close().timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final data = jsonDecode(body);
        if (data is Map && data['query'] is Map && data['query']['pages'] is Map) {
          final pages = data['query']['pages'] as Map;
          for (final p in pages.values) {
            if (p is Map && p['imageinfo'] is List && (p['imageinfo'] as List).isNotEmpty) {
              final info = (p['imageinfo'] as List).first as Map;
              final url = info['url']?.toString();
              final title = (p['title']?.toString() ?? query).replaceFirst('File:', '');
              if (url != null &&
                  (url.endsWith('.jpg') ||
                      url.endsWith('.png') ||
                      url.endsWith('.jpeg') ||
                      url.endsWith('.webp'))) {
                results.add(ProductImageSearchResult(
                  url: url,
                  title: title,
                  source: 'ويكيميديا كومونز العالمية',
                ));
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ Wikimedia Commons search error: $e');
    }
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
      final imagesDir = Directory('${appDir.path}/nayli_market_images');
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
        final imagesDir = Directory('${appDir.path}/nayli_market_images');
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
    return webUrl;
  }
}
