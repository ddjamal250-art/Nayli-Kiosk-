import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'invoice_ocr_service.dart';
import 'receipt_ocr_parser.dart';

enum InvoiceFileType {
  pdf,
  excel,
  word,
  image,
  text,
  unknown,
}

class InvoiceFileExtractionResult {
  final File file;
  final String fileName;
  final InvoiceFileType fileType;
  final String formatName;
  final int fileSizeBytes;
  final String rawText;
  final ParsedReceiptResult parsedResult;

  InvoiceFileExtractionResult({
    required this.file,
    required this.fileName,
    required this.fileType,
    required this.formatName,
    required this.fileSizeBytes,
    required this.rawText,
    required this.parsedResult,
  });

  String get formattedFileSize {
    if (fileSizeBytes < 1024) return '$fileSizeBytes B';
    if (fileSizeBytes < 1024 * 1024) return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class InvoiceFileReader {
  static final InvoiceFileReader instance = InvoiceFileReader._();
  InvoiceFileReader._();

  InvoiceFileType detectFileType(String filePath) {
    final lower = filePath.toLowerCase();
    if (lower.endsWith('.pdf')) return InvoiceFileType.pdf;
    if (lower.endsWith('.xlsx') || lower.endsWith('.xls') || lower.endsWith('.csv') || lower.endsWith('.tsv')) {
      return InvoiceFileType.excel;
    }
    if (lower.endsWith('.docx') || lower.endsWith('.doc')) return InvoiceFileType.word;
    if (lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.bmp')) {
      return InvoiceFileType.image;
    }
    if (lower.endsWith('.txt')) return InvoiceFileType.text;
    return InvoiceFileType.unknown;
  }

  String getFormatName(InvoiceFileType type) {
    switch (type) {
      case InvoiceFileType.pdf:
        return 'مستند PDF';
      case InvoiceFileType.excel:
        return 'جدول إكسل / CSV';
      case InvoiceFileType.word:
        return 'مستند Word';
      case InvoiceFileType.image:
        return 'صورة / سكانير';
      case InvoiceFileType.text:
        return 'ملف نصي TXT';
      case InvoiceFileType.unknown:
        return 'ملف غير معروف';
    }
  }

  /// Main entry point to process an imported invoice file
  Future<InvoiceFileExtractionResult?> processFile(File file) async {
    try {
      if (!await file.exists()) return null;

      final fileName = file.uri.pathSegments.isNotEmpty ? file.uri.pathSegments.last : 'invoice';
      final fileType = detectFileType(file.path);
      final formatName = getFormatName(fileType);
      final fileBytes = await file.readAsBytes();

      String rawText = '';

      switch (fileType) {
        case InvoiceFileType.pdf:
          rawText = await _extractFromPdf(file) ?? '';
          break;

        case InvoiceFileType.image:
          rawText = await _extractFromImage(file) ?? '';
          break;

        case InvoiceFileType.excel:
          if (file.path.toLowerCase().endsWith('.csv') || file.path.toLowerCase().endsWith('.tsv')) {
            rawText = _extractFromCsv(fileBytes);
          } else if (file.path.toLowerCase().endsWith('.xlsx')) {
            rawText = _extractFromXlsx(fileBytes);
          } else {
            // .xls fallback
            rawText = _extractFallbackText(fileBytes);
          }
          break;

        case InvoiceFileType.word:
          if (file.path.toLowerCase().endsWith('.docx')) {
            rawText = _extractFromDocx(fileBytes);
          } else {
            rawText = _extractFallbackText(fileBytes);
          }
          break;

        case InvoiceFileType.text:
          rawText = _extractFromCsv(fileBytes);
          break;

        case InvoiceFileType.unknown:
          rawText = _extractFallbackText(fileBytes);
          break;
      }

      final parsed = ReceiptOcrParser.parseRawText(rawText);

      return InvoiceFileExtractionResult(
        file: file,
        fileName: fileName,
        fileType: fileType,
        formatName: formatName,
        fileSizeBytes: fileBytes.length,
        rawText: rawText,
        parsedResult: parsed,
      );
    } catch (e) {
      debugPrint('⚠️ Error processing invoice file ${file.path}: $e');
      return null;
    }
  }

  Future<String?> _extractFromPdf(File file) async {
    return await InvoiceOcrService.instance.extractTextFromImage(file, isPdf: true);
  }

  Future<String?> _extractFromImage(File file) async {
    return await InvoiceOcrService.instance.extractTextFromImage(file, isPdf: false);
  }

  String _extractFromCsv(List<int> bytes) {
    try {
      String text;
      try {
        text = utf8.decode(bytes);
      } catch (_) {
        text = latin1.decode(bytes);
      }

      // Convert common CSV delimiters (; or \t) to clean spaces for OCR parser
      final lines = text.split(RegExp(r'\r?\n'));
      final cleanedLines = <String>[];
      for (final line in lines) {
        if (line.trim().isEmpty) continue;
        final cells = line.split(RegExp(r'[,;\t]')).map((c) => c.trim().replaceAll('"', '')).toList();
        cleanedLines.add(cells.join('   '));
      }
      return cleanedLines.join('\n');
    } catch (e) {
      debugPrint('⚠️ CSV Extraction error: $e');
      return '';
    }
  }

  String _extractFromDocx(List<int> bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      for (final f in archive) {
        if (f.name == 'word/document.xml') {
          final content = utf8.decode(f.content as List<int>);
          // Replace paragraph and table row boundaries with newlines
          final withBreaks = content
              .replaceAll(RegExp(r'<w:p[ >]'), '\n')
              .replaceAll(RegExp(r'<w:tr[ >]'), '\n')
              .replaceAll(RegExp(r'<w:tc[ >]'), '   ');
          // Strip all remaining XML tags
          final stripped = withBreaks.replaceAll(RegExp(r'<[^>]+>'), '');
          return stripped
              .split('\n')
              .map((l) => l.trim())
              .where((l) => l.isNotEmpty)
              .join('\n');
        }
      }
    } catch (e) {
      debugPrint('⚠️ DOCX Extraction error: $e');
    }
    return '';
  }

  String _extractFromXlsx(List<int> bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);

      // 1. Read shared strings
      final sharedStrings = <String>[];
      for (final f in archive) {
        if (f.name == 'xl/sharedStrings.xml') {
          final content = utf8.decode(f.content as List<int>);
          final matches = RegExp(r'<t[^>]*>(.*?)</t>').allMatches(content);
          for (final m in matches) {
            sharedStrings.add(m.group(1) ?? '');
          }
        }
      }

      // 2. Read first worksheet
      for (final f in archive) {
        if (f.name.startsWith('xl/worksheets/sheet') && f.name.endsWith('.xml')) {
          final content = utf8.decode(f.content as List<int>);
          final rows = <String>[];

          final rowMatches = RegExp(r'<row[^>]*>(.*?)</row>').allMatches(content);
          for (final r in rowMatches) {
            final rowXml = r.group(1) ?? '';
            final cellMatches = RegExp(r'<c\s*([^>]*)>(.*?)</c>').allMatches(rowXml);
            final rowCells = <String>[];

            for (final c in cellMatches) {
              final attrs = c.group(1) ?? '';
              final cellBody = c.group(2) ?? '';
              final isSharedString = attrs.contains('t="s"');

              final valMatch = RegExp(r'<v>(.*?)</v>').firstMatch(cellBody);
              if (valMatch != null) {
                final rawVal = valMatch.group(1) ?? '';
                if (isSharedString) {
                  final idx = int.tryParse(rawVal);
                  if (idx != null && idx >= 0 && idx < sharedStrings.length) {
                    rowCells.add(sharedStrings[idx]);
                  } else {
                    rowCells.add(rawVal);
                  }
                } else {
                  rowCells.add(rawVal);
                }
              }
            }

            if (rowCells.isNotEmpty) {
              rows.add(rowCells.join('   '));
            }
          }

          if (rows.isNotEmpty) {
            return rows.join('\n');
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ XLSX Extraction error: $e');
    }
    return '';
  }

  String _extractFallbackText(List<int> bytes) {
    try {
      final decoded = utf8.decode(bytes, allowMalformed: true);
      final clean = decoded.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '');
      final lines = clean
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.length > 3)
          .toList();
      return lines.join('\n');
    } catch (_) {
      return '';
    }
  }
}
