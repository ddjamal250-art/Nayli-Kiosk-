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
  static const List<String> categories = [
    'الكل',
    'ألبان وأجبان',
    'مشروبات ومياه',
    'مواد غذائية',
    'معلبات وتونة',
    'قهوة وشاي',
    'حلويات وبسكويت',
    'تنظيف ونظافة',
  ];

  static const List<MasterCatalogItem> items = [
    // 🥛 ألبان وأجبان
    MasterCatalogItem(barcode: '6130001001011', name: 'حليب كانديا كامل الدسم 1L', category: 'ألبان وأجبان', defaultPrice: 125.0, defaultCost: 110.0),
    MasterCatalogItem(barcode: '6130001001028', name: 'حليب كانديا نصف دسم 1L', category: 'ألبان وأجبان', defaultPrice: 120.0, defaultCost: 105.0),
    MasterCatalogItem(barcode: '6130001001035', name: 'حليب كانديا سيليويت 1L', category: 'ألبان وأجبان', defaultPrice: 130.0, defaultCost: 115.0),
    MasterCatalogItem(barcode: '6130001001042', name: 'حليب كانديا فيفا 1L', category: 'ألبان وأجبان', defaultPrice: 135.0, defaultCost: 120.0),
    MasterCatalogItem(barcode: '6130001001059', name: 'حليب كانديا شوكولايت 20cl', category: 'ألبان وأجبان', defaultPrice: 50.0, defaultCost: 40.0),
    MasterCatalogItem(barcode: '6131112000012', name: 'ياغورت صومام ممزوج فراولة', category: 'ألبان وأجبان', defaultPrice: 30.0, defaultCost: 24.0),
    MasterCatalogItem(barcode: '6131112000029', name: 'ياغورت صومام طبيعي سادة', category: 'ألبان وأجبان', defaultPrice: 25.0, defaultCost: 20.0),
    MasterCatalogItem(barcode: '6131112000036', name: 'ياغورت صومام ديسير فانيلا كراميل', category: 'ألبان وأجبان', defaultPrice: 40.0, defaultCost: 32.0),
    MasterCatalogItem(barcode: '6131112000043', name: 'لبن صومام 1L', category: 'ألبان وأجبان', defaultPrice: 110.0, defaultCost: 95.0),
    MasterCatalogItem(barcode: '6131112000098', name: 'ياغورت دانون أصيل خوخ', category: 'ألبان وأجبان', defaultPrice: 35.0, defaultCost: 28.0),
    MasterCatalogItem(barcode: '6131112000104', name: 'ياغورت هودنا فواكه غابية', category: 'ألبان وأجبان', defaultPrice: 30.0, defaultCost: 24.0),
    MasterCatalogItem(barcode: '6131112000111', name: 'ياغورت صومام فورت بالشوكولا', category: 'ألبان وأجبان', defaultPrice: 35.0, defaultCost: 28.0),
    MasterCatalogItem(barcode: '6131112000050', name: 'جبن طري بربر 16 قطعة', category: 'ألبان وأجبان', defaultPrice: 260.0, defaultCost: 225.0),
    MasterCatalogItem(barcode: '6131112000067', name: 'جبن لافاش كيري 24 قطعة', category: 'ألبان وأجبان', defaultPrice: 480.0, defaultCost: 420.0),
    MasterCatalogItem(barcode: '6131112000128', name: 'جبن لافاش كيري 16 قطعة', category: 'ألبان وأجبان', defaultPrice: 340.0, defaultCost: 295.0),
    MasterCatalogItem(barcode: '6131112000135', name: 'جبن طاسيلي شيدار 250g', category: 'ألبان وأجبان', defaultPrice: 320.0, defaultCost: 275.0),
    MasterCatalogItem(barcode: '6131112000142', name: 'جبن شيزي مثلثات 16 قطعة', category: 'ألبان وأجبان', defaultPrice: 240.0, defaultCost: 205.0),
    MasterCatalogItem(barcode: '6131112000159', name: 'جبن فوندي فوندوس 24 قطعة', category: 'ألبان وأجبان', defaultPrice: 310.0, defaultCost: 265.0),
    MasterCatalogItem(barcode: '6131112000074', name: 'مارغرين لابيل سيفيتال 250g', category: 'ألبان وأجبان', defaultPrice: 115.0, defaultCost: 98.0),
    MasterCatalogItem(barcode: '6131112000081', name: 'مارغرين فلوريال 500g', category: 'ألبان وأجبان', defaultPrice: 230.0, defaultCost: 195.0),
    MasterCatalogItem(barcode: '6131112000166', name: 'مارغرين ماني 500g', category: 'ألبان وأجبان', defaultPrice: 220.0, defaultCost: 185.0),
    MasterCatalogItem(barcode: '6131112000173', name: 'مارغرين صول 500g', category: 'ألبان وأجبان', defaultPrice: 240.0, defaultCost: 205.0),
    MasterCatalogItem(barcode: '6131112000180', name: 'حليب بودرة لويا 500g', category: 'ألبان وأجبان', defaultPrice: 480.0, defaultCost: 420.0),
    MasterCatalogItem(barcode: '6131112000197', name: 'حليب بودرة نيدو 400g', category: 'ألبان وأجبان', defaultPrice: 560.0, defaultCost: 490.0),

    // 🥤 مشروبات ومياه معدنية
    MasterCatalogItem(barcode: '6132001001019', name: 'ماء معدني إفرو 1.5L', category: 'مشروبات ومياه', defaultPrice: 40.0, defaultCost: 30.0),
    MasterCatalogItem(barcode: '6132001001026', name: 'ماء معدني إفرو 0.5L', category: 'مشروبات ومياه', defaultPrice: 25.0, defaultCost: 18.0),
    MasterCatalogItem(barcode: '6132001001033', name: 'ماء معدني سيدي الكبير 1.5L', category: 'مشروبات ومياه', defaultPrice: 35.0, defaultCost: 26.0),
    MasterCatalogItem(barcode: '6132001001040', name: 'ماء معدني للا خديجة 1.5L', category: 'مشروبات ومياه', defaultPrice: 40.0, defaultCost: 30.0),
    MasterCatalogItem(barcode: '6132001001118', name: 'ماء معدني سيدي يعقوب 1.5L', category: 'مشروبات ومياه', defaultPrice: 35.0, defaultCost: 25.0),
    MasterCatalogItem(barcode: '6132001001125', name: 'ماء معدني غوريا 1.5L', category: 'مشروبات ومياه', defaultPrice: 35.0, defaultCost: 25.0),
    MasterCatalogItem(barcode: '6132001001132', name: 'ماء معدني صايدة 1.5L', category: 'مشروبات ومياه', defaultPrice: 40.0, defaultCost: 30.0),
    MasterCatalogItem(barcode: '6132001001057', name: 'مشروب حمود بوعلام سيليكتو 1L', category: 'مشروبات ومياه', defaultPrice: 110.0, defaultCost: 92.0),
    MasterCatalogItem(barcode: '6132001001064', name: 'مشروب حمود بوعلام سيليكتو 2L', category: 'مشروبات ومياه', defaultPrice: 180.0, defaultCost: 155.0),
    MasterCatalogItem(barcode: '6132001001071', name: 'مشروب حمود بوعلام ليمون بلانش 1L', category: 'مشروبات ومياه', defaultPrice: 110.0, defaultCost: 92.0),
    MasterCatalogItem(barcode: '6132001001149', name: 'مشروب حمود بوعلام كراش برتقال 1L', category: 'مشروبات ومياه', defaultPrice: 110.0, defaultCost: 92.0),
    MasterCatalogItem(barcode: '6132001001156', name: 'مشروب حمود سليم أناناس 1L', category: 'مشروبات ومياه', defaultPrice: 110.0, defaultCost: 92.0),
    MasterCatalogItem(barcode: '6132001001088', name: 'عصير رامي برتقال وجزر 1L', category: 'مشروبات ومياه', defaultPrice: 130.0, defaultCost: 108.0),
    MasterCatalogItem(barcode: '6132001001095', name: 'عصير رامي غلال مشكلة 1.25L', category: 'مشروبات ومياه', defaultPrice: 140.0, defaultCost: 118.0),
    MasterCatalogItem(barcode: '6132001001163', name: 'عصير رامي ليمون ونعناع 1L', category: 'مشروبات ومياه', defaultPrice: 130.0, defaultCost: 108.0),
    MasterCatalogItem(barcode: '6132001001101', name: 'عصير نغواس خوخ ومشمش 1L', category: 'مشروبات ومياه', defaultPrice: 135.0, defaultCost: 112.0),
    MasterCatalogItem(barcode: '6132001001170', name: 'عصير رويبة برتقال مانجو 1L', category: 'مشروبات ومياه', defaultPrice: 140.0, defaultCost: 118.0),
    MasterCatalogItem(barcode: '6132001001187', name: 'عصير رويبة كوكتيل 1L', category: 'مشروبات ومياه', defaultPrice: 140.0, defaultCost: 118.0),
    MasterCatalogItem(barcode: '6132001001194', name: 'عصير إفرو فواكه حمراء 1L', category: 'مشروبات ومياه', defaultPrice: 130.0, defaultCost: 108.0),
    MasterCatalogItem(barcode: '5449000000996', name: 'كوكاكولا زجاجة 1L', category: 'مشروبات ومياه', defaultPrice: 120.0, defaultCost: 100.0),
    MasterCatalogItem(barcode: '5449000000439', name: 'كوكاكولا كانيت 33cl', category: 'مشروبات ومياه', defaultPrice: 70.0, defaultCost: 55.0),
    MasterCatalogItem(barcode: '5449000014528', name: 'فانتا برتقال 1L', category: 'مشروبات ومياه', defaultPrice: 115.0, defaultCost: 95.0),
    MasterCatalogItem(barcode: '5449000027535', name: 'سبرايت 1L', category: 'مشروبات ومياه', defaultPrice: 115.0, defaultCost: 95.0),
    MasterCatalogItem(barcode: '6132001001200', name: 'مشروب طاقة توب غان 250ml', category: 'مشروبات ومياه', defaultPrice: 100.0, defaultCost: 80.0),

    // 🌾 بقالة ومواد غذائية أساسية
    MasterCatalogItem(barcode: '6133001001018', name: 'زيت المائدة إيليو 5L', category: 'مواد غذائية', defaultPrice: 650.0, defaultCost: 600.0),
    MasterCatalogItem(barcode: '6133001001025', name: 'زيت المائدة إيليو 1L', category: 'مواد غذائية', defaultPrice: 140.0, defaultCost: 125.0),
    MasterCatalogItem(barcode: '6133001001032', name: 'زيت المائدة عافية 5L', category: 'مواد غذائية', defaultPrice: 680.0, defaultCost: 620.0),
    MasterCatalogItem(barcode: '6133001001186', name: 'زيت المائدة سيم 5L', category: 'مواد غذائية', defaultPrice: 640.0, defaultCost: 590.0),
    MasterCatalogItem(barcode: '6133001001049', name: 'سكر أبيض سيفيتال 1kg', category: 'مواد غذائية', defaultPrice: 95.0, defaultCost: 85.0),
    MasterCatalogItem(barcode: '6133001001193', name: 'سكر رقيق سكرابي 1kg', category: 'مواد غذائية', defaultPrice: 95.0, defaultCost: 85.0),
    MasterCatalogItem(barcode: '6133001001056', name: 'فرينة فاخرة سفينة 1kg T45', category: 'مواد غذائية', defaultPrice: 50.0, defaultCost: 42.0),
    MasterCatalogItem(barcode: '6133001001063', name: 'فرينة سفينة 5kg', category: 'مواد غذائية', defaultPrice: 240.0, defaultCost: 210.0),
    MasterCatalogItem(barcode: '6133001001209', name: 'فرينة ماما 1kg', category: 'مواد غذائية', defaultPrice: 50.0, defaultCost: 42.0),
    MasterCatalogItem(barcode: '6133001001070', name: 'سميد سيم متوسط 1kg', category: 'مواد غذائية', defaultPrice: 95.0, defaultCost: 82.0),
    MasterCatalogItem(barcode: '6133001001087', name: 'سميد ماما ممتاز 1kg', category: 'مواد غذائية', defaultPrice: 90.0, defaultCost: 78.0),
    MasterCatalogItem(barcode: '6133001001216', name: 'سميد فاخر عمور 1kg', category: 'مواد غذائية', defaultPrice: 95.0, defaultCost: 82.0),
    MasterCatalogItem(barcode: '6133001001223', name: 'كسكسي سيم متوسط 1kg', category: 'مواد غذائية', defaultPrice: 140.0, defaultCost: 120.0),
    MasterCatalogItem(barcode: '6133001001230', name: 'كسكسي ماما رقيق 1kg', category: 'مواد غذائية', defaultPrice: 135.0, defaultCost: 115.0),
    MasterCatalogItem(barcode: '6133001001094', name: 'عجائن سيم سباغيتي 500g', category: 'مواد غذائية', defaultPrice: 60.0, defaultCost: 48.0),
    MasterCatalogItem(barcode: '6133001001100', name: 'عجائن ماما مكرونة 500g', category: 'مواد غذائية', defaultPrice: 55.0, defaultCost: 45.0),
    MasterCatalogItem(barcode: '6133001001117', name: 'عجائن فريكور شوربة فريك 500g', category: 'مواد غذائية', defaultPrice: 65.0, defaultCost: 52.0),
    MasterCatalogItem(barcode: '6133001001247', name: 'عجائن إكسترا ريشة 500g', category: 'مواد غذائية', defaultPrice: 60.0, defaultCost: 48.0),
    MasterCatalogItem(barcode: '6133001001254', name: 'أرز أبيض سفينة بسمتي 1kg', category: 'مواد غذائية', defaultPrice: 280.0, defaultCost: 240.0),
    MasterCatalogItem(barcode: '6133001001261', name: 'أرز أبيض مفور سيم 1kg', category: 'مواد غذائية', defaultPrice: 160.0, defaultCost: 135.0),
    MasterCatalogItem(barcode: '6133001001278', name: 'ملح طعام بحري سيمو 1kg', category: 'مواد غذائية', defaultPrice: 35.0, defaultCost: 25.0),
    MasterCatalogItem(barcode: '6133001001285', name: 'خل أبيض المائدة 1L', category: 'مواد غذائية', defaultPrice: 60.0, defaultCost: 45.0),

    // 🥫 معلبات وتونة وصلصات
    MasterCatalogItem(barcode: '6133001001124', name: 'طماطم مصبرة عمور 800g', category: 'معلبات وتونة', defaultPrice: 240.0, defaultCost: 205.0),
    MasterCatalogItem(barcode: '6133001001131', name: 'طماطم مصبرة كاب 400g', category: 'معلبات وتونة', defaultPrice: 130.0, defaultCost: 110.0),
    MasterCatalogItem(barcode: '6133001001292', name: 'طماطم مصبرة بستان 800g', category: 'معلبات وتونة', defaultPrice: 220.0, defaultCost: 190.0),
    MasterCatalogItem(barcode: '6133001001308', name: 'طماطم مصبرة إيزيدور 800g', category: 'معلبات وتونة', defaultPrice: 230.0, defaultCost: 195.0),
    MasterCatalogItem(barcode: '6133001001148', name: 'تونة بالطماطم إيزابيل 3x80g', category: 'معلبات وتونة', defaultPrice: 380.0, defaultCost: 320.0),
    MasterCatalogItem(barcode: '6133001001155', name: 'تونة بالزيت ماريانو 160g', category: 'معلبات وتونة', defaultPrice: 220.0, defaultCost: 185.0),
    MasterCatalogItem(barcode: '6133001001315', name: 'تونة بالزيت قندوز 160g', category: 'معلبات وتونة', defaultPrice: 210.0, defaultCost: 175.0),
    MasterCatalogItem(barcode: '6133001001322', name: 'تونة بالطماطم المحيط 3 قطع', category: 'معلبات وتونة', defaultPrice: 320.0, defaultCost: 270.0),
    MasterCatalogItem(barcode: '6133001001162', name: 'مايونيز ليسيور 250g', category: 'معلبات وتونة', defaultPrice: 180.0, defaultCost: 150.0),
    MasterCatalogItem(barcode: '6133001001339', name: 'مايونيز ريغال 500g', category: 'معلبات وتونة', defaultPrice: 260.0, defaultCost: 220.0),
    MasterCatalogItem(barcode: '6133001001346', name: 'كاتشب ليسيور 350g', category: 'معلبات وتونة', defaultPrice: 190.0, defaultCost: 160.0),
    MasterCatalogItem(barcode: '6133001001179', name: 'هريسة حارة الصقر 140g', category: 'معلبات وتونة', defaultPrice: 70.0, defaultCost: 55.0),
    MasterCatalogItem(barcode: '6133001001353', name: 'هريسة تونسية نابلية 380g', category: 'معلبات وتونة', defaultPrice: 180.0, defaultCost: 150.0),
    MasterCatalogItem(barcode: '6133001001360', name: 'حمص حب مصبر كاب 800g', category: 'معلبات وتونة', defaultPrice: 160.0, defaultCost: 130.0),
    MasterCatalogItem(barcode: '6133001001377', name: 'ذرة حلوة كاب 340g', category: 'معلبات وتونة', defaultPrice: 170.0, defaultCost: 140.0),

    // ☕ قهوة، شاي وكاكاو
    MasterCatalogItem(barcode: '6134001001017', name: 'قهوة مطحونة فاميكو 250g', category: 'قهوة وشاي', defaultPrice: 320.0, defaultCost: 280.0),
    MasterCatalogItem(barcode: '6134001001024', name: 'قهوة بن معطر ممتاز 250g', category: 'قهوة وشاي', defaultPrice: 350.0, defaultCost: 300.0),
    MasterCatalogItem(barcode: '6134001001109', name: 'قهوة أروما 250g', category: 'قهوة وشاي', defaultPrice: 330.0, defaultCost: 285.0),
    MasterCatalogItem(barcode: '6134001001116', name: 'قهوة بيلوز مطحونة 250g', category: 'قهوة وشاي', defaultPrice: 300.0, defaultCost: 260.0),
    MasterCatalogItem(barcode: '6134001001123', name: 'قهوة سريعة الذوبان نيسكافيه 100g', category: 'قهوة وشاي', defaultPrice: 580.0, defaultCost: 510.0),
    MasterCatalogItem(barcode: '6134001001031', name: 'شاي أخضر المنيعة 250g', category: 'قهوة وشاي', defaultPrice: 220.0, defaultCost: 180.0),
    MasterCatalogItem(barcode: '6134001001130', name: 'شاي أخضر القافلة 250g', category: 'قهوة وشاي', defaultPrice: 200.0, defaultCost: 165.0),
    MasterCatalogItem(barcode: '6134001001147', name: 'شاي أخضر تكسانة 250g', category: 'قهوة وشاي', defaultPrice: 230.0, defaultCost: 190.0),
    MasterCatalogItem(barcode: '6134001001048', name: 'شاي لبتون أصفر 25 كيس', category: 'قهوة وشاي', defaultPrice: 210.0, defaultCost: 175.0),
    MasterCatalogItem(barcode: '6134001001154', name: 'بودرة كاكاو كاندي باربي 250g', category: 'قهوة وشاي', defaultPrice: 240.0, defaultCost: 200.0),

    // 🍪 حلويات، بسكويت ومقرمشات
    MasterCatalogItem(barcode: '6134001001055', name: 'بسكويت بيمو غوفرات فانيلا', category: 'حلويات وبسكويت', defaultPrice: 40.0, defaultCost: 30.0),
    MasterCatalogItem(barcode: '6134001001062', name: 'بسكويت بيمو كوكيز شوكولا', category: 'حلويات وبسكويت', defaultPrice: 60.0, defaultCost: 48.0),
    MasterCatalogItem(barcode: '6134001001079', name: 'بسكويت بالماري توب كاكاو', category: 'حلويات وبسكويت', defaultPrice: 35.0, defaultCost: 26.0),
    MasterCatalogItem(barcode: '6134001001161', name: 'بسكويت كابريس ميني كيك', category: 'حلويات وبسكويت', defaultPrice: 45.0, defaultCost: 34.0),
    MasterCatalogItem(barcode: '6134001001178', name: 'بسكويت ماكسون محشو شوكولا', category: 'حلويات وبسكويت', defaultPrice: 50.0, defaultCost: 38.0),
    MasterCatalogItem(barcode: '6134001001185', name: 'شيبس مهدي بالجبن عائلي', category: 'حلويات وبسكويت', defaultPrice: 80.0, defaultCost: 65.0),
    MasterCatalogItem(barcode: '6134001001192', name: 'شيبس بيكنيك بابريكا 50g', category: 'حلويات وبسكويت', defaultPrice: 40.0, defaultCost: 30.0),
    MasterCatalogItem(barcode: '6134001001086', name: 'شوكولاتة الطلاء ماكسون 350g', category: 'حلويات وبسكويت', defaultPrice: 280.0, defaultCost: 235.0),
    MasterCatalogItem(barcode: '6134001001093', name: 'شوكولاتة الطلاء إلبيريا 400g', category: 'حلويات وبسكويت', defaultPrice: 320.0, defaultCost: 270.0),
    MasterCatalogItem(barcode: '6134001001208', name: 'شوكولاتة الطلاء نوتيلا 400g', category: 'حلويات وبسكويت', defaultPrice: 750.0, defaultCost: 660.0),
    MasterCatalogItem(barcode: '6134001001215', name: 'حلوى طحينية شامية غزال 250g', category: 'حلويات وبسكويت', defaultPrice: 170.0, defaultCost: 140.0),
    MasterCatalogItem(barcode: '6134001001222', name: 'مربى المشمش عمور 450g', category: 'حلويات وبسكويت', defaultPrice: 210.0, defaultCost: 175.0),
    MasterCatalogItem(barcode: '6134001001239', name: 'مربى الفراولة بستان 450g', category: 'حلويات وبسكويت', defaultPrice: 220.0, defaultCost: 180.0),

    // 🧼 تنظيف ونظافة منزلية
    MasterCatalogItem(barcode: '6135001001016', name: 'مسحوق غسيل إيزيس أوتوماتيك 3kg', category: 'تنظيف ونظافة', defaultPrice: 620.0, defaultCost: 530.0),
    MasterCatalogItem(barcode: '6135001001023', name: 'مسحوق غسيل أومو يدوي 500g', category: 'تنظيف ونظافة', defaultPrice: 140.0, defaultCost: 118.0),
    MasterCatalogItem(barcode: '6135001001092', name: 'مسحوق غسيل أريال أوتوماتيك 3kg', category: 'تنظيف ونظافة', defaultPrice: 850.0, defaultCost: 740.0),
    MasterCatalogItem(barcode: '6135001001108', name: 'مسحوق غسيل تيد يدوي 400g', category: 'تنظيف ونظافة', defaultPrice: 120.0, defaultCost: 100.0),
    MasterCatalogItem(barcode: '6135001001030', name: 'سائل غسيل الأواني بريل 1L', category: 'تنظيف ونظافة', defaultPrice: 220.0, defaultCost: 185.0),
    MasterCatalogItem(barcode: '6135001001047', name: 'سائل غسيل الأواني إيزيس 1.25L', category: 'تنظيف ونظافة', defaultPrice: 190.0, defaultCost: 160.0),
    MasterCatalogItem(barcode: '6135001001115', name: 'سائل غسيل الأواني ماكسي 1L', category: 'تنظيف ونظافة', defaultPrice: 160.0, defaultCost: 130.0),
    MasterCatalogItem(barcode: '6135001001054', name: 'ماء جافيل برافو 1L', category: 'تنظيف ونظافة', defaultPrice: 60.0, defaultCost: 45.0),
    MasterCatalogItem(barcode: '6135001001122', name: 'ماء جافيل لاك روا 1L', category: 'تنظيف ونظافة', defaultPrice: 70.0, defaultCost: 55.0),
    MasterCatalogItem(barcode: '6135001001139', name: 'معطر ومنظف الأرضيات لافاند 1L', category: 'تنظيف ونظافة', defaultPrice: 170.0, defaultCost: 140.0),
    MasterCatalogItem(barcode: '6135001001061', name: 'معجون أسنان سيجنال مكافحة التسوس 75ml', category: 'تنظيف ونظافة', defaultPrice: 150.0, defaultCost: 120.0),
    MasterCatalogItem(barcode: '6135001001146', name: 'معجون أسنان كولجيت توتال 100ml', category: 'تنظيف ونظافة', defaultPrice: 230.0, defaultCost: 190.0),
    MasterCatalogItem(barcode: '6135001001078', name: 'صابون دوف مرطب 100g', category: 'تنظيف ونظافة', defaultPrice: 130.0, defaultCost: 105.0),
    MasterCatalogItem(barcode: '6135001001153', name: 'صابون بالدوليف زيت الزيتون 90g', category: 'تنظيف ونظافة', defaultPrice: 85.0, defaultCost: 68.0),
    MasterCatalogItem(barcode: '6135001001160', name: 'صابون مرسيليا مارساك 200g', category: 'تنظيف ونظافة', defaultPrice: 95.0, defaultCost: 75.0),
    MasterCatalogItem(barcode: '6135001001085', name: 'شامبو ألترا دو بالزيتون 400ml', category: 'تنظيف ونظافة', defaultPrice: 380.0, defaultCost: 320.0),
    MasterCatalogItem(barcode: '6135001001177', name: 'شامبو هيد آند شولدرز كلاسيك 400ml', category: 'تنظيف ونظافة', defaultPrice: 460.0, defaultCost: 390.0),
    MasterCatalogItem(barcode: '6135001001184', name: 'حفاضات أطفال بيبي لوك مقاس 4 (40 حبة)', category: 'تنظيف ونظافة', defaultPrice: 950.0, defaultCost: 830.0),
    MasterCatalogItem(barcode: '6135001001191', name: 'حفاضات أطفال مولفيكس مقاس 3 (44 حبة)', category: 'تنظيف ونظافة', defaultPrice: 1100.0, defaultCost: 970.0),
    MasterCatalogItem(barcode: '6135001001207', name: 'ورق صحي كلينيكس 4 لفات', category: 'تنظيف ونظافة', defaultPrice: 180.0, defaultCost: 145.0),
  ];

  static MasterCatalogItem? lookup(String barcode) {
    try {
      return items.firstWhere((element) => element.barcode == barcode.trim());
    } catch (_) {
      return null;
    }
  }

  static List<MasterCatalogItem> search(String query, {String category = 'الكل'}) {
    final q = query.trim().toLowerCase();
    return items.where((element) {
      final matchesCategory = category == 'الكل' || element.category == category;
      if (!matchesCategory) return false;
      if (q.isEmpty) return true;
      return element.name.toLowerCase().contains(q) ||
          element.barcode.contains(q) ||
          element.category.toLowerCase().contains(q);
    }).toList();
  }
}
