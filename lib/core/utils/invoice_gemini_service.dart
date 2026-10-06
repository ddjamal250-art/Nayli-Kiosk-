import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../../features/documents/data/commercial_doc_model.dart';
import 'receipt_ocr_parser.dart';

class InvoiceGeminiService {
  static const String _defaultApiKey = ''; // TODO: ضع مفتاحك هنا ليكون ثابتاً لجميع التجار

  static Future<ParsedReceiptResult?> processImage(File file, String apiKey) async {
    try {
      final keyToUse = apiKey.trim().isNotEmpty ? apiKey.trim() : _defaultApiKey;
      if (keyToUse.isEmpty) {
        print('Gemini API Key is empty!');
        return null;
      }

      final bytes = await file.readAsBytes();
      final base64Image = base64Encode(bytes);
      String mimeType = 'image/jpeg';
      if (file.path.toLowerCase().endsWith('.png')) mimeType = 'image/png';
      else if (file.path.toLowerCase().endsWith('.pdf')) mimeType = 'application/pdf';

      final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$keyToUse');

      final prompt = """
You are an expert invoice data extractor for an Algerian POS system.
Extract all products from the invoice image.
Respond ONLY with a valid JSON array of objects. Do NOT wrap it in ```json or any markdown.
Each object must have exactly these keys:
- "designation": string (the product name, exactly as written)
- "quantity": number (e.g. 1.0, 5, 2.5)
- "unitPrice": number (the price per unit without currency symbol)
- "totalHT": number (quantity * unitPrice)

Do not include empty rows. If the invoice has no products, return an empty array [].
""";

      final payload = {
        "contents": [{
          "parts": [
            {"text": prompt},
            {
              "inline_data": {
                "mime_type": mimeType,
                "data": base64Image
              }
            }
          ]
        }],
        "generationConfig": {
          "response_mime_type": "application/json",
          "temperature": 0.1,
        }
      };

      final response = await http.post(url, headers: {'Content-Type': 'application/json'}, body: jsonEncode(payload));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '[]';
        
        final List<dynamic> jsonList = jsonDecode(content);
        final List<CommercialDocItem> items = [];
        
        for (var item in jsonList) {
          final des = item['designation']?.toString() ?? 'منتج غير معروف';
          final qty = (item['quantity'] as num?)?.toDouble() ?? 1.0;
          final price = (item['unitPrice'] as num?)?.toDouble() ?? 0.0;
          
          items.add(CommercialDocItem(
            id: const Uuid().v4(),
            productId: '',
            designation: des,
            quantity: qty,
            unitPrice: price,
            unit: 'حبة',
          ));
        }

        double total = items.fold(0.0, (s, i) => s + i.totalHT);

        return ParsedReceiptResult(
          entityName: 'تم التعرف بواسطة الذكاء الاصطناعي (Gemini)',
          date: DateTime.now(),
          items: items,
          totalAmount: total,
          subtotal: total,
          rawExtractedText: content,
        );
      } else {
        print('Gemini API Error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('InvoiceGeminiService Error: $e');
    }
    return null;
  }
}
