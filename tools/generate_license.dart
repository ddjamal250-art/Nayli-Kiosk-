import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';

void main(List<String> args) {
  if (args.isEmpty) {
    print('Usage: dart tools/generate_license.dart <MACHINE_CODE> [PLAN: P/Y/S/M]');
    print('Example: dart tools/generate_license.dart NK7B2F9A4C1E P');
    exit(1);
  }

  final rawMachine = args[0].trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  final plan = (args.length > 1 ? args[1].trim().toUpperCase() : 'P');
  final planCode = (plan == 'Y' || plan == 'S' || plan == 'M') ? plan : 'P';

  final effectiveId = rawMachine.length >= 12 ? rawMachine.substring(0, 12) : rawMachine.padRight(12, '0');

  const List<int> saltBytes = [100, 107, 115, 102, 107, 117, 106, 101, 121, 117, 127, 102, 126, 120, 107, 117, 121, 99, 105, 127, 120, 99, 117, 24, 26, 24, 16, 117, 106, 9];
  final saltStr = String.fromCharCodes(saltBytes.map((e) => e ^ 42));

  final key = utf8.encode(saltStr);
  final bytes = utf8.encode('$effectiveId:$planCode:NAYLI_OFFLINE_SECRET_2026');
  final hmac = Hmac(sha256, key);
  final digest = hmac.convert(bytes);
  final sig = digest.toString().toUpperCase().substring(0, 16);

  final licenseKey = 'NK$planCode$sig';

  print('==============================================');
  print('  NAYLI POS - OFFLINE LICENSE GENERATOR 🔑    ');
  print('==============================================');
  print('Machine Code : $effectiveId');
  print('Plan         : $planCode (${planCode == 'P' ? 'Permanent' : (planCode == 'Y' ? '1 Year' : (planCode == 'S' ? '6 Months' : '1 Month'))})');
  print('License Key  : $licenseKey');
  print('==============================================');
}
