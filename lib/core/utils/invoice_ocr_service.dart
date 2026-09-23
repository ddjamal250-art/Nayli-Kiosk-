import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class InvoiceOcrService {
  static final InvoiceOcrService instance = InvoiceOcrService._();
  InvoiceOcrService._();

  // OCR Space API endpoints & free public gateway keys
  static const String _ocrApiUrl = 'https://api.ocr.space/parse/image';
  static const List<String> _apiKeys = [
    'K87899142388957', // OCR.space public key
    'helloworld',
  ];

  /// Extract raw printed text from a photo, scan, or PDF invoice
  Future<String?> extractTextFromImage(File imageFile, {bool? isPdf}) async {
    try {
      if (!await imageFile.exists()) return null;

      final fileBytes = await imageFile.readAsBytes();
      if (fileBytes.isEmpty) return null;

      final pathLower = imageFile.path.toLowerCase();
      final bool detectedPdf = isPdf ?? pathLower.endsWith('.pdf');
      final String fileType = detectedPdf ? 'PDF' : (pathLower.endsWith('.png') ? 'PNG' : 'JPG');
      final String fileName = detectedPdf ? 'invoice.pdf' : (pathLower.endsWith('.png') ? 'invoice.png' : 'invoice.jpg');

      // Try each API key in order
      for (final apiKey in _apiKeys) {
        try {
          final request = http.MultipartRequest('POST', Uri.parse(_ocrApiUrl));
          request.fields['apikey'] = apiKey;
          request.fields['language'] = 'fre'; // French & Arabic numerals are standard in Algerian invoices
          request.fields['isOverlayRequired'] = 'false';
          request.fields['filetype'] = fileType;
          request.fields['detectOrientation'] = 'true';
          request.fields['isTable'] = 'true';
          request.fields['scale'] = 'true';

          request.files.add(
            http.MultipartFile.fromBytes(
              'file',
              fileBytes,
              filename: fileName,
            ),
          );

          final streamedResponse = await request.send().timeout(const Duration(seconds: 18));
          final response = await http.Response.fromStream(streamedResponse);

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            if (data is Map && data['ParsedResults'] is List) {
              final parsedResults = data['ParsedResults'] as List;
              if (parsedResults.isNotEmpty) {
                final pageTexts = <String>[];
                for (final res in parsedResults) {
                  if (res is Map && res['ParsedText'] != null) {
                    final t = res['ParsedText'].toString().trim();
                    if (t.isNotEmpty) pageTexts.add(t);
                  }
                }
                final fullText = pageTexts.join('\n');
                if (fullText.isNotEmpty) {
                  debugPrint('🚀 OCR Successfully extracted ${fullText.length} characters from $fileName');
                  return fullText;
                }
              }
            }
          }
        } catch (e) {
          debugPrint('⚠️ OCR Space attempt with key $apiKey failed: $e');
        }
      }
    } catch (e) {
      debugPrint('⚠️ InvoiceOcrService overall error: $e');
    }
    return null;
  }
}
