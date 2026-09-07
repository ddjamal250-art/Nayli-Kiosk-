import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/data/hive_database.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/utils/app_constants.dart';
import '../../../../core/utils/snackbar_helper.dart';
import '../../../../core/utils/sound_service.dart';
import '../../../product/domain/entities/product.dart';
import '../../../product/presentation/bloc/product_bloc.dart';
import '../bloc/billing_bloc.dart';

class SmartScaleModal extends StatefulWidget {
  const SmartScaleModal({super.key});

  @override
  State<SmartScaleModal> createState() => _SmartScaleModalState();
}

class _SmartScaleModalState extends State<SmartScaleModal> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _pricePerKgController = TextEditingController();
  final TextEditingController _costPerKgController = TextEditingController();
  final TextEditingController _weightController = TextEditingController(); // in grams
  final TextEditingController _amountController = TextEditingController(); // in DZD

  bool _isByWeight = true; // true = by weight, false = by fixed amount (e.g. 100 DZD)
  String? _selectedProductId;
  double _currentStockKg = 50.0;
  String _selectedCategory = 'الكل';

  List<Map<String, dynamic>> _scaleProducts = [];
  List<Map<String, dynamic>> _filteredProducts = [];

  static const List<String> _categories = [
    'الكل',
    '🌾 بقوليات وحبوب',
    '🫒 زيتون ومخللات',
    '🧀 أجبان وكاشير',
    '🌶️ توابل وعطارة',
    '🥜 مكسرات وفواكه جافة',
    '🥔 خضر وفواكه',
    '🍗 لحوم ودواجن',
  ];

  static const List<Map<String, dynamic>> _defaultPresets = [
    // 🌾 بقوليات وحبوب
    {'name': 'عدس كندا بالميزان', 'category': '🌾 بقوليات وحبوب', 'pricePerKg': 260.0, 'costPerKg': 210.0, 'stockKg': 50.0, 'barcode': 'SCALE_LENTIL'},
    {'name': 'حمص خشن بالميزان', 'category': '🌾 بقوليات وحبوب', 'pricePerKg': 280.0, 'costPerKg': 230.0, 'stockKg': 40.0, 'barcode': 'SCALE_CHICKPEA'},
    {'name': 'لوبيا بيضاء بالميزان', 'category': '🌾 بقوليات وحبوب', 'pricePerKg': 340.0, 'costPerKg': 290.0, 'stockKg': 30.0, 'barcode': 'SCALE_BEAN'},
    {'name': 'لوبيا حمراء بالميزان', 'category': '🌾 بقوليات وحبوب', 'pricePerKg': 320.0, 'costPerKg': 270.0, 'stockKg': 20.0, 'barcode': 'SCALE_RED_BEAN'},
    {'name': 'فريك شوربة قمح صلب', 'category': '🌾 بقوليات وحبوب', 'pricePerKg': 450.0, 'costPerKg': 370.0, 'stockKg': 25.0, 'barcode': 'SCALE_FRIK'},
    {'name': 'مرموز شوربة بالميزان', 'category': '🌾 بقوليات وحبوب', 'pricePerKg': 380.0, 'costPerKg': 310.0, 'stockKg': 20.0, 'barcode': 'SCALE_MERMEZ'},
    {'name': 'جلبانة يابسة مقسومة', 'category': '🌾 بقوليات وحبوب', 'pricePerKg': 240.0, 'costPerKg': 190.0, 'stockKg': 25.0, 'barcode': 'SCALE_POIS_CASSE'},
    {'name': 'أرز أبيض مفور بالميزان', 'category': '🌾 بقوليات وحبوب', 'pricePerKg': 160.0, 'costPerKg': 130.0, 'stockKg': 60.0, 'barcode': 'SCALE_RICE_ETUVE'},
    {'name': 'أرز بسمتي هندي بالميزان', 'category': '🌾 بقوليات وحبوب', 'pricePerKg': 320.0, 'costPerKg': 260.0, 'stockKg': 30.0, 'barcode': 'SCALE_RICE_BASMATI'},
    {'name': 'سميد سيم/ماما بالميزان', 'category': '🌾 بقوليات وحبوب', 'pricePerKg': 95.0, 'costPerKg': 80.0, 'stockKg': 100.0, 'barcode': 'SCALE_SEMOLINA'},
    {'name': 'فرينة بيضاء بالميزان', 'category': '🌾 بقوليات وحبوب', 'pricePerKg': 50.0, 'costPerKg': 40.0, 'stockKg': 100.0, 'barcode': 'SCALE_FLOUR'},
    {'name': 'سكر أبيض بالميزان', 'category': '🌾 بقوليات وحبوب', 'pricePerKg': 95.0, 'costPerKg': 82.0, 'stockKg': 150.0, 'barcode': 'SCALE_SUGAR'},
    {'name': 'ملح طعام بحري بالميزان', 'category': '🌾 بقوليات وحبوب', 'pricePerKg': 35.0, 'costPerKg': 20.0, 'stockKg': 50.0, 'barcode': 'SCALE_SALT'},
    {'name': 'شوفان حبة كاملة بالميزان', 'category': '🌾 بقوليات وحبوب', 'pricePerKg': 420.0, 'costPerKg': 340.0, 'stockKg': 15.0, 'barcode': 'SCALE_OATS'},

    // 🫒 زيتون ومخللات
    {'name': 'زيتون أخضر مقطع رونديل', 'category': '🫒 زيتون ومخللات', 'pricePerKg': 360.0, 'costPerKg': 280.0, 'stockKg': 20.0, 'barcode': 'SCALE_OLIVE_G'},
    {'name': 'زيتون أخضر مفرغ بدون نواة', 'category': '🫒 زيتون ومخللات', 'pricePerKg': 420.0, 'costPerKg': 330.0, 'stockKg': 20.0, 'barcode': 'SCALE_OLIVE_DENOY'},
    {'name': 'زيتون أخضر مشمل حار', 'category': '🫒 زيتون ومخللات', 'pricePerKg': 400.0, 'costPerKg': 310.0, 'stockKg': 20.0, 'barcode': 'SCALE_OLIVE_SPICY'},
    {'name': 'زيتون أسود مجعد بالميزان', 'category': '🫒 زيتون ومخللات', 'pricePerKg': 460.0, 'costPerKg': 360.0, 'stockKg': 20.0, 'barcode': 'SCALE_OLIVE_B'},
    {'name': 'زيتون أسود مخلل يوناني', 'category': '🫒 زيتون ومخللات', 'pricePerKg': 550.0, 'costPerKg': 440.0, 'stockKg': 15.0, 'barcode': 'SCALE_OLIVE_KALAMATA'},
    {'name': 'مخللات مشكلة كورنيشون', 'category': '🫒 زيتون ومخللات', 'pricePerKg': 380.0, 'costPerKg': 290.0, 'stockKg': 20.0, 'barcode': 'SCALE_PICKLES'},

    // 🧀 أجبان وكاشير
    {'name': 'كاشير أحمر بالميزان', 'category': '🧀 أجبان وكاشير', 'pricePerKg': 380.0, 'costPerKg': 290.0, 'stockKg': 15.0, 'barcode': 'SCALE_CACHIR_RED'},
    {'name': 'باتي دجاج وزيتون بالميزان', 'category': '🧀 أجبان وكاشير', 'pricePerKg': 450.0, 'costPerKg': 350.0, 'stockKg': 15.0, 'barcode': 'SCALE_PATE_OLIVE'},
    {'name': 'سلامي مدخن بالميزان', 'category': '🧀 أجبان وكاشير', 'pricePerKg': 850.0, 'costPerKg': 680.0, 'stockKg': 10.0, 'barcode': 'SCALE_SALAMI'},
    {'name': 'جبن أحمر غودا / كودة', 'category': '🧀 أجبان وكاشير', 'pricePerKg': 1250.0, 'costPerKg': 1020.0, 'stockKg': 10.0, 'barcode': 'SCALE_CHEESE_GOUDA'},
    {'name': 'جبن موزاريلا قوالب بالميزان', 'category': '🧀 أجبان وكاشير', 'pricePerKg': 950.0, 'costPerKg': 760.0, 'stockKg': 15.0, 'barcode': 'SCALE_MOZZARELLA'},
    {'name': 'جبن إيدام هولندي بالميزان', 'category': '🧀 أجبان وكاشير', 'pricePerKg': 1350.0, 'costPerKg': 1100.0, 'stockKg': 10.0, 'barcode': 'SCALE_EDAM'},
    {'name': 'جبن طري أبيض بالميزان', 'category': '🧀 أجبان وكاشير', 'pricePerKg': 420.0, 'costPerKg': 330.0, 'stockKg': 20.0, 'barcode': 'SCALE_FROMAGE_BLANC'},
    {'name': 'زبدة عرب طبيعية بالميزان', 'category': '🧀 أجبان وكاشير', 'pricePerKg': 1600.0, 'costPerKg': 1350.0, 'stockKg': 10.0, 'barcode': 'SCALE_BEURRE_ARAB'},

    // 🌶️ توابل وعطارة
    {'name': 'فلفل أسود حب / مطحون', 'category': '🌶️ توابل وعطارة', 'pricePerKg': 1800.0, 'costPerKg': 1450.0, 'stockKg': 10.0, 'barcode': 'SCALE_BLACK_PEPPER'},
    {'name': 'فلفل عكري أحمر حلو', 'category': '🌶️ توابل وعطارة', 'pricePerKg': 950.0, 'costPerKg': 750.0, 'stockKg': 15.0, 'barcode': 'SCALE_PAPRIKA'},
    {'name': 'فلفل أحمر حار سودانية', 'category': '🌶️ توابل وعطارة', 'pricePerKg': 1100.0, 'costPerKg': 880.0, 'stockKg': 10.0, 'barcode': 'SCALE_PIMENT_FORT'},
    {'name': 'كمون عريض هندي مرحي', 'category': '🌶️ توابل وعطارة', 'pricePerKg': 1400.0, 'costPerKg': 1100.0, 'stockKg': 10.0, 'barcode': 'SCALE_CUMIN'},
    {'name': 'رأس الحانوت أصلي مشكل', 'category': '🌶️ توابل وعطارة', 'pricePerKg': 1200.0, 'costPerKg': 950.0, 'stockKg': 15.0, 'barcode': 'SCALE_RAS_HANOUT'},
    {'name': 'كروية مرحية', 'category': '🌶️ توابل وعطارة', 'pricePerKg': 1100.0, 'costPerKg': 850.0, 'stockKg': 10.0, 'barcode': 'SCALE_CARVI'},
    {'name': 'قرفة عود / مرحية', 'category': '🌶️ توابل وعطارة', 'pricePerKg': 2200.0, 'costPerKg': 1750.0, 'stockKg': 8.0, 'barcode': 'SCALE_CINNAMON'},
    {'name': 'زنجبيل مرحي', 'category': '🌶️ توابل وعطارة', 'pricePerKg': 1300.0, 'costPerKg': 1000.0, 'stockKg': 10.0, 'barcode': 'SCALE_GINGEMBRE'},
    {'name': 'كركم أصفر مرحي', 'category': '🌶️ توابل وعطارة', 'pricePerKg': 950.0, 'costPerKg': 750.0, 'stockKg': 15.0, 'barcode': 'SCALE_CURCUMA'},
    {'name': 'كزبرة يابسة مطحونة', 'category': '🌶️ توابل وعطارة', 'pricePerKg': 800.0, 'costPerKg': 620.0, 'stockKg': 12.0, 'barcode': 'SCALE_KOSBOR'},
    {'name': 'ثوم غبرة مرحي', 'category': '🌶️ توابل وعطارة', 'pricePerKg': 1100.0, 'costPerKg': 850.0, 'stockKg': 10.0, 'barcode': 'SCALE_AIL_POUDRE'},
    {'name': 'سانوج حبة البركة', 'category': '🌶️ توابل وعطارة', 'pricePerKg': 1200.0, 'costPerKg': 920.0, 'stockKg': 10.0, 'barcode': 'SCALE_SANOUJ'},
    {'name': 'جلجلان سمسم محمص', 'category': '🌶️ توابل وعطارة', 'pricePerKg': 950.0, 'costPerKg': 750.0, 'stockKg': 15.0, 'barcode': 'SCALE_SESAME'},
    {'name': 'قرنفل أعواد بالميزان', 'category': '🌶️ توابل وعطارة', 'pricePerKg': 3200.0, 'costPerKg': 2600.0, 'stockKg': 5.0, 'barcode': 'SCALE_GIROFLE'},
    {'name': 'قهوة حب مطحونة فريش', 'category': '🌶️ توابل وعطارة', 'pricePerKg': 1400.0, 'costPerKg': 1150.0, 'stockKg': 20.0, 'barcode': 'SCALE_COFFEE_BULK'},

    // 🥜 مكسرات وفواكه جافة
    {'name': 'حلوة الترك الغزالة بالميزان', 'category': '🥜 مكسرات وفواكه جافة', 'pricePerKg': 600.0, 'costPerKg': 480.0, 'stockKg': 15.0, 'barcode': 'SCALE_HALWA'},
    {'name': 'كاوكاو مقلي مالح بالقشور', 'category': '🥜 مكسرات وفواكه جافة', 'pricePerKg': 650.0, 'costPerKg': 520.0, 'stockKg': 25.0, 'barcode': 'SCALE_PEANUTS_SALT'},
    {'name': 'كاوكاو نيء أبيض للحلويات', 'category': '🥜 مكسرات وفواكه جافة', 'pricePerKg': 520.0, 'costPerKg': 410.0, 'stockKg': 30.0, 'barcode': 'SCALE_PEANUTS_RAW'},
    {'name': 'لوز حلو كامل نيء', 'category': '🥜 مكسرات وفواكه جافة', 'pricePerKg': 2200.0, 'costPerKg': 1850.0, 'stockKg': 15.0, 'barcode': 'SCALE_ALMONDS'},
    {'name': 'لوز مقشر أبيض إيفيلي', 'category': '🥜 مكسرات وفواكه جافة', 'pricePerKg': 2500.0, 'costPerKg': 2100.0, 'stockKg': 10.0, 'barcode': 'SCALE_ALMONDS_WHITE'},
    {'name': 'جوز مقشر حبة كاملة', 'category': '🥜 مكسرات وفواكه جافة', 'pricePerKg': 2400.0, 'costPerKg': 2000.0, 'stockKg': 10.0, 'barcode': 'SCALE_WALNUTS'},
    {'name': 'بندق مقشر بالميزان', 'category': '🥜 مكسرات وفواكه جافة', 'pricePerKg': 2600.0, 'costPerKg': 2150.0, 'stockKg': 8.0, 'barcode': 'SCALE_NOISETTES'},
    {'name': 'كاجو محمص مالح', 'category': '🥜 مكسرات وفواكه جافة', 'pricePerKg': 2800.0, 'costPerKg': 2300.0, 'stockKg': 8.0, 'barcode': 'SCALE_CAJOU'},
    {'name': 'بيستاش فستق محمص مالح', 'category': '🥜 مكسرات وفواكه جافة', 'pricePerKg': 3200.0, 'costPerKg': 2650.0, 'stockKg': 8.0, 'barcode': 'SCALE_PISTACHE'},
    {'name': 'زبيب أسود / أشقر بالميزان', 'category': '🥜 مكسرات وفواكه جافة', 'pricePerKg': 850.0, 'costPerKg': 680.0, 'stockKg': 20.0, 'barcode': 'SCALE_RAISINS'},
    {'name': 'مشمش جاف تورت بالميزان', 'category': '🥜 مكسرات وفواكه جافة', 'pricePerKg': 1800.0, 'costPerKg': 1450.0, 'stockKg': 10.0, 'barcode': 'SCALE_ABRICOTS'},
    {'name': 'عين بقرة برقوق مجفف', 'category': '🥜 مكسرات وفواكه جافة', 'pricePerKg': 1400.0, 'costPerKg': 1100.0, 'stockKg': 15.0, 'barcode': 'SCALE_PRUNEAUX'},
    {'name': 'تمر دقلة نور بسكرة', 'category': '🥜 مكسرات وفواكه جافة', 'pricePerKg': 550.0, 'costPerKg': 420.0, 'stockKg': 30.0, 'barcode': 'SCALE_DATES'},
    {'name': 'جوز الهند مبشور نوادكوكو', 'category': '🥜 مكسرات وفواكه جافة', 'pricePerKg': 850.0, 'costPerKg': 680.0, 'stockKg': 15.0, 'barcode': 'SCALE_COCO'},
    {'name': 'غرس تمر معجون بالميزان', 'category': '🥜 مكسرات وفواكه جافة', 'pricePerKg': 350.0, 'costPerKg': 260.0, 'stockKg': 25.0, 'barcode': 'SCALE_GHARS'},

    // 🥔 خضر وفواكه
    {'name': 'بطاطا استهلاك بالميزان', 'category': '🥔 خضر وفواكه', 'pricePerKg': 85.0, 'costPerKg': 65.0, 'stockKg': 100.0, 'barcode': 'SCALE_POTATO'},
    {'name': 'طماطم طازجة حمراء', 'category': '🥔 خضر وفواكه', 'pricePerKg': 120.0, 'costPerKg': 90.0, 'stockKg': 40.0, 'barcode': 'SCALE_TOMATO'},
    {'name': 'بصل أحمر يابس بالميزان', 'category': '🥔 خضر وفواكه', 'pricePerKg': 70.0, 'costPerKg': 50.0, 'stockKg': 60.0, 'barcode': 'SCALE_ONION'},
    {'name': 'ثوم يابس بالميزان', 'category': '🥔 خضر وفواكه', 'pricePerKg': 450.0, 'costPerKg': 350.0, 'stockKg': 20.0, 'barcode': 'SCALE_AIL'},
    {'name': 'جزر زرودية طازجة', 'category': '🥔 خضر وفواكه', 'pricePerKg': 80.0, 'costPerKg': 55.0, 'stockKg': 40.0, 'barcode': 'SCALE_CARROT'},
    {'name': 'كوسة قرعة طازجة', 'category': '🥔 خضر وفواكه', 'pricePerKg': 110.0, 'costPerKg': 80.0, 'stockKg': 25.0, 'barcode': 'SCALE_COURGETTE'},
    {'name': 'فلفل حلو طرشي', 'category': '🥔 خضر وفواكه', 'pricePerKg': 130.0, 'costPerKg': 95.0, 'stockKg': 25.0, 'barcode': 'SCALE_POIVRON'},
    {'name': 'فلفل حار فريش', 'category': '🥔 خضر وفواكه', 'pricePerKg': 160.0, 'costPerKg': 120.0, 'stockKg': 20.0, 'barcode': 'SCALE_PIMENT'},
    {'name': 'خيار طازج بالميزان', 'category': '🥔 خضر وفواكه', 'pricePerKg': 120.0, 'costPerKg': 85.0, 'stockKg': 30.0, 'barcode': 'SCALE_CONCOMBRE'},
    {'name': 'سلطة خس فريش', 'category': '🥔 خضر وفواكه', 'pricePerKg': 140.0, 'costPerKg': 95.0, 'stockKg': 20.0, 'barcode': 'SCALE_SALADE'},
    {'name': 'موز مستورد (بنان)', 'category': '🥔 خضر وفواكه', 'pricePerKg': 380.0, 'costPerKg': 320.0, 'stockKg': 35.0, 'barcode': 'SCALE_BANANA'},
    {'name': 'تفاح محلي ممتاز', 'category': '🥔 خضر وفواكه', 'pricePerKg': 280.0, 'costPerKg': 210.0, 'stockKg': 30.0, 'barcode': 'SCALE_APPLE'},
    {'name': 'برتقال طومسون فريش', 'category': '🥔 خضر وفواكه', 'pricePerKg': 160.0, 'costPerKg': 115.0, 'stockKg': 40.0, 'barcode': 'SCALE_ORANGE'},
    {'name': 'يوسفي مندارين بالميزان', 'category': '🥔 خضر وفواكه', 'pricePerKg': 180.0, 'costPerKg': 130.0, 'stockKg': 30.0, 'barcode': 'SCALE_MANDARINE'},
    {'name': 'ليمون حامض فريش', 'category': '🥔 خضر وفواكه', 'pricePerKg': 220.0, 'costPerKg': 160.0, 'stockKg': 20.0, 'barcode': 'SCALE_LEMON'},
    {'name': 'دلاع بطيخ أحمر بالميزان', 'category': '🥔 خضر وفواكه', 'pricePerKg': 60.0, 'costPerKg': 40.0, 'stockKg': 100.0, 'barcode': 'SCALE_WATERMELON'},

    // 🍗 لحوم ودواجن
    {'name': 'دجاج طازج بالميزان', 'category': '🍗 لحوم ودواجن', 'pricePerKg': 480.0, 'costPerKg': 420.0, 'stockKg': 50.0, 'barcode': 'SCALE_CHICKEN'},
    {'name': 'إسكالوب دجاج/داند بدون عظم', 'category': '🍗 لحوم ودواجن', 'pricePerKg': 950.0, 'costPerKg': 820.0, 'stockKg': 30.0, 'barcode': 'SCALE_ESCALOPE'},
    {'name': 'فخذ دجاج كامل فريش', 'category': '🍗 لحوم ودواجن', 'pricePerKg': 450.0, 'costPerKg': 380.0, 'stockKg': 30.0, 'barcode': 'SCALE_CUISSES'},
    {'name': 'لحم مفروم فاشي طازج', 'category': '🍗 لحوم ودواجن', 'pricePerKg': 2200.0, 'costPerKg': 1900.0, 'stockKg': 15.0, 'barcode': 'SCALE_MEAT_MINCED'},
    {'name': 'لحم خروف غنمي محلي', 'category': '🍗 لحوم ودواجن', 'pricePerKg': 2400.0, 'costPerKg': 2100.0, 'stockKg': 20.0, 'barcode': 'SCALE_MEAT_LAMB'},
    {'name': 'لحم بقري هبرة بدون عظم', 'category': '🍗 لحوم ودواجن', 'pricePerKg': 2200.0, 'costPerKg': 1900.0, 'stockKg': 20.0, 'barcode': 'SCALE_MEAT_BEEF'},
    {'name': 'مرقاز بلدي طازج بالميزان', 'category': '🍗 لحوم ودواجن', 'pricePerKg': 1400.0, 'costPerKg': 1150.0, 'stockKg': 15.0, 'barcode': 'SCALE_MERGUEZ'},
    {'name': 'سردين طازج بالميزان', 'category': '🍗 لحوم ودواجن', 'pricePerKg': 600.0, 'costPerKg': 480.0, 'stockKg': 20.0, 'barcode': 'SCALE_SARDINE'},
  ];

  @override
  void initState() {
    super.initState();
    _loadScaleProducts();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _nameController.dispose();
    _pricePerKgController.dispose();
    _costPerKgController.dispose();
    _weightController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _loadScaleProducts() {
    final List<Map<String, dynamic>> list = [];
    final pBox = HiveDatabase.productBox;

    // Load from products database
    for (final p in pBox.values) {
      if (p.barcode.startsWith('SCALE_') || p.name.contains('ميزان') || p.name.contains('كغ')) {
        list.add({
          'id': p.id,
          'name': p.name,
          'pricePerKg': p.price,
          'costPerKg': p.costPrice,
          'stockKg': p.stock.toDouble(),
          'barcode': p.barcode,
          'category': '🌾 بقوليات وحبوب',
        });
      }
    }

    // Merge default presets if not in database
    for (final def in _defaultPresets) {
      if (!list.any((e) => e['name'].toString().trim() == def['name'].toString().trim())) {
        list.add(Map<String, dynamic>.from(def));
      }
    }

    setState(() {
      _scaleProducts = list;
      _filteredProducts = List.from(list);
    });
  }

  String _normalizeArabic(String text) {
    return text
        .replaceAll(RegExp(r'[أإآا]'), 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي')
        .toLowerCase()
        .trim();
  }

  void _onSearchChanged() {
    final rawQuery = _searchController.text.trim();
    final query = _normalizeArabic(rawQuery);

    setState(() {
      _filteredProducts = _scaleProducts.where((p) {
        final matchesCat = _selectedCategory == 'الكل' || p['category'] == _selectedCategory;
        if (!matchesCat) return false;

        if (query.isEmpty) return true;
        final name = _normalizeArabic(p['name']?.toString() ?? '');
        final barcode = p['barcode']?.toString().toLowerCase() ?? '';
        return name.contains(query) || barcode.contains(query);
      }).toList();
    });
  }

  void _onCategorySelected(String category) {
    setState(() {
      _selectedCategory = category;
    });
    _onSearchChanged();
  }

  void _selectProduct(Map<String, dynamic> product) {
    setState(() {
      _selectedProductId = product['id']?.toString() ?? product['barcode']?.toString();
      _nameController.text = product['name'] ?? '';
      _pricePerKgController.text = (product['pricePerKg'] as num?)?.toStringAsFixed(0) ?? '0';
      _costPerKgController.text = (product['costPerKg'] as num?)?.toStringAsFixed(0) ?? '0';
      _currentStockKg = (product['stockKg'] as num?)?.toDouble() ?? 50.0;
    });
    SoundService.playScanBeep();
  }

  void _showAddScaleProductDialog() {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final costCtrl = TextEditingController();
    final directKgCtrl = TextEditingController(text: '50');
    final bagsCountCtrl = TextEditingController(text: '2');
    final bagWeightCtrl = TextEditingController(text: '25');
    final supplierCtrl = TextEditingController();
    bool isBagsMode = false;
    String selectedCat = '🌾 بقوليات وحبوب';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.add_shopping_cart, color: AppTheme.primaryColor),
              SizedBox(width: 8),
              Text('إضافة مادة ميزان جديدة وتفاصيل المخزون', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: context.tr('item_name'),
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  ),
                ),
                const SizedBox(height: 10),

                // Category Dropdown
                DropdownButtonFormField<String>(
                  value: selectedCat,
                  decoration: const InputDecoration(
                    labelText: context.tr('category'),
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  ),
                  items: _categories.where((c) => c != 'الكل').map((cat) {
                    return DropdownMenuItem(value: cat, child: Text(cat, style: const TextStyle(fontSize: 12)));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedCat = val);
                  },
                ),
                const SizedBox(height: 10),

                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: priceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: context.tr('selling_price_per_kg'),
                          suffixText: AppConstants.currencySymbol,
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: costCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: context.tr('cost_price'),
                          suffixText: AppConstants.currencySymbol,
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Supply Method (Bags / Direct Kg)
                const Text('طريقة احتساب وتوريد المخزون:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    ChoiceChip(
                      label: Text(context.tr('by_bags_sacks'), style: const TextStyle(fontSize: 11)),
                      selected: isBagsMode,
                      onSelected: (v) => setDialogState(() => isBagsMode = true),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: Text(context.tr('by_direct_kg'), style: const TextStyle(fontSize: 11)),
                      selected: !isBagsMode,
                      onSelected: (v) => setDialogState(() => isBagsMode = false),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                if (isBagsMode) ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: bagsCountCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: context.tr('sacks_count'),
                            suffixText: 'شكارة',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          ),
                          onChanged: (_) => setDialogState(() {}),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: bagWeightCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: context.tr('sack_weight'),
                            suffixText: 'كغ',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          ),
                          onChanged: (_) => setDialogState(() {}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Builder(
                    builder: (_) {
                      final bags = int.tryParse(bagsCountCtrl.text.trim()) ?? 0;
                      final weight = double.tryParse(bagWeightCtrl.text.trim()) ?? 0.0;
                      final total = bags * weight;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: Colors.green.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
                        child: Text(
                          '📦 إجمالي المخزون: $total كغ ($bags شكارة × $weight كغ)',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green),
                        ),
                      );
                    },
                  ),
                ] else ...[
                  TextField(
                    controller: directKgCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: context.tr('direct_total_stock_kg'),
                      suffixText: 'كغ',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    ),
                  ),
                ],
                const SizedBox(height: 12),

                TextField(
                  controller: supplierCtrl,
                  decoration: const InputDecoration(
                    labelText: context.tr('supplier_optional'),
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.tr('cancel'))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
              onPressed: () {
                final name = nameCtrl.text.trim();
                final price = double.tryParse(priceCtrl.text.trim()) ?? 0.0;
                final cost = double.tryParse(costCtrl.text.trim()) ?? (price * 0.8);
                if (name.isEmpty || price <= 0) return;

                double totalStock = 0.0;
                if (isBagsMode) {
                  final bags = int.tryParse(bagsCountCtrl.text.trim()) ?? 0;
                  final bWeight = double.tryParse(bagWeightCtrl.text.trim()) ?? 25.0;
                  totalStock = bags * bWeight;
                } else {
                  totalStock = double.tryParse(directKgCtrl.text.trim()) ?? 50.0;
                }

                final newProdId = const Uuid().v4();
                final rawBarcode = 'SCALE_${DateTime.now().millisecondsSinceEpoch}';

                final newProd = Product(
                  id: newProdId,
                  name: name,
                  barcode: rawBarcode,
                  price: price,
                  costPrice: cost,
                  stock: totalStock.toInt(),
                );

                context.read<ProductBloc>().add(AddProduct(newProd));

                final itemMap = {
                  'id': newProdId,
                  'name': name,
                  'category': selectedCat,
                  'pricePerKg': price,
                  'costPerKg': cost,
                  'stockKg': totalStock,
                  'barcode': rawBarcode,
                };

                setState(() {
                  _scaleProducts.insert(0, itemMap);
                  _selectProduct(itemMap);
                });

                Navigator.pop(ctx);
                SoundService.playCheckoutSuccess();
                context.showAppSnackBar(
                  '✅ تم حفظ مادة الميزان ($name) بمخزون $totalStock كغ!',
                  backgroundColor: Colors.green[800]!,
                );
              },
              child: Text(context.tr('save_and_insert'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  double get _calculatedTotal {
    final pricePerKg = double.tryParse(_pricePerKgController.text.trim()) ?? 0.0;
    if (_isByWeight) {
      final grams = double.tryParse(_weightController.text.trim()) ?? 0.0;
      return (pricePerKg * (grams / 1000.0)).roundToDouble();
    } else {
      return double.tryParse(_amountController.text.trim()) ?? 0.0;
    }
  }

  double get _calculatedGrams {
    final pricePerKg = double.tryParse(_pricePerKgController.text.trim()) ?? 0.0;
    if (pricePerKg <= 0) return 0.0;
    if (_isByWeight) {
      return double.tryParse(_weightController.text.trim()) ?? 0.0;
    } else {
      final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
      return ((amount / pricePerKg) * 1000.0).roundToDouble();
    }
  }

  void _onAddToCart() {
    final name = _nameController.text.trim().isEmpty ? 'سلعة ميزان' : _nameController.text.trim();
    final pricePerKg = double.tryParse(_pricePerKgController.text.trim()) ?? 0.0;
    final costPerKg = double.tryParse(_costPerKgController.text.trim()) ?? (pricePerKg * 0.8);
    final finalTotal = _calculatedTotal;
    final grams = _calculatedGrams;
    final weightKg = grams / 1000.0;

    if (finalTotal <= 0 || grams <= 0) {
      context.showAppSnackBar('يرجى تحديد وزن أو مبلغ صحيح!', backgroundColor: Colors.red[800]!);
      return;
    }

    final String weightLabel = grams >= 1000 ? '${(grams / 1000).toStringAsFixed(2)} كغ' : '${grams.toInt()} غ';
    final customItemName = '$name ($weightLabel)';
    final rawBarcode = 'SCALE_${DateTime.now().millisecondsSinceEpoch}';

    // 1. Add to cart
    context.read<BillingBloc>().add(AddCustomItemEvent(
      name: customItemName,
      price: finalTotal,
      costPrice: (costPerKg * weightKg).roundToDouble(),
      quantity: 1,
      barcode: rawBarcode,
    ));

    // 2. Deduct from product stock if registered in ProductBox
    final pBox = HiveDatabase.productBox;
    final matching = pBox.values.where((p) => p.name.trim() == name.trim() || p.id == _selectedProductId).firstOrNull;
    if (matching != null) {
      final current = matching.stock;
      final newStock = (current - weightKg).clamp(0.0, double.infinity).toInt();
      final updated = Product(
        id: matching.id,
        name: matching.name,
        barcode: matching.barcode,
        price: matching.price,
        costPrice: matching.costPrice,
        stock: newStock,
      );
      context.read<ProductBloc>().add(UpdateProduct(updated));
    }

    Navigator.pop(context);
    SoundService.playScanBeep();
    context.showAppSnackBar(
      '✅ تمت إضافة $customItemName بمبلغ $finalTotal ${AppConstants.currencySymbol}!',
      backgroundColor: Colors.teal[800]!,
      icon: Icons.scale_rounded,
    );
  }

  @override
  Widget build(BuildContext context) {
    final grams = _calculatedGrams;
    final total = _calculatedTotal;

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Modal Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.scale_rounded, color: AppTheme.primaryColor, size: 24),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'حاسبة سلع الميزان والتجزئة (Vrac) ⚖️',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                )
              ],
            ),
            const SizedBox(height: 12),

            // SEARCH BAR & ADD PRODUCT ROW
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: context.tr('search_scale_item_hint'),
                      prefixIcon: const Icon(Icons.search, size: 20, color: AppTheme.primaryColor),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () => _searchController.clear(),
                            )
                          : null,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(context.tr('add_item_btn'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: _showAddScaleProductDialog,
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Category Filter Chips
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (context, index) {
                  final cat = _categories[index];
                  final isSelected = _selectedCategory == cat;
                  return ChoiceChip(
                    label: Text(cat, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                    selected: isSelected,
                    selectedColor: AppTheme.primaryColor.withOpacity(0.15),
                    onSelected: (_) => _onCategorySelected(cat),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),

            // SCALE PRODUCTS HORIZONTAL LIST / GRID
            SizedBox(
              height: 72,
              child: _filteredProducts.isEmpty
                  ? Center(
                      child: Text(
                        'لا توجد مواد تطابق "${_searchController.text}"',
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                    )
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _filteredProducts.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final item = _filteredProducts[index];
                        final isSelected = _nameController.text.trim() == item['name'].toString().trim();
                        final price = (item['pricePerKg'] as num?)?.toDouble() ?? 0.0;

                        return InkWell(
                          onTap: () => _selectProduct(item),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 140,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isSelected ? AppTheme.primaryColor.withOpacity(0.1) : Colors.grey[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? AppTheme.primaryColor : Colors.grey[300]!,
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['name'] ?? '',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? AppTheme.primaryColor : Colors.black87,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${price.toStringAsFixed(0)} ${AppConstants.currencySymbol}/كغ',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected ? AppTheme.primaryColor : Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 12),

            // PRODUCT DETAILS FORM (Name & Price/Kg)
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: context.tr('selected_item'),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: TextField(
                    controller: _pricePerKgController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: context.tr('price_per_kg'),
                      suffixText: AppConstants.currencySymbol,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Mode Selector: By Weight (grams) vs By Amount (DZD)
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: Center(child: Text(context.tr('sell_by_weight_kg'))),
                    selected: _isByWeight,
                    onSelected: (val) {
                      setState(() {
                        _isByWeight = true;
                      });
                    },
                    selectedColor: AppTheme.primaryColor.withOpacity(0.2),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: Center(child: Text(context.tr('sell_by_amount_money'))),
                    selected: !_isByWeight,
                    onSelected: (val) {
                      setState(() {
                        _isByWeight = false;
                      });
                    },
                    selectedColor: AppTheme.primaryColor.withOpacity(0.2),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Input Fields depending on Mode
            if (_isByWeight) ...[
              TextField(
                controller: _weightController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                decoration: InputDecoration(
                  labelText: context.tr('weight_in_grams'),
                  hintText: 'مثال: 500 للرطل، 1000 للكيلو، 250 للربع...',
                  suffixText: 'غرام',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              // Preset Weight Buttons (250g, 500g, 1kg, 2kg, 5kg)
              Wrap(
                spacing: 6,
                children: [
                  _buildQuickWeightChip('100 غ', 100),
                  _buildQuickWeightChip('250 غ (ربع)', 250),
                  _buildQuickWeightChip('500 غ (رطل)', 500),
                  _buildQuickWeightChip('1 كغ', 1000),
                  _buildQuickWeightChip('2 كغ', 2000),
                  _buildQuickWeightChip('5 كغ', 5000),
                ],
              ),
            ] else ...[
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                decoration: InputDecoration(
                  labelText: '${context.tr("amount")} (${context.tr("currency_symbol")})',
                  hintText: 'مثال: اعطيني قيس 100 دج أو 200 دج...',
                  suffixText: AppConstants.currencySymbol,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              // Preset Amount Buttons (50 DA, 100 DA, 200 DA, 500 DA, 1000 DA)
              Wrap(
                spacing: 6,
                children: [
                  _buildQuickAmountChip('50 دج', 50),
                  _buildQuickAmountChip('100 دج', 100),
                  _buildQuickAmountChip('200 دج', 200),
                  _buildQuickAmountChip('500 دج', 500),
                  _buildQuickAmountChip('1000 دج', 1000),
                ],
              ),
            ],
            const SizedBox(height: 16),

            // LIVE CALCULATION RESULT CARD
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.tr('calculated_weight_label'), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      Text(
                        grams >= 1000 ? '${(grams / 1000).toStringAsFixed(2)} كغ' : '${grams.toInt()} غرام',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                      ),
                    ],
                  ),
                  Container(height: 30, width: 1, color: Colors.grey[300]),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(context.tr('total_amount_label'), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      Text(
                        '${total.toStringAsFixed(0)} ${AppConstants.currencySymbol}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ADD TO CART BUTTON
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.add_shopping_cart, size: 20),
              label: Text(
                'إضافة إلى السلة (${total.toStringAsFixed(0)} ${AppConstants.currencySymbol})',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              onPressed: _onAddToCart,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickWeightChip(String label, int grams) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      onPressed: () {
        setState(() {
          _weightController.text = grams.toString();
        });
      },
    );
  }

  Widget _buildQuickAmountChip(String label, int amount) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      onPressed: () {
        setState(() {
          _amountController.text = amount.toString();
        });
      },
    );
  }
}
