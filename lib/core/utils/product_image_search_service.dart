import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../data/master_catalog_service.dart';
import 'product_image_helper.dart';

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
  /// 3. Bing Image Search by Barcode and Query (fast, unblocked, high-resolution)
  /// 4. Open Food Facts by Keywords
  /// 5. Wikimedia Commons & Wikipedia
  Future<List<ProductImageSearchResult>> searchImages({
    String? barcode,
    String? query,
    int maxResults = 16,
  }) async {
    final List<ProductImageSearchResult> results = [];
    final cleanBarcode = barcode?.trim() ?? '';
    final cleanQuery = query?.trim() ?? '';

    // 1. Master Catalog (instant match from verified Algerian goods - offline)
    try {
      if (cleanBarcode.isNotEmpty) {
        final m = MasterCatalogService.searchByBarcode(cleanBarcode);
        if (m != null && m.imageUrl != null && m.imageUrl!.isNotEmpty) {
          results.add(ProductImageSearchResult(
            url: m.imageUrl!,
            title: m.name,
            source: 'دليل السلع الجزائري (فوري)',
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
              source: 'دليل السلع الجزائري (فوري)',
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
        for (final r in barcodeResults) {
          if (!results.any((existing) => existing.url == r.url)) {
            results.add(r);
          }
        }
      } catch (e) {
        debugPrint('⚠️ OpenFoodFacts barcode search error: $e');
      }
    }

    // 3. Bing Image Search by Barcode
    if (results.length < maxResults && cleanBarcode.isNotEmpty) {
      try {
        final bingBarcodeResults = await _searchBingImages(cleanBarcode);
        for (final r in bingBarcodeResults) {
          if (!results.any((existing) => existing.url == r.url)) {
            results.add(r);
          }
          if (results.length >= maxResults) break;
        }
      } catch (e) {
        debugPrint('⚠️ Bing barcode search error: $e');
      }
    }

    // 4. Bing Image Search by Query (Name / Brand / Keywords)
    if (results.length < maxResults && cleanQuery.isNotEmpty) {
      try {
        final bingQueryResults = await _searchBingImages(cleanQuery);
        for (final r in bingQueryResults) {
          if (!results.any((existing) => existing.url == r.url)) {
            results.add(r);
          }
          if (results.length >= maxResults) break;
        }
      } catch (e) {
        debugPrint('⚠️ Bing query search error: $e');
      }
    }

    // 5. Open Food Facts (Text search)
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

    // 6. Wikimedia Commons Image search
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

    // 7. Wikipedia Fallback
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

  /// Automatically and swiftly searches for a product image by barcode and/or name,
  /// downloads it to the permanent local store, and returns the local file path.
  Future<String?> autoFetchProductImage({
    required String barcode,
    String? name,
  }) async {
    final cleanBarcode = barcode.trim();
    final cleanName = name?.trim() ?? '';
    if (cleanBarcode.isEmpty && cleanName.isEmpty) return null;

    // 1. Instant local Algerian Master Catalog
    if (cleanBarcode.isNotEmpty) {
      final master = MasterCatalogService.searchByBarcode(cleanBarcode);
      if (master != null && master.imageUrl != null && master.imageUrl!.isNotEmpty) {
        if (!master.imageUrl!.startsWith('http')) {
          return master.imageUrl;
        }
        return await downloadAndSaveImageLocally(master.imageUrl!, barcode: cleanBarcode);
      }
    }

    // 2. Open Food Facts by Barcode
    if (cleanBarcode.isNotEmpty) {
      final offList = await _searchOpenFoodFactsByBarcode(cleanBarcode);
      if (offList.isNotEmpty) {
        final localPath = await downloadAndSaveImageLocally(offList.first.url, barcode: cleanBarcode);
        if (localPath != null) return localPath;
      }
    }

    // 3. Bing Image Search by Barcode
    if (cleanBarcode.isNotEmpty) {
      final bingBarcodeList = await _searchBingImages(cleanBarcode);
      if (bingBarcodeList.isNotEmpty) {
        final localPath = await downloadAndSaveImageLocally(bingBarcodeList.first.url, barcode: cleanBarcode);
        if (localPath != null) return localPath;
      }
    }

    // 4. Bing Image Search by Name / Brand
    if (cleanName.isNotEmpty) {
      final bingNameList = await _searchBingImages(cleanName);
      if (bingNameList.isNotEmpty) {
        final localPath = await downloadAndSaveImageLocally(bingNameList.first.url, barcode: cleanBarcode.isNotEmpty ? cleanBarcode : 'name');
        if (localPath != null) return localPath;
      }
    }

    return null;
  }

  Future<List<ProductImageSearchResult>> _searchOpenFoodFactsByBarcode(String barcode) async {
    final List<ProductImageSearchResult> results = [];
    try {
      final uri = Uri.parse('https://world.openfoodfacts.org/api/v2/product/$barcode.json?fields=product_name,image_url,image_front_url,image_front_small_url,brands');
      final request = await _httpClient.getUrl(uri);
      request.headers.set('User-Agent', 'NayliPOS-Algeria-Kiosk/2.0 (admin@naylipos.dz)');
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
      request.headers.set('User-Agent', 'NayliPOS-Algeria-Kiosk/2.0 (admin@naylipos.dz)');
      final response = await request.close().timeout(const Duration(seconds: 4));

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

  /// Fast Bing async image search engine (Returns high-res web images without blocking)
  Future<List<ProductImageSearchResult>> _searchBingImages(String query) async {
    final List<ProductImageSearchResult> results = [];
    try {
      final uri = Uri.parse(
        'https://www.bing.com/images/async?q=${Uri.encodeComponent(query)}&first=0&count=16&mmasync=1',
      );
      final request = await _httpClient.getUrl(uri);
      request.headers.set(
        'User-Agent',
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
      );
      request.headers.set('Accept-Language', 'fr-FR,fr;q=0.9,ar;q=0.8,en;q=0.7');
      request.headers.set('Referer', 'https://www.bing.com/');
      final response = await request.close().timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final matches = RegExp(r'm="({[^"]+})"').allMatches(body);
        for (final m in matches) {
          final raw = m.group(1)?.replaceAll('&quot;', '"');
          if (raw != null) {
            try {
              final data = jsonDecode(raw);
              if (data is Map) {
                final imgUrl = data['murl']?.toString();
                final title = data['t']?.toString() ?? query;
                if (imgUrl != null &&
                    imgUrl.startsWith('http') &&
                    !imgUrl.contains('data:image')) {
                  results.add(ProductImageSearchResult(
                    url: imgUrl,
                    title: title,
                    source: 'محرك الصور العالمي (Bing)',
                  ));
                }
              }
            } catch (_) {}
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ Bing search error: $e');
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
      final response = await request.close().timeout(const Duration(seconds: 4));
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

      final imagesDir = await ProductImageHelper.getImagesDirectory();
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
  Future<String?> downloadAndSaveImageLocally(String webUrl, {String? barcode}) async {
    try {
      if (!webUrl.startsWith('http://') && !webUrl.startsWith('https://')) {
        return webUrl; // Already a local path
      }

      final uri = Uri.parse(webUrl);
      final request = await _httpClient.getUrl(uri);
      request.headers.set(
        'User-Agent',
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
      );
      final response = await request.close().timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final bytes = await consolidateHttpClientResponseBytes(response);
        final imagesDir = await ProductImageHelper.getImagesDirectory();

        final ext = (webUrl.toLowerCase().contains('.png'))
            ? 'png'
            : (webUrl.toLowerCase().contains('.webp'))
                ? 'webp'
                : 'jpg';

        final cleanBc = barcode != null && barcode.trim().isNotEmpty
            ? barcode.trim().replaceAll(RegExp(r'[^\w-]'), '_')
            : 'web';
        final fileName = 'prod_${cleanBc}_${DateTime.now().millisecondsSinceEpoch}.$ext';
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
