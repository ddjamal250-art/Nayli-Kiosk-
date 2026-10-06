import sys
f1 = 'lib/features/documents/presentation/widgets/receipt_ocr_scanner_dialog.dart'
with open(f1, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Imports
import_statement = "import '../../domain/entities/commercial_document.dart';\nimport '../../../product/domain/entities/product.dart';\n"
content = content.replace("import '../../domain/entities/commercial_document.dart';\n", import_statement)

# 2. _processFile
old_process_file = """      ParsedReceiptResult? geminiResult;
      if (isImageOrPdf) { // Changed this to try Gemini always, fallback will handle empty keys
        setState(() => _processingStatus = 'جاري تحليل الفاتورة باستخدام الذكاء الاصطناعي (Gemini) 🤖...');
        geminiResult = await InvoiceGeminiService.processImage(file, apiKey);
      }

      if (geminiResult != null) {
        _selectedFileFormat = isImageOrPdf ? (pathLower.endsWith('.pdf') ? 'PDF (AI)' : 'صورة (AI)') : 'ملف (AI)';
        _rawTextCtrl.text = geminiResult.rawExtractedText;
        setState(() {
          _parsedItems.clear();
          _parsedItems.addAll(geminiResult!.items);
          _entityName = geminiResult.entityName;
          _detectedTotal = geminiResult.totalAmount;
        });

        if (mounted) {
          if (_parsedItems.isNotEmpty) {
            SnackbarHelper.showSuccess(context, '✅ تم استخراج ${_parsedItems.length} سلع بنجاح باستخدام الذكاء الاصطناعي!');
          } else {
            SnackbarHelper.showWarning(context, 'لم يعثر الذكاء الاصطناعي على سلع في هذه الفاتورة.');
          }
        }
      } else {
        // Fallback to traditional parser
        final res = await InvoiceFileReader.instance.processFile(file);
        if (res != null) {
          _selectedFileFormat = res.formatName;
          _rawTextCtrl.text = res.rawText;
          setState(() {
            _parsedItems.clear();
            _parsedItems.addAll(res.parsedResult.items);
            _entityName = res.parsedResult.entityName;
            _detectedTotal = res.parsedResult.totalAmount;
          });

          if (mounted) {
            if (_parsedItems.isNotEmpty) {
              SnackbarHelper.showSuccess(context, '✅ تم استخراج ${_parsedItems.length} سلع بنجاح! يرجى المعاينة والتأكيد.');
            } else {
              SnackbarHelper.showWarning(context, 'تمت قراءة الملف لكن لم نكتشف سلعاً تلقائياً. يمكنك إضافة السلع أو تعديل النص.');
            }
          }
        } else {
          if (mounted) SnackbarHelper.showError(context, 'فشلت عملية القراءة أو الملف غير مدعوم.');
        }
      }"""

new_process_file = """      ParsedReceiptResult? finalResult;
      String finalFormat = '';
      if (isImageOrPdf) { 
        setState(() => _processingStatus = 'جاري تحليل الفاتورة باستخدام الذكاء الاصطناعي (Gemini) 🤖...');
        finalResult = await InvoiceGeminiService.processImage(file, apiKey);
        finalFormat = pathLower.endsWith('.pdf') ? 'PDF (AI)' : 'صورة (AI)';
        if (finalResult == null && mounted) {
           SnackbarHelper.showError(context, '⚠️ فشل الذكاء الاصطناعي! يرجى إضافة مفتاح API الخاص بـ Gemini.');
        }
      } else {
        final res = await InvoiceFileReader.instance.processFile(file);
        if (res != null) {
          finalResult = res.parsedResult;
          finalFormat = res.formatName;
        }
      }

      if (finalResult != null) {
        _selectedFileFormat = finalFormat;
        _rawTextCtrl.text = finalResult.rawExtractedText;
        setState(() {
          _parsedItems.clear();
          _parsedItems.addAll(finalResult!.items);
          _entityName = finalResult.entityName;
          _detectedTotal = finalResult.totalAmount;
        });

        if (mounted) {
          if (_parsedItems.isNotEmpty) {
            SnackbarHelper.showSuccess(context, '✅ تم استخراج ${_parsedItems.length} سلع بنجاح!');
          } else {
            SnackbarHelper.showWarning(context, 'لم يتم العثور على سلع في هذه الفاتورة.');
          }
        }
      } else {
        if (mounted && !isImageOrPdf) SnackbarHelper.showError(context, 'فشلت عملية القراءة.');
      }"""

content = content.replace(old_process_file, new_process_file)

# 3. Item row
old_item_row = """                    // Item Designation
                    Expanded(
                      flex: 4,
                      child: TextFormField(
                        initialValue: item.designation,
                        decoration: const InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                          hintText: 'اسم السلعة',
                        ),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                        onChanged: (v) {
                          _parsedItems[index] = item.copyWith(designation: v);
                          setState(() {});
                        },
                      ),
                    ),"""

new_item_row = """                    // Item Designation
                    Expanded(
                      flex: 4,
                      child: Autocomplete<Product>(
                        initialValue: TextEditingValue(text: item.designation),
                        displayStringForOption: (Product option) => option.name,
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          final query = textEditingValue.text.toLowerCase();
                          if (query.isEmpty) return const Iterable<Product>.empty();
                          return HiveDatabase.productBox.values.cast<Product>().where((product) {
                            return product.name.toLowerCase().contains(query) || product.barcode.contains(query);
                          });
                        },
                        onSelected: (Product selection) {
                          setState(() {
                            _parsedItems[index] = item.copyWith(
                              designation: selection.name,
                              productId: selection.barcode,
                            );
                          });
                        },
                        fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                          return TextFormField(
                            controller: textEditingController,
                            focusNode: focusNode,
                            decoration: const InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                              hintText: 'اسم السلعة أو الباركود',
                            ),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                            onChanged: (v) {
                              _parsedItems[index] = item.copyWith(designation: v);
                            },
                          );
                        },
                      ),
                    ),"""

content = content.replace(old_item_row, new_item_row)

with open(f1, 'w', encoding='utf-8') as f:
    f.write(content)
print('Done!')
