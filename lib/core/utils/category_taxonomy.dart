class CategoryDomain {
  final String id;
  final String titleAr;
  final String titleFr;
  final String titleEn;
  final String icon;
  final List<CategorySub> subcategories;

  const CategoryDomain({
    required this.id,
    required this.titleAr,
    required this.titleFr,
    required this.titleEn,
    required this.icon,
    required this.subcategories,
  });

  List<CategorySub> get subCategories => subcategories;
}

class CategorySub {
  final String id;
  final String domainId;
  final String titleAr;
  final String titleFr;
  final String titleEn;
  final String icon;
  final List<String> tags;

  const CategorySub({
    required this.id,
    required this.domainId,
    required this.titleAr,
    required this.titleFr,
    required this.titleEn,
    required this.icon,
    this.tags = const [],
  });
}

class CategoryTaxonomy {
  static const List<CategoryDomain> domains = [
    // 1. المواد الغذائية والتموين
    CategoryDomain(
      id: 'food',
      titleAr: 'المواد الغذائية والتموين',
      titleFr: 'Alimentation & Épicerie',
      titleEn: 'Food & Groceries',
      icon: '🛒',
      subcategories: [
        CategorySub(
          id: 'beverages',
          domainId: 'food',
          titleAr: 'مشروبات ومياه وعصائر',
          titleFr: 'Boissons, Eaux & Jus',
          titleEn: 'Beverages & Juices',
          icon: '🥤',
          tags: ['عصير', 'ماء', 'مياه', 'مشروب', 'غازوز', 'كوكا', 'بيبسي', 'حميد', 'إفري', 'روايبة', 'رامي', 'سيلست', 'نقاوس', 'jus', 'eau', 'soda'],
        ),
        CategorySub(
          id: 'dairy',
          domainId: 'food',
          titleAr: 'حليب ومشتقاته وألبان',
          titleFr: 'Produits Laitiers & Fromages',
          titleEn: 'Dairy & Cheese',
          icon: '🥛',
          tags: ['حليب', 'ياغورت', 'لبن', 'رايب', 'جبن', 'فرماج', 'زبادي', 'زبدة', 'كانديا', 'سومام', 'دانون', 'برير', 'lait', 'fromage', 'yaourt'],
        ),
        CategorySub(
          id: 'canned_oils',
          domainId: 'food',
          titleAr: 'معلبات وزيوت وتوابل',
          titleFr: 'Conserves, Huiles & Épices',
          titleEn: 'Canned Goods, Oils & Spices',
          icon: '🥫',
          tags: ['تونة', 'طماطم', 'زيت', 'سردين', 'خل', 'مايونيز', 'هريسة', 'توابل', 'بهارات', 'صلصة', 'عافية', 'إيليو', 'thit', 'huile', 'tomate'],
        ),
        CategorySub(
          id: 'bakery_pasta',
          domainId: 'food',
          titleAr: 'مخبوزات وعجائن وحبوب',
          titleFr: 'Boulangerie & Pâtes',
          titleEn: 'Bakery & Pasta',
          icon: '🥖',
          tags: ['خبز', 'كسكسي', 'مقرونة', 'سباغيتي', 'فرينة', 'سميد', 'عجين', 'بريوش', 'سيم', 'ماما', 'عمر بن عمر', 'pain', 'couscous', 'pates'],
        ),
        CategorySub(
          id: 'vrac_scale',
          domainId: 'food',
          titleAr: 'بضاعة الميزان وبقوليات ⚖️',
          titleFr: 'Vrac & Légumineuses',
          titleEn: 'Scale & Bulk Goods',
          icon: '⚖️',
          tags: ['عدس', 'حمص', 'فريك', 'أرز', 'لوبيا', 'فاصوليا', 'ميزان', 'كغ', 'وزن', 'vrac', 'lentille', 'pois chiche'],
        ),
        CategorySub(
          id: 'coffee_tea_sugar',
          domainId: 'food',
          titleAr: 'قهوة وشاي وسكر ومحليات',
          titleFr: 'Café, Thé & Sucre',
          titleEn: 'Coffee, Tea & Sugar',
          icon: '☕',
          tags: ['قهوة', 'بن', 'شاي', 'تاي', 'سكر', 'نسكافيه', 'حليب بودرة', 'لحظة', 'فاميكو', 'بونال', 'cafe', 'the', 'sucre'],
        ),
      ],
    ),

    // 2. الحلويات والسكاكر والمقرمشات
    CategoryDomain(
      id: 'sweets',
      titleAr: 'حلويات وسكاكر ومقرمشات',
      titleFr: 'Confiserie & Biscuits',
      titleEn: 'Sweets & Snacks',
      icon: '🍫',
      subcategories: [
        CategorySub(
          id: 'chocolate_biscuits',
          domainId: 'sweets',
          titleAr: 'شوكولاتة وبسكويت وقوفريط',
          titleFr: 'Chocolats & Biscuits',
          titleEn: 'Chocolates & Biscuits',
          icon: '🍫',
          tags: ['شوكولا', 'بسكويت', 'قوفريط', 'ماكسون', 'بيمو', 'تيفينا', 'طاج', 'كوكيز', 'كوفريط', 'chocolat', 'biscuit', 'gaufrette'],
        ),
        CategorySub(
          id: 'candy_gum',
          domainId: 'sweets',
          titleAr: 'سكاكر وحلوى وعلكة',
          titleFr: 'Bonbons & Chewing-gum',
          titleEn: 'Candy & Chewing Gum',
          icon: '🍬',
          tags: ['حلوى', 'علكة', 'شيكليت', 'مصاصة', 'كابريس', 'مارشميلو', 'حبة حلوى', 'bonbon', 'chewing-gum', 'caprice'],
        ),
        CategorySub(
          id: 'chips_nuts',
          domainId: 'sweets',
          titleAr: 'مقرمشات ومكسرات وشبس',
          titleFr: 'Chips & Arachides',
          titleEn: 'Chips & Nuts',
          icon: '🍿',
          tags: ['شبس', 'شيبس', 'كاوكاو', 'فول سوداني', 'مكسرات', 'بذور', 'بوب كورن', 'شيبس ماها', 'chips', 'cacahuetes'],
        ),
      ],
    ),

    // 3. الأدوات المدرسية والمكتبية
    CategoryDomain(
      id: 'stationery',
      titleAr: 'أدوات مدرسية ومكتبية',
      titleFr: 'Fournitures Scolaires & Papeterie',
      titleEn: 'Stationery & School Supplies',
      icon: '📚',
      subcategories: [
        CategorySub(
          id: 'writing_tools',
          domainId: 'stationery',
          titleAr: 'أدوات الكتابة والرسم',
          titleFr: 'Instruments d\'écriture',
          titleEn: 'Writing Instruments',
          icon: '✏️',
          tags: ['قلم', 'بيك', 'سيالة', 'رصاص', 'ممحاة', 'براية', 'تلوين', 'لباد', 'ماركور', 'stylo', 'bic', 'crayon', 'gomme', 'feutre'],
        ),
        CategorySub(
          id: 'notebooks',
          domainId: 'stationery',
          titleAr: 'كراريس ودفاتر وسجلات',
          titleFr: 'Cahiers & Registres',
          titleEn: 'Notebooks & Registers',
          icon: '📓',
          tags: ['كراس', 'دفتر', 'سجل', 'كراس رسم', 'كشكول', '64 صفحة', '96 صفحة', '120 صفحة', '288 صفحة', 'cahier', 'registre', 'dessin'],
        ),
        CategorySub(
          id: 'paper_covers',
          domainId: 'stationery',
          titleAr: 'ورقيات وأغلفة ومجلدات',
          titleFr: 'Papiers & Protèges-cahiers',
          titleEn: 'Paper & Covers',
          icon: '📜',
          tags: ['ورق', 'أوراق', 'مزدوجة', 'رزمة', 'a4', 'غلاف', 'أغلفة', 'بلاستيك', 'ملف', 'مصنف', 'ramette', 'feuille', 'protege'],
        ),
        CategorySub(
          id: 'office_supplies',
          domainId: 'stationery',
          titleAr: 'لوازم مكتبية وهندسية',
          titleFr: 'Accessoires de Bureau',
          titleEn: 'Desk & Office Accessories',
          icon: '📐',
          tags: ['مسطرة', 'مقص', 'غراء', 'لصاق', 'سكوتش', 'بلانكو', 'مصلح', 'كوس', 'منقلة', 'دباسة', 'regle', 'colle', 'scotch', 'correcteur'],
        ),
      ],
    ),

    // 4. النظافة ومستحضرات التجميل
    CategoryDomain(
      id: 'hygiene',
      titleAr: 'نظافة وتجميل وعناية',
      titleFr: 'Hygiène & Entretien',
      titleEn: 'Hygiene & Cleaning',
      icon: '🧼',
      subcategories: [
        CategorySub(
          id: 'personal_care',
          domainId: 'hygiene',
          titleAr: 'عناية شخصية وشامبو وصابون',
          titleFr: 'Soins Personnels & Savons',
          titleEn: 'Personal Care & Soaps',
          icon: '🧴',
          tags: ['صابون', 'شامبو', 'معجون أسنان', 'عطر', 'مزيل عرق', 'مناديل ورقية', 'كوش', 'حفاضات', 'savon', 'shampoing', 'dentifrice'],
        ),
        CategorySub(
          id: 'home_cleaning',
          domainId: 'hygiene',
          titleAr: 'منظفات ومواد تطهير منزلية',
          titleFr: 'Produits d\'Entretien',
          titleEn: 'Cleaning Products',
          icon: '🧽',
          tags: ['جافيل', 'غسيل أواني', 'مسحوق غسيل', 'معطر أرضيات', 'إيزيس', 'أومو', 'أمير', 'منظف', 'javel', 'lessive', 'detergent'],
        ),
      ],
    ),

    // 5. التبغ ولوازم التدخين (معزول تماماً عن السلع العامة)
    CategoryDomain(
      id: 'tobacco',
      titleAr: 'تبغ وسجائر ولوازم تدخين',
      titleFr: 'Tabac & Accessoires',
      titleEn: 'Tobacco & Smoking',
      icon: '🚬',
      subcategories: [
        CategorySub(
          id: 'cigarettes',
          domainId: 'tobacco',
          titleAr: 'سجائر وطنية ومستوردة',
          titleFr: 'Cigarettes',
          titleEn: 'Cigarettes',
          icon: '🚬',
          tags: ['سجائر', 'ريم', 'نسيم', 'مارلبورو', 'مالبورو', 'غالواز', 'وينستون', 'روثمان', 'مارلبورو غولد', 'rym', 'marlboro', 'gauloises'],
        ),
        CategorySub(
          id: 'chewing_traditional',
          domainId: 'tobacco',
          titleAr: 'شمة وتبغ تقليدي',
          titleFr: 'Tabac à chiquer (Chemama)',
          titleEn: 'Chewing Tobacco',
          icon: '🌿',
          tags: ['شمة', 'صنافلي', 'تمباك', 'ماكلة', 'حربة', 'شمة هلال', 'chemma', 'tabac'],
        ),
        CategorySub(
          id: 'hookah_molasses',
          domainId: 'tobacco',
          titleAr: 'معسل ولوازم الشيشة',
          titleFr: 'Chicha & Tabamel',
          titleEn: 'Hookah & Molasses',
          icon: '💨',
          tags: ['معسل', 'شيشة', 'فحم', 'نرجيلة', 'تفاحتين', 'مزايا', 'فحم سريع', 'chicha', 'charbon'],
        ),
        CategorySub(
          id: 'lighters_papers',
          domainId: 'tobacco',
          titleAr: 'ولاعات وغاز وورق لف وفلاتر',
          titleFr: 'Briquets & Feuilles à rouler',
          titleEn: 'Lighters & Rolling Papers',
          icon: '🔥',
          tags: ['ولاعة', 'غاز ولاعات', 'ورق لف', 'فلاتر', 'ريزلا', 'أوسيبي', 'كليبر', 'briquet', 'feuilles a rouler', 'ocb', 'clipper'],
        ),
      ],
    ),

    // 6. خضر وفواكه ولحوم طازجة
    CategoryDomain(
      id: 'produce',
      titleAr: 'خضر وفواكه ولحوم طازجة',
      titleFr: 'Fruits, Légumes & Boucherie',
      titleEn: 'Produce & Fresh Meat',
      icon: '🍏',
      subcategories: [
        CategorySub(
          id: 'fruits_veg',
          domainId: 'produce',
          titleAr: 'خضر وفواكه طازجة',
          titleFr: 'Fruits & Légumes Frais',
          titleEn: 'Fresh Fruits & Veg',
          icon: '🍎',
          tags: ['تفاح', 'برتقال', 'موز', 'طماطم طازجة', 'بطاطا', 'بصل', 'جزر', 'فلفل', 'سلطة', 'خيار', 'fruits', 'legumes'],
        ),
        CategorySub(
          id: 'meat_poultry',
          domainId: 'produce',
          titleAr: 'لحوم ودواجن وبيض',
          titleFr: 'Viandes, Volailles & Œufs',
          titleEn: 'Meat, Poultry & Eggs',
          icon: '🥩',
          tags: ['لحم', 'دجاج', 'بيض', 'مرقاز', 'كفتة', 'viande', 'poulet', 'oeufs'],
        ),
      ],
    ),

    // 7. سلع الكشك والخدمات العامة
    CategoryDomain(
      id: 'general',
      titleAr: 'سلع الكشك والخدمات العامة',
      titleFr: 'Divers & Kiosque',
      titleEn: 'General & Kiosk Services',
      icon: '📦',
      subcategories: [
        CategorySub(
          id: 'kiosk_services',
          domainId: 'general',
          titleAr: 'خدمات وفليكسي وكروت شحن',
          titleFr: 'Recharges & Services',
          titleEn: 'Top-ups & Services',
          icon: '⚡',
          tags: ['فليكسي', 'كارت', 'تعبئة', 'موبيليس', 'جازي', 'أوريدو', 'recharge', 'flexy'],
        ),
        CategorySub(
          id: 'misc_general',
          domainId: 'general',
          titleAr: 'سلع عامة ومنوعة',
          titleFr: 'Articles Divers',
          titleEn: 'General Merchandise',
          icon: '📦',
          tags: ['عام', 'أخرى', 'شاحن', 'كابل', 'بطارية', 'ألعاب', 'divers', 'general'],
        ),
      ],
    ),

    // 8. ماكينة القهوة والشاي والمشروبات الساخنة (صنف معزول ومستقل)
    CategoryDomain(
      id: 'coffee_tea',
      titleAr: 'ماكينة القهوة والشاي',
      titleFr: 'Machine à Café & Thé',
      titleEn: 'Coffee & Tea Machine',
      icon: '☕',
      subcategories: [
        CategorySub(
          id: 'coffee_beans_ground',
          domainId: 'coffee_tea',
          titleAr: 'حبوب بن ومسحوق قهوة',
          titleFr: 'Café en grains & moulu',
          titleEn: 'Coffee Beans & Ground',
          icon: '☕',
          tags: ['بن', 'قهوة', 'اسبريسو', 'اكسبريسو', 'حبوب بن', 'قهوة مطحونة', 'لافيستا', 'فاميكو', 'بونال', 'cafe', 'espresso', 'grain', 'moulu', 'illy', 'lavazza'],
        ),
        CategorySub(
          id: 'tea_infusions',
          domainId: 'coffee_tea',
          titleAr: 'شاي وأعشاب وتجهيز',
          titleFr: 'Thé & Infusions',
          titleEn: 'Tea & Herbs',
          icon: '🍵',
          tags: ['شاي', 'شاي أخضر', 'شاي أحمر', 'نعناع', 'أتاي', 'بارود', 'the', 'infusion', 'menthe'],
        ),
        CategorySub(
          id: 'cups_machine_supplies',
          domainId: 'coffee_tea',
          titleAr: 'كؤوس ومستلزمات التقديم',
          titleFr: 'Gobelets & Consommables',
          titleEn: 'Cups & Serving Supplies',
          icon: '🥤',
          tags: ['كؤوس', 'كوب', 'كاس', 'خلط', 'ملاعق صغيرة', 'سكر ساشي', 'gobelet', 'palet'],
        ),
        CategorySub(
          id: 'prepared_hot_drinks',
          domainId: 'coffee_tea',
          titleAr: 'مشروبات ساخنة محضرة',
          titleFr: 'Boissons Chaudes Servies',
          titleEn: 'Prepared Hot Drinks',
          icon: '☕',
          tags: ['كأس قهوة', 'كاس قهوة', 'قهوة حليب', 'كابوتشينو', 'كأس شاي', 'كاس شاي', 'شاي بالنعناع', 'قهوة كبريس', 'espresso servi', 'cafe au lait'],
        ),
      ],
    ),
  ];

  /// Flat list of all subcategory names for legacy dropdown and fast selection
  static List<String> get allCategoryNames {
    final List<String> names = [];
    for (final d in domains) {
      for (final s in d.subcategories) {
        names.add(s.titleAr);
      }
    }
    return names;
  }

  /// All category domains
  static List<CategoryDomain> get allDomains => domains;

  /// Finds the parent domain for a given category name or product name
  static CategoryDomain? findDomain(String categoryOrProductName) {
    final clean = categoryOrProductName.trim().toLowerCase();
    for (final d in domains) {
      if (d.id == clean || d.titleAr.toLowerCase() == clean || d.titleFr.toLowerCase() == clean) {
        return d;
      }
      for (final s in d.subcategories) {
        if (s.id == clean || s.titleAr.toLowerCase() == clean || s.titleFr.toLowerCase() == clean) {
          return d;
        }
      }
    }
    return null;
  }

  /// Resolves the parent domain for a given category name or product name (with default fallback)
  static CategoryDomain resolveDomain(String categoryOrProductName) {
    return findDomain(categoryOrProductName) ?? domains.first;
  }

  /// Smartly detects the best subcategory for an item name based on tags
  static CategorySub smartDetect(String productName) {
    final clean = productName.trim().toLowerCase();
    if (clean.isEmpty) {
      return domains.first.subcategories.first;
    }

    int bestScore = 0;
    CategorySub? bestMatch;

    for (final d in domains) {
      for (final s in d.subcategories) {
        int score = 0;
        for (final tag in s.tags) {
          if (clean.contains(tag.toLowerCase())) {
            score += tag.length; // weight by tag specificity
          }
        }
        if (score > bestScore) {
          bestScore = score;
          bestMatch = s;
        }
      }
    }

    return bestMatch ?? domains.first.subcategories.first;
  }

  /// Returns the corresponding icon for any category string
  static String getIconForCategory(String categoryName) {
    final clean = categoryName.trim().toLowerCase();
    for (final d in domains) {
      if (clean.contains(d.titleAr.toLowerCase()) || clean == d.id) return d.icon;
      for (final s in d.subcategories) {
        if (clean.contains(s.titleAr.toLowerCase()) || clean == s.id) return s.icon;
      }
    }
    if (clean.contains('مدرس') || clean.contains('مكتب') || clean.contains('كراس') || clean.contains('قلم')) return '📚';
    if (clean.contains('تبغ') || clean.contains('سجائر')) return '🚬';
    if (clean.contains('شمة')) return '🌿';
    if (clean.contains('حليب') || clean.contains('ألبان')) return '🥛';
    if (clean.contains('مشروب') || clean.contains('عصير')) return '🥤';
    if (clean.contains('حلو') || clean.contains('شوكولا')) return '🍫';
    if (clean.contains('ميزان')) return '⚖️';
    if (clean.contains('تنظيف')) return '🧼';
    if (clean.contains('قهوة') || clean.contains('شاي') || clean.contains('كافيتيريا') || clean.contains('اسبريسو')) return '☕';
    return '📦';
  }
}
