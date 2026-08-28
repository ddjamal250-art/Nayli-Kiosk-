class MasterCatalogItem {
  final String barcode;
  final String name;
  final String category;
  final double defaultPrice;
  final double defaultCost;

  const MasterCatalogItem({
    required this.barcode,
    required this.name,
    required this.category,
    this.defaultPrice = 0.0,
    this.defaultCost = 0.0,
  });
}

class MasterCatalogSeed {
  static const List<MasterCatalogItem> items = [
    // --- ألبان ومشتقات الحليب (Dairy) ---
    MasterCatalogItem(barcode: '6130001001011', name: 'حليب كانديا كامل الدسم 1L', category: 'ألبان', defaultPrice: 125.0, defaultCost: 110.0),
    MasterCatalogItem(barcode: '6130001001028', name: 'حليب كانديا نصف دسم 1L', category: 'ألبان', defaultPrice: 120.0, defaultCost: 105.0),
    MasterCatalogItem(barcode: '6130001001035', name: 'حليب كانديا سيليويت خالي الدسم 1L', category: 'ألبان', defaultPrice: 130.0, defaultCost: 115.0),
    MasterCatalogItem(barcode: '6130001001042', name: 'حليب كانديا فيفا 1L', category: 'ألبان', defaultPrice: 135.0, defaultCost: 120.0),
    MasterCatalogItem(barcode: '6130001001059', name: 'حليب كانديا شوكولا شوكولايت 20cl', category: 'ألبان', defaultPrice: 50.0, defaultCost: 40.0),
    MasterCatalogItem(barcode: '6131112000012', name: 'ياغورت صومام ممزوج فراولة', category: 'ألبان', defaultPrice: 30.0, defaultCost: 24.0),
    MasterCatalogItem(barcode: '6131112000029', name: 'ياغورت صومام طبيعي سادة', category: 'ألبان', defaultPrice: 25.0, defaultCost: 20.0),
    MasterCatalogItem(barcode: '6131112000036', name: 'ياغورت صومام ديسير فانيلا كراميل', category: 'ألبان', defaultPrice: 40.0, defaultCost: 32.0),
    MasterCatalogItem(barcode: '6131112000043', name: 'لبن صومام 1L', category: 'ألبان', defaultPrice: 110.0, defaultCost: 95.0),
    MasterCatalogItem(barcode: '6131112000050', name: 'جبن طري ترافاي بربر 16 قطعة', category: 'ألبان', defaultPrice: 260.0, defaultCost: 225.0),
    MasterCatalogItem(barcode: '6131112000067', name: 'جبن لافاش كيري 24 قطعة', category: 'ألبان', defaultPrice: 480.0, defaultCost: 420.0),
    MasterCatalogItem(barcode: '6131112000074', name: 'زبدة سيفيتال لابيل 250g', category: 'ألبان', defaultPrice: 115.0, defaultCost: 98.0),
    MasterCatalogItem(barcode: '6131112000081', name: 'مارغرين فلوريال 500g', category: 'ألبان', defaultPrice: 230.0, defaultCost: 195.0),

    // --- مشروبات ومياه معدنية (Beverages & Water) ---
    MasterCatalogItem(barcode: '6132001001019', name: 'ماء معدني إفرو 1.5L', category: 'مشروبات', defaultPrice: 40.0, defaultCost: 30.0),
    MasterCatalogItem(barcode: '6132001001026', name: 'ماء معدني إفرو 0.5L', category: 'مشروبات', defaultPrice: 25.0, defaultCost: 18.0),
    MasterCatalogItem(barcode: '6132001001033', name: 'ماء معدني سيدي الكبير 1.5L', category: 'مشروبات', defaultPrice: 35.0, defaultCost: 26.0),
    MasterCatalogItem(barcode: '6132001001040', name: 'ماء معدني للا خديجة 1.5L', category: 'مشروبات', defaultPrice: 40.0, defaultCost: 30.0),
    MasterCatalogItem(barcode: '6132001001057', name: 'مشروب حمود بوعلام سيليكتو 1L', category: 'مشروبات', defaultPrice: 110.0, defaultCost: 92.0),
    MasterCatalogItem(barcode: '6132001001064', name: 'مشروب حمود بوعلام سيليكتو 2L', category: 'مشروبات', defaultPrice: 180.0, defaultCost: 155.0),
    MasterCatalogItem(barcode: '6132001001071', name: 'مشروب حمود بوعلام ليمون بلانش 1L', category: 'مشروبات', defaultPrice: 110.0, defaultCost: 92.0),
    MasterCatalogItem(barcode: '6132001001088', name: 'عصير رامي برتقال وجزر 1L', category: 'مشروبات', defaultPrice: 130.0, defaultCost: 108.0),
    MasterCatalogItem(barcode: '6132001001095', name: 'عصير رامي غلال مشكلة 1.25L', category: 'مشروبات', defaultPrice: 140.0, defaultCost: 118.0),
    MasterCatalogItem(barcode: '6132001001101', name: 'عصير نغواس خوخ ومشمش 1L', category: 'مشروبات', defaultPrice: 135.0, defaultCost: 112.0),
    MasterCatalogItem(barcode: '5449000000996', name: 'كوكاكولا زجاجة 1L', category: 'مشروبات', defaultPrice: 120.0, defaultCost: 100.0),
    MasterCatalogItem(barcode: '5449000000439', name: 'كوكاكولا علبة معدنية 33cl', category: 'مشروبات', defaultPrice: 70.0, defaultCost: 55.0),
    MasterCatalogItem(barcode: '5449000014528', name: 'فانتا برتقال 1L', category: 'مشروبات', defaultPrice: 115.0, defaultCost: 95.0),
    MasterCatalogItem(barcode: '5449000027535', name: 'سبرايت 1L', category: 'مشروبات', defaultPrice: 115.0, defaultCost: 95.0),

    // --- بقالة ومواد غذائية أساسية (Groceries & Staples) ---
    MasterCatalogItem(barcode: '6133001001018', name: 'زيت المائدة إيليو 5L', category: 'مواد غذائية', defaultPrice: 650.0, defaultCost: 600.0),
    MasterCatalogItem(barcode: '6133001001025', name: 'زيت المائدة إيليو 1L', category: 'مواد غذائية', defaultPrice: 140.0, defaultCost: 125.0),
    MasterCatalogItem(barcode: '6133001001032', name: 'زيت المائدة عافية 5L', category: 'مواد غذائية', defaultPrice: 680.0, defaultCost: 620.0),
    MasterCatalogItem(barcode: '6133001001049', name: 'سكر أبيض سيفيتال 1kg', category: 'مواد غذائية', defaultPrice: 95.0, defaultCost: 85.0),
    MasterCatalogItem(barcode: '6133001001056', name: 'دقيق فاخر سفينة 1kg T45', category: 'مواد غذائية', defaultPrice: 50.0, defaultCost: 42.0),
    MasterCatalogItem(barcode: '6133001001063', name: 'دقيق سفينة 5kg', category: 'مواد غذائية', defaultPrice: 240.0, defaultCost: 210.0),
    MasterCatalogItem(barcode: '6133001001070', name: 'سميد سيم متوسط 1kg', category: 'مواد غذائية', defaultPrice: 95.0, defaultCost: 82.0),
    MasterCatalogItem(barcode: '6133001001087', name: 'سميد ماما ممتاز 1kg', category: 'مواد غذائية', defaultPrice: 90.0, defaultCost: 78.0),
    MasterCatalogItem(barcode: '6133001001094', name: 'عجائن سيم سباغيتي 500g', category: 'مواد غذائية', defaultPrice: 60.0, defaultCost: 48.0),
    MasterCatalogItem(barcode: '6133001001100', name: 'عجائن ماما مكرونة 500g', category: 'مواد غذائية', defaultPrice: 55.0, defaultCost: 45.0),
    MasterCatalogItem(barcode: '6133001001117', name: 'عجائن فريكور شوربة لسان الطير 500g', category: 'مواد غذائية', defaultPrice: 65.0, defaultCost: 52.0),
    MasterCatalogItem(barcode: '6133001001124', name: 'طماطم مصبرة عمور 800g', category: 'مواد غذائية', defaultPrice: 240.0, defaultCost: 205.0),
    MasterCatalogItem(barcode: '6133001001131', name: 'طماطم مصبرة كاب 400g', category: 'مواد غذائية', defaultPrice: 130.0, defaultCost: 110.0),
    MasterCatalogItem(barcode: '6133001001148', name: 'تونة بالطماطم إيزابيل 3x80g', category: 'مواد غذائية', defaultPrice: 380.0, defaultCost: 320.0),
    MasterCatalogItem(barcode: '6133001001155', name: 'تونة بالزيت ماريانو 160g', category: 'مواد غذائية', defaultPrice: 220.0, defaultCost: 185.0),
    MasterCatalogItem(barcode: '6133001001162', name: 'مايونيز ليسيور 250g', category: 'مواد غذائية', defaultPrice: 180.0, defaultCost: 150.0),
    MasterCatalogItem(barcode: '6133001001179', name: 'هريسة الصقر 140g', category: 'مواد غذائية', defaultPrice: 70.0, defaultCost: 55.0),

    // --- قهوة، شاي وبسكويت (Coffee, Tea & Biscuits) ---
    MasterCatalogItem(barcode: '6134001001017', name: 'قهوة مطحونة فاميكو 250g', category: 'قهوة وشاي', defaultPrice: 320.0, defaultCost: 280.0),
    MasterCatalogItem(barcode: '6134001001024', name: 'قهوة بن معطر 250g', category: 'قهوة وشاي', defaultPrice: 350.0, defaultCost: 300.0),
    MasterCatalogItem(barcode: '6134001001031', name: 'شاي أخضر المنيعة 250g', category: 'قهوة وشاي', defaultPrice: 220.0, defaultCost: 180.0),
    MasterCatalogItem(barcode: '6134001001048', name: 'شاي لبتون أكياس 25 كيس', category: 'قهوة وشاي', defaultPrice: 210.0, defaultCost: 175.0),
    MasterCatalogItem(barcode: '6134001001055', name: 'بسكويت بيمو غوفرات فانيلا', category: 'حلويات', defaultPrice: 40.0, defaultCost: 30.0),
    MasterCatalogItem(barcode: '6134001001062', name: 'بسكويت بيمو كوكيز شوكولا', category: 'حلويات', defaultPrice: 60.0, defaultCost: 48.0),
    MasterCatalogItem(barcode: '6134001001079', name: 'بسكويت بالماري توب كاكاو', category: 'حلويات', defaultPrice: 35.0, defaultCost: 26.0),
    MasterCatalogItem(barcode: '6134001001086', name: 'شوكولاتة الطلاء ماكسون 350g', category: 'حلويات', defaultPrice: 280.0, defaultCost: 235.0),
    MasterCatalogItem(barcode: '6134001001093', name: 'شوكولاتة الطلاء إلبيريا 400g', category: 'حلويات', defaultPrice: 320.0, defaultCost: 270.0),

    // --- تنظيف وعناية منزلية (Cleaning & Hygiene) ---
    MasterCatalogItem(barcode: '6135001001016', name: 'مسحوق غسيل إيزيس أوتوماتيك 3kg', category: 'تنظيف', defaultPrice: 620.0, defaultCost: 530.0),
    MasterCatalogItem(barcode: '6135001001023', name: 'مسحوق غسيل أومو يدوي 500g', category: 'تنظيف', defaultPrice: 140.0, defaultCost: 118.0),
    MasterCatalogItem(barcode: '6135001001030', name: 'سائل غسيل الأواني بريل 1L', category: 'تنظيف', defaultPrice: 220.0, defaultCost: 185.0),
    MasterCatalogItem(barcode: '6135001001047', name: 'سائل غسيل الأواني إيزيس 1.25L', category: 'تنظيف', defaultPrice: 190.0, defaultCost: 160.0),
    MasterCatalogItem(barcode: '6135001001054', name: 'ماء جافيل برافو 1L', category: 'تنظيف', defaultPrice: 60.0, defaultCost: 45.0),
    MasterCatalogItem(barcode: '6135001001061', name: 'معجون أسنان سيجنال مكافحة التسوس 75ml', category: 'نظافة', defaultPrice: 150.0, defaultCost: 120.0),
    MasterCatalogItem(barcode: '6135001001078', name: 'صابون دوف مرطب 100g', category: 'نظافة', defaultPrice: 130.0, defaultCost: 105.0),
    MasterCatalogItem(barcode: '6135001001085', name: 'شامبو ألترا دو بالزيتون 400ml', category: 'نظافة', defaultPrice: 380.0, defaultCost: 320.0),
  ];

  static MasterCatalogItem? lookup(String barcode) {
    try {
      return items.firstWhere((element) => element.barcode == barcode.trim());
    } catch (_) {
      return null;
    }
  }

  static List<MasterCatalogItem> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];
    return items.where((element) =>
      element.name.toLowerCase().contains(q) ||
      element.barcode.contains(q) ||
      element.category.toLowerCase().contains(q)
    ).toList();
  }
}
