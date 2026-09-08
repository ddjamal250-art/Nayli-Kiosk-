import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/data/hive_database.dart';

class EulaPage extends StatefulWidget {
  const EulaPage({super.key});

  @override
  State<EulaPage> createState() => _EulaPageState();
}

class _EulaPageState extends State<EulaPage> {
  bool _accepted = false;

  final String _eulaText = """
اتفاقية ترخيص المستخدم النهائي (EULA) لنظام Nayli Market POS

مرحباً بك في نظام Nayli Market لإدارة نقاط البيع والمحلات التجارية. يُرجى قراءة هذه الاتفاقية بعناية قبل استخدام البرنامج:

1. ترخيص الاستخدام:
يمنحك المطور ترخيصاً شخصياً لاستخدام هذا البرنامج لإدارة المبيعات ونقاط البيع والمخزون في نشاطك التجاري. لا يحق بيع أو إعادة توزيع أو إجراء هندسة عكسية للبرنامج دون موافقة خطية مسبقة من المطور.

2. حماية البيانات والخصوصية:
تُحفظ جميع بياناتك وقواعد البيانات الخاصة بالمبيعات والمخزون والزبائن محلياً على جهازك، دون إرسالها إلى أي خادم خارجي دون إذنك. أنت المسؤول عن أخذ نسخ احتياطية دورية لبياناتك لضمان عدم فقدانها في حال تعطل الجهاز.

3. المسؤولية القانونية:
البرنامج أداة مساعدة لإدارة نقاط البيع. لا يتحمل المطور أي مسؤولية عن أي خسائر ناتجة عن سوء الاستخدام أو انقطاع التيار الكهربائي أو تلف وحدات التخزين بالجهاز.

4. التحديثات والدعم:
يحق للمطور إصدار تحديثات وتحسينات دورية للنظام لمعالجة الأخطاء وإضافة مميزات جديدة تلبي احتياجات المستخدمين.

5. القبول والإقرار:
باختيارك "موافقة ومتابعة"، فإنك تقر بأنك قد قرأت هذه الاتفاقية وفهمت جميع بنودها وتوافق على الالتزام الكامل بها.
""";

  void _accept() {
    HiveDatabase.settingsBox.put('eula_accepted', true);
    context.go('/');
  }

  void _decline() {
    exit(0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('اتفاقية ترخيص الاستخدام'),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Card(
            margin: const EdgeInsets.all(24.0),
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.gavel_rounded, size: 64, color: Colors.teal),
                  const SizedBox(height: 16),
                  const Text(
                    'Nayli Market POS 🇩🇿',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.black26
                            : Colors.grey.shade100,
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SingleChildScrollView(
                        child: Text(
                          _eulaText,
                          style: const TextStyle(height: 1.6, fontSize: 15),
                          textDirection: TextDirection.rtl,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Checkbox(
                        value: _accepted,
                        activeColor: Colors.teal,
                        onChanged: (val) {
                          setState(() {
                            _accepted = val ?? false;
                          });
                        },
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _accepted = !_accepted;
                          });
                        },
                        child: const Text(
                          'لقد قرأت جميع البنود وأوافق على شروط الاستخدام',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _decline,
                        icon: const Icon(Icons.close),
                        label: const Text('رفض وإغلاق', style: TextStyle(fontSize: 15)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          foregroundColor: Colors.red,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _accepted ? _accept : null,
                        icon: const Icon(Icons.check),
                        label: const Text('موافقة ومتابعة', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
