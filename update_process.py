import sys
f1 = 'lib/features/documents/presentation/widgets/receipt_ocr_scanner_dialog.dart'
with open(f1, 'r', encoding='utf-8') as f:
    lines = f.readlines()

new_lines = []
skip = False
for i, l in enumerate(lines):
    if 'ParsedReceiptResult? geminiResult;' in l:
        skip = True
        new_lines.append("      ParsedReceiptResult? finalResult;\n")
        new_lines.append("      String finalFormat = '';\n")
        new_lines.append("      if (isImageOrPdf) {\n")
        new_lines.append("        setState(() => _processingStatus = 'جاري تحليل الفاتورة باستخدام الذكاء الاصطناعي (Gemini) 🤖...');\n")
        new_lines.append("        finalResult = await InvoiceGeminiService.processImage(file, apiKey);\n")
        new_lines.append("        finalFormat = pathLower.endsWith('.pdf') ? 'PDF (AI)' : 'صورة (AI)';\n")
        new_lines.append("        if (finalResult == null && mounted) {\n")
        new_lines.append("          SnackbarHelper.showError(context, '⚠️ فشل الذكاء الاصطناعي! يرجى وضع مفتاح API الخاص بـ Gemini في الكود.');\n")
        new_lines.append("        }\n")
        new_lines.append("      } else {\n")
        new_lines.append("        final res = await InvoiceFileReader.instance.processFile(file);\n")
        new_lines.append("        if (res != null) {\n")
        new_lines.append("          finalResult = res.parsedResult;\n")
        new_lines.append("          finalFormat = res.formatName;\n")
        new_lines.append("        }\n")
        new_lines.append("      }\n\n")
        new_lines.append("      if (finalResult != null) {\n")
        new_lines.append("        _selectedFileFormat = finalFormat;\n")
        new_lines.append("        _rawTextCtrl.text = finalResult.rawExtractedText;\n")
        new_lines.append("        setState(() {\n")
        new_lines.append("          _parsedItems.clear();\n")
        new_lines.append("          _parsedItems.addAll(finalResult!.items);\n")
        new_lines.append("          _entityName = finalResult.entityName;\n")
        new_lines.append("          _detectedTotal = finalResult.totalAmount;\n")
        new_lines.append("        });\n\n")
        new_lines.append("        if (mounted) {\n")
        new_lines.append("          if (_parsedItems.isNotEmpty) {\n")
        new_lines.append("            SnackbarHelper.showSuccess(context, '✅ تم استخراج ${_parsedItems.length} سلع بنجاح!');\n")
        new_lines.append("          } else {\n")
        new_lines.append("            SnackbarHelper.showWarning(context, 'لم يتم العثور على سلع في هذه الفاتورة.');\n")
        new_lines.append("          }\n")
        new_lines.append("        }\n")
        continue
    
    if skip:
        if 'if (mounted) SnackbarHelper.showError(context, \'فشلت عملية القراءة' in l:
            skip = False
            new_lines.append("      } else {\n")
            new_lines.append("        if (mounted) SnackbarHelper.showError(context, 'فشلت عملية القراءة أو الملف غير مدعوم.');\n")
            continue
        continue

    new_lines.append(l)

with open(f1, 'w', encoding='utf-8') as f:
    f.writelines(new_lines)
print('Done!')
