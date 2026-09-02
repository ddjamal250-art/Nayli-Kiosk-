import os
import sys
from pptx import Presentation
from pptx.util import Inches, Pt
from pptx.enum.text import PP_ALIGN
from pptx.dml.color import RGBColor
from pptx.enum.shapes import MSO_SHAPE

# 1. إعداد العرض التقديمي بحجم الشاشة العريضة 16:9
prs = Presentation()
prs.slide_width = Inches(13.333)
prs.slide_height = Inches(7.5)

# لوحة الألوان الفاخرة (Dark Fintech Theme)
BG_COLOR = RGBColor(8, 11, 18)          # أسود ملكي
CARD_BG = RGBColor(16, 24, 38)          # أزرق كحلي داكن للبطاقات
CARD_BORDER = RGBColor(30, 41, 59)      # حدود البطاقات
CYAN = RGBColor(0, 242, 254)            # سيان نيون
CYAN_DARK = RGBColor(0, 160, 200)
EMERALD = RGBColor(16, 185, 129)        # أخضر زمردي
GOLD = RGBColor(245, 158, 11)           # ذهبي ملكي
WHITE = RGBColor(248, 250, 252)         # أبيض ناصع
MUTED = RGBColor(148, 163, 184)         # رمادي فاتح للنصوص الثانوية

# مسارات الصور ثلاثية الأبعاد المولدة
BRAIN_DIR = r"C:\Users\Admin\.gemini\antigravity\brain\0198678e-e3da-4b47-bce1-1fab48603782"
IMG_POS = os.path.join(BRAIN_DIR, "pos_terminal_3d_1788299586743.jpg")
IMG_MESH = os.path.join(BRAIN_DIR, "network_mesh_3d_1788299606349.jpg")
IMG_INVEST = os.path.join(BRAIN_DIR, "growth_invest_3d_1788299650916.jpg")

blank_layout = prs.slide_layouts[6] # شريحة فارغة

def set_slide_background(slide):
    # رسم مستطيل خلفية يغطي الشريحة بالكامل بلون داكن فخم
    bg = slide.shapes.add_shape(MSO_SHAPE.RECTANGLE, 0, 0, Inches(13.333), Inches(7.5))
    bg.fill.solid()
    bg.fill.fore_color.rgb = BG_COLOR
    bg.line.fill.background()
    return bg

def add_header(slide, title_text, category_text, badge_color=CYAN):
    # شريط علوي أنيق
    cat_box = slide.shapes.add_textbox(Inches(0.8), Inches(0.4), Inches(11.7), Inches(0.4))
    tf_cat = cat_box.text_frame
    tf_cat.word_wrap = True
    p_cat = tf_cat.paragraphs[0]
    p_cat.text = category_text.upper()
    p_cat.font.name = "Segoe UI"
    p_cat.font.size = Pt(11)
    p_cat.font.bold = True
    p_cat.font.color.rgb = badge_color
    p_cat.alignment = PP_ALIGN.RIGHT

    title_box = slide.shapes.add_textbox(Inches(0.8), Inches(0.7), Inches(11.7), Inches(0.8))
    tf_title = title_box.text_frame
    tf_title.word_wrap = True
    p_title = tf_title.paragraphs[0]
    p_title.text = title_text
    p_title.font.name = "Tajawal"
    p_title.font.size = Pt(26)
    p_title.font.bold = True
    p_title.font.color.rgb = WHITE
    p_title.alignment = PP_ALIGN.RIGHT

def create_card(slide, left, top, width, height, bg_color=CARD_BG, border_color=CARD_BORDER):
    card = slide.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, left, top, width, height)
    card.fill.solid()
    card.fill.fore_color.rgb = bg_color
    card.line.color.rgb = border_color
    card.line.width = Pt(1.2)
    return card

# ==============================================================================
# الشريحة 1: الغلاف التنفيذي (The Vision & Hero Slide)
# ==============================================================================
slide1 = prs.slides.add_slide(blank_layout)
set_slide_background(slide1)

# إضافة الصورة ثلاثية الأبعاد للـ POS
if os.path.exists(IMG_POS):
    slide1.shapes.add_picture(IMG_POS, Inches(0.6), Inches(1.1), Inches(6.2), Inches(5.4))

# المحتوى النصي الأيمن
content_box1 = slide1.shapes.add_textbox(Inches(6.8), Inches(1.1), Inches(5.8), Inches(5.5))
tf1 = content_box1.text_frame
tf1.word_wrap = True

p1 = tf1.paragraphs[0]
p1.text = "⚡ جولة استثمارية - 10M$ PITCH DECK"
p1.font.name = "Segoe UI"
p1.font.size = Pt(12)
p1.font.bold = True
p1.font.color.rgb = GOLD
p1.alignment = PP_ALIGN.RIGHT

p2 = tf1.add_paragraph()
p2.text = "نايلي ماركت | NAYLI MARKET"
p2.font.name = "Tajawal"
p2.font.size = Pt(36)
p2.font.bold = True
p2.font.color.rgb = CYAN
p2.alignment = PP_ALIGN.RIGHT

p3 = tf1.add_paragraph()
p3.text = "الجيل القادم لأنظمة تشغيل تجارة التجزئة المستقلة (Autonomous Retail OS)"
p3.font.name = "Cairo"
p3.font.size = Pt(18)
p3.font.bold = True
p3.font.color.rgb = WHITE
p3.alignment = PP_ALIGN.RIGHT

p4 = tf1.add_paragraph()
p4.text = "\nإعادة هندسة تجارة التجزئة في الشرق الأوسط وشمال إفريقيا عبر بنية هجينة (Local-First) تعمل بدون انقطاع، وقاعدة بيانات مسبقة بـ 100,000 منتج، مع ذكاء اصطناعي لإدارة المخزون والديون."
p4.font.name = "Segoe UI"
p4.font.size = Pt(14)
p4.font.color.rgb = MUTED
p4.alignment = PP_ALIGN.RIGHT

# 3 بطاقات مزايا سريعة بالأسفل
highlights = [
    ("سرعة خارقة", "استجابة مسح < 12ms", CYAN),
    ("P2P Mesh", "تزامن بدون إنترنت", EMERALD),
    ("100K كنز", "انطلاق في 60 ثانية", GOLD)
]
for i, (h_title, h_sub, h_col) in enumerate(highlights):
    card = create_card(slide1, Inches(6.8 + i * 1.95), Inches(5.4), Inches(1.85), Inches(1.2))
    tb = slide1.shapes.add_textbox(Inches(6.8 + i * 1.95), Inches(5.45), Inches(1.85), Inches(1.1))
    tf = tb.text_frame
    tf.word_wrap = True
    p = tf.paragraphs[0]
    p.text = h_title
    p.font.name = "Tajawal"
    p.font.size = Pt(13)
    p.font.bold = True
    p.font.color.rgb = h_col
    p.alignment = PP_ALIGN.CENTER
    p_s = tf.add_paragraph()
    p_s.text = h_sub
    p_s.font.name = "Segoe UI"
    p_s.font.size = Pt(10)
    p_s.font.color.rgb = MUTED
    p_s.alignment = PP_ALIGN.CENTER

# ==============================================================================
# الشريحة 2: الأزمة الكبرى وفرصة السوق (The $45B Market Problem)
# ==============================================================================
slide2 = prs.slides.add_slide(blank_layout)
set_slide_background(slide2)
add_header(slide2, "أزمة تجار التجزئة: نزيف أرباح الكراس الورقي وعقم الأنظمة السحابية", "THE $45 BILLION MARKET VOID • فجوة السوق", GOLD)

# 4 إحصائيات علوية
stats2 = [
    ("45B$", "حجم سوق التجزئة غير المرقمَن", CYAN),
    ("18%", "نزيف الأرباح السنوي للتاجر", GOLD),
    ("85%", "متاجر لا زالت مقيدة بالدفاتر", MUTED),
    ("0$", "تكلفة الهدر مع نايلي ماركت", EMERALD)
]
for i, (val, lbl, col) in enumerate(stats2):
    create_card(slide2, Inches(0.8 + i * 2.95), Inches(1.6), Inches(2.85), Inches(1.2))
    tb = slide2.shapes.add_textbox(Inches(0.8 + i * 2.95), Inches(1.65), Inches(2.85), Inches(1.1))
    tf = tb.text_frame
    p_v = tf.paragraphs[0]
    p_v.text = val
    p_v.font.name = "Tajawal"
    p_v.font.size = Pt(28)
    p_v.font.bold = True
    p_v.font.color.rgb = col
    p_v.alignment = PP_ALIGN.CENTER
    p_l = tf.add_paragraph()
    p_l.text = lbl
    p_l.font.name = "Segoe UI"
    p_l.font.size = Pt(11)
    p_l.font.color.rgb = MUTED
    p_l.alignment = PP_ALIGN.CENTER

# مقارنة بين القديم والحديث
# بطاقة القديم
create_card(slide2, Inches(0.8), Inches(3.1), Inches(5.7), Inches(3.8), bg_color=RGBColor(24, 16, 20), border_color=RGBColor(120, 30, 40))
tb_old = slide2.shapes.add_textbox(Inches(1.0), Inches(3.2), Inches(5.3), Inches(3.6))
tf_old = tb_old.text_frame
tf_old.word_wrap = True
p = tf_old.paragraphs[0]
p.text = "❌ أنظمة الكراس والبرامج السحابية العتيقة"
p.font.name = "Tajawal"
p.font.size = Pt(18)
p.font.bold = True
p.font.color.rgb = RGBColor(248, 113, 113)
p.alignment = PP_ALIGN.RIGHT

old_points = [
    "• انقطاع الإنترنت: شلل كامل للمحل وتوقف البيع وخروج الزبائن غاضبين.",
    "• الكريدي الورقي: نسيان وضياع 15% إلى 20% من مستحقات الديون دون استرجاع.",
    "• الإدخال اليدوي: 3 إلى 6 أشهر لإدخال آلاف السلع بالاسم والباركود.",
    "• سرقة المخزون: انعدام الرقابة الفورية على الصندوق وتلاعب العمال."
]
for pt in old_points:
    p = tf_old.add_paragraph()
    p.text = pt
    p.font.name = "Segoe UI"
    p.font.size = Pt(13)
    p.font.color.rgb = MUTED
    p.alignment = PP_ALIGN.RIGHT

# بطاقة نايلي ماركت
create_card(slide2, Inches(6.8), Inches(3.1), Inches(5.7), Inches(3.8), bg_color=RGBColor(12, 28, 28), border_color=RGBColor(16, 185, 129))
tb_new = slide2.shapes.add_textbox(Inches(7.0), Inches(3.2), Inches(5.3), Inches(3.6))
tf_new = tb_new.text_frame
tf_new.word_wrap = True
p = tf_new.paragraphs[0]
p.text = "✔️ منظومة Nayli Market / Lumina POS"
p.font.name = "Tajawal"
p.font.size = Pt(18)
p.font.bold = True
p.font.color.rgb = EMERALD
p.alignment = PP_ALIGN.RIGHT

new_points = [
    "• بنية Local-First: يعمل 100% بدون إنترنت مع سرعة فائقة أقل من 12ms.",
    "• ذكاء إدارة الكريدي: سقف ائتماني لكل زبون وتنبيهات ومشاركة واتساب.",
    "• 100,000 سلعة مجهزة: مسح فوري للباركود والبدء في البيع خلال دقيقة واحدة.",
    "• انضباط الصندوق والورديات: حساب الأرباح الصافية ورأس المال بدقة السنتيم."
]
for pt in new_points:
    p = tf_new.add_paragraph()
    p.text = pt
    p.font.name = "Segoe UI"
    p.font.size = Pt(13)
    p.font.color.rgb = WHITE
    p.alignment = PP_ALIGN.RIGHT

# ==============================================================================
# الشريحة 3: المعمارية التقنية الخارقة (Local-First Mesh Architecture)
# ==============================================================================
slide3 = prs.slides.add_slide(blank_layout)
set_slide_background(slide3)
add_header(slide3, "المعمارية التقنية: بنية هجينة وشبكة P2P محلية لا تتوقف أبداً", "DEEP TECH & ARCHITECTURE • المعمارية الخارقة", CYAN)

# وضع الصورة ثلاثية الأبعاد للمتجر والشبكة
if os.path.exists(IMG_MESH):
    slide3.shapes.add_picture(IMG_MESH, Inches(0.8), Inches(1.6), Inches(5.8), Inches(5.3))

# بطاقات التقنية على اليمين
tech_cards = [
    ("P2P Local Sync Server", "خادم مزامنة محلي مدمج في الكاشير يربط هواتف العمال في الممرات وشاشات الزبائن Kiosk والميزان دون حاجة لراوتر أو إنترنت خارجي.", CYAN),
    ("محرك Hive NoSQL فائق الاستجابة", "قراءة وكتابة السجلات في أجزاء من الميلي ثانية (Sub-12ms). صمود تام أمام انقطاع الكهرباء مع حفظ فوري لكل حركة بيع.", EMERALD),
    ("تحويل أي هاتف لماسح باركود ذكي", "العمال والمدير يتجولون داخل المتجر ويفحصون الأسعار والمخزون ويرسلون السلات مباشرة لشاشة الكاشير بضغطة زر واحدة.", GOLD)
]
for i, (t_title, t_desc, t_col) in enumerate(tech_cards):
    create_card(slide3, Inches(6.9), Inches(1.6 + i * 1.8), Inches(5.6), Inches(1.65))
    tb = slide3.shapes.add_textbox(Inches(7.1), Inches(1.65 + i * 1.8), Inches(5.2), Inches(1.5))
    tf = tb.text_frame
    tf.word_wrap = True
    p = tf.paragraphs[0]
    p.text = "⚡ " + t_title
    p.font.name = "Tajawal"
    p.font.size = Pt(15)
    p.font.bold = True
    p.font.color.rgb = t_col
    p.alignment = PP_ALIGN.RIGHT
    p_d = tf.add_paragraph()
    p_d.text = t_desc
    p_d.font.name = "Segoe UI"
    p_d.font.size = Pt(12)
    p_d.font.color.rgb = MUTED
    p_d.alignment = PP_ALIGN.RIGHT

# ==============================================================================
# الشريحة 4: السلاح السري والحاجز التنافسي (100,000+ Master Catalog)
# ==============================================================================
slide4 = prs.slides.add_slide(blank_layout)
set_slide_background(slide4)
add_header(slide4, "السلاح السري: كتالوج مسبق بـ 100,000 سلعة يلغي عائق الإطلاق", "THE UNBEATABLE MOAT • الحاجز التنافسي الحصري", EMERALD)

# بطاقة كبيرة تشرح الميزة التنافسية
create_card(slide4, Inches(0.8), Inches(1.6), Inches(11.7), Inches(2.2))
tb_moat = slide4.shapes.add_textbox(Inches(1.0), Inches(1.75), Inches(11.3), Inches(1.9))
tf_moat = tb_moat.text_frame
tf_moat.word_wrap = True
p = tf_moat.paragraphs[0]
p.text = "💡 كيف حطمنا الحاجز الذي يمنع 90% من التجار من التحول الرقمي؟"
p.font.name = "Tajawal"
p.font.size = Pt(20)
p.font.bold = True
p.font.color.rgb = GOLD
p.alignment = PP_ALIGN.RIGHT

p2 = tf_moat.add_paragraph()
p2.text = "في الأنظمة التقليدية، يطلبون من التاجر إدخال 8,000 منتج يدوياً، وهو ما يستغرق شهوراً ويتسبب في فشل المشروع. نحن بنينا قاعدة بيانات مسبقة تضم أكثر من 100,000 منتج محلي ومستورد مع أرقام الباركود والأسعار والتصنيفات. التاجر يمسح الباركود، فيتعرف النظام فوراً على السلعة ويبدأ البيع في 60 ثانية فقط!"
p2.font.name = "Segoe UI"
p2.font.size = Pt(13.5)
p2.font.color.rgb = WHITE
p2.alignment = PP_ALIGN.RIGHT

# 4 إحصائيات فارقة
cat_stats = [
    ("100,000+", "سلعة مجهزة بالباركود مسبقاً", CYAN),
    ("60 ثانية", "وقت تشغيل المتجر بالكامل", EMERALD),
    ("99.8%", "دقة التعرف على المنتجات", GOLD),
    ("3 أشهر", "وقت موفر على كل تاجر جديد", WHITE)
]
for i, (val, lbl, col) in enumerate(cat_stats):
    create_card(slide4, Inches(0.8 + i * 2.95), Inches(4.1), Inches(2.85), Inches(2.8))
    tb = slide4.shapes.add_textbox(Inches(0.9), Inches(4.5), Inches(2.65), Inches(2.0))
    tf = tb.text_frame
    p_v = tf.paragraphs[0]
    p_v.text = val
    p_v.font.name = "Tajawal"
    p_v.font.size = Pt(32)
    p_v.font.bold = True
    p_v.font.color.rgb = col
    p_v.alignment = PP_ALIGN.CENTER
    p_l = tf.add_paragraph()
    p_l.text = lbl
    p_l.font.name = "Segoe UI"
    p_l.font.size = Pt(13)
    p_l.font.color.rgb = MUTED
    p_l.alignment = PP_ALIGN.CENTER

# ==============================================================================
# الشريحة 5: التقنيات العميقة الميدانية (Deep Tech Features)
# ==============================================================================
slide5 = prs.slides.add_slide(blank_layout)
set_slide_background(slide5)
add_header(slide5, "قدرات هندسية ميدانية: مصممة لواقع التاجر وتحدياته اليومية", "OPERATIONAL EXCELLENCE • القدرات الميدانية", CYAN)

deep_features = [
    ("⚖️ فك شفرات باركود الموازين الإلكترونية", "خوارزمية ذكية مدمجة تقرأ تلقائياً باركود موازين الوزن (اللحوم، الأجبان، الخضار والفاكهة) وتستخرج الوزن وسعر الكيلو والمبلغ الصافي بدقة أوتوماتيكية دون تدخل الكاشير.", CYAN),
    ("🤝 دفتر الكريدي الذكي (AI Debt Scoring)", "إدارة متطورة لديون العملاء، سقف ائتماني محدد، تنبيهات آلية عند التأخر في السداد، كشوفات حساب تفصيلية ترسل عبر الواتساب، وتقييم لمخاطر العميل.", EMERALD),
    ("📦 البيع بالوحدة والتجزئة والكرتونة (Multi-Pack)", "إدارة ذكية لحزم البيع مع احتساب تلقائي للوفر والخصومات عند شراء الكرتونة، ومزامنة لحظية للرصيد الإجمالي للمخزون دون أي التباس.", GOLD),
    ("💼 إدارة الورديات وجرد الصندوق بالسنتيم", "فصل مبيعات كل عامل وكاشير، كشف العجز أو الفائض المالي، تقارير الربح الصافي ورأس المال اللحظي، وطباعة إيصالات التسليم الحرارية عبر البلوتوث وUSB.", WHITE)
]
for i, (title, desc, col) in enumerate(deep_features):
    col_idx = i % 2
    row_idx = i // 2
    x = Inches(0.8 + col_idx * 5.95)
    y = Inches(1.6 + row_idx * 2.7)
    create_card(slide5, x, y, Inches(5.75), Inches(2.5))
    tb = slide5.shapes.add_textbox(x + Inches(0.2), y + Inches(0.15), Inches(5.35), Inches(2.2))
    tf = tb.text_frame
    tf.word_wrap = True
    p = tf.paragraphs[0]
    p.text = title
    p.font.name = "Tajawal"
    p.font.size = Pt(16)
    p.font.bold = True
    p.font.color.rgb = col
    p.alignment = PP_ALIGN.RIGHT
    p_d = tf.add_paragraph()
    p_d.text = desc
    p_d.font.name = "Segoe UI"
    p_d.font.size = Pt(12.5)
    p_d.font.color.rgb = MUTED
    p_d.alignment = PP_ALIGN.RIGHT

# ==============================================================================
# الشريحة 6: نموذج الأعمال والـ Unit Economics
# ==============================================================================
slide6 = prs.slides.add_slide(blank_layout)
set_slide_background(slide6)
add_header(slide6, "نموذج أعمال عالي الربحية: 88% هامش إجمالي واشتراكات متكررة", "MONETIZATION & UNIT ECONOMICS • نموذج الإيرادات", GOLD)

biz_streams = [
    ("اشتراكات SaaS المتكررة", "رسوم شهرية وسنوية مرنة للترخيص السحابي والنسخ الاحتياطي والتحليلات المتقدمة بهامش ربح يفوق 90%.", CYAN),
    ("باقات العتاد المتكاملة (Hardware)", "تجهيز المتاجر بشاشات لمس متطورة، طابعات حرارية، موازين إلكترونية وماسحات بأسعار تنافسية وهوامش ربح فورية.", EMERALD),
    ("شبكة التوريد B2B والمدفوعات", "عمولات ربط التجار بكبار موزعي الجملة، ومستقبلاً بوابات الدفع الإلكتروني وحلول التمويل المصغر بالتعاون مع البنوك.", GOLD)
]
for i, (st_title, st_desc, st_col) in enumerate(biz_streams):
    create_card(slide6, Inches(0.8 + i * 3.95), Inches(1.6), Inches(3.8), Inches(2.6))
    tb = slide6.shapes.add_textbox(Inches(0.9 + i * 3.95), Inches(1.8), Inches(3.6), Inches(2.2))
    tf = tb.text_frame
    tf.word_wrap = True
    p = tf.paragraphs[0]
    p.text = st_title
    p.font.name = "Tajawal"
    p.font.size = Pt(17)
    p.font.bold = True
    p.font.color.rgb = st_col
    p.alignment = PP_ALIGN.RIGHT
    p_d = tf.add_paragraph()
    p_d.text = st_desc
    p_d.font.name = "Segoe UI"
    p_d.font.size = Pt(13)
    p_d.font.color.rgb = MUTED
    p_d.alignment = PP_ALIGN.RIGHT

# مؤشرات اقتصاديات الوحدة بالأسفل
unit_metrics = [
    ("8.4x", "نسبة LTV / CAC المرتفعة", GOLD),
    ("94%", "نسبة الاحتفاظ السنوي بالعملاء", EMERALD),
    ("< شهرين", "فترة استرداد تكلفة العميل (Payback)", CYAN),
    ("88%", "هامش الربح الإجمالي (Gross Margin)", WHITE)
]
for i, (val, lbl, col) in enumerate(unit_metrics):
    create_card(slide6, Inches(0.8 + i * 2.95), Inches(4.5), Inches(2.85), Inches(2.4))
    tb = slide6.shapes.add_textbox(Inches(0.9 + i * 2.95), Inches(4.8), Inches(2.65), Inches(1.8))
    tf = tb.text_frame
    p_v = tf.paragraphs[0]
    p_v.text = val
    p_v.font.name = "Tajawal"
    p_v.font.size = Pt(32)
    p_v.font.bold = True
    p_v.font.color.rgb = col
    p_v.alignment = PP_ALIGN.CENTER
    p_l = tf.add_paragraph()
    p_l.text = lbl
    p_l.font.name = "Segoe UI"
    p_l.font.size = Pt(12.5)
    p_l.font.color.rgb = MUTED
    p_l.alignment = PP_ALIGN.CENTER

# ==============================================================================
# الشريحة 7: خطة النمو المالي والـ 10 ملايين دولار (Road to Unicorn)
# ==============================================================================
slide7 = prs.slides.add_slide(blank_layout)
set_slide_background(slide7)
add_header(slide7, "مسار النمو: خطة الوصول إلى 50,000 متجر و 16.8M$ إيرادات متكررة", "FINANCIAL ROADMAP • خطة التوسع والنمو", CYAN)

# وضع صورة الـ 10M$ ثلاثية الأبعاد
if os.path.exists(IMG_INVEST):
    slide7.shapes.add_picture(IMG_INVEST, Inches(0.8), Inches(1.6), Inches(5.8), Inches(5.3))

# خطة السنوات الثلاث
years = [
    ("السنة الأولى: التوسع الميداني وبناء الشبكة", "🎯 3,500 متجر نشط | 1.2M$ ARR\nتغطية كامل ولايات الجزائر عبر شبكة وكلاء ميدانيين وتثبيت الحصة السوقية.", CYAN),
    ("السنة الثانية: شمال إفريقيا والـ B2B", "🚀 15,000 متجر نشط | 5.4M$ ARR\nالتوسع في تونس والمغرب وإطلاق منصة التوريد المباشر لكبار الموزعين.", EMERALD),
    ("السنة الثالثة: الخليج والشرق الأوسط", "👑 50,000 متجر نشط | 16.8M$ ARR\nالتوسع في السعودية والإمارات ومصر وربط حلول المدفوعات والـ Fintech بهامش EBITDA 44%.", GOLD)
]
for i, (y_title, y_desc, y_col) in enumerate(years):
    create_card(slide7, Inches(6.9), Inches(1.6 + i * 1.8), Inches(5.6), Inches(1.65))
    tb = slide7.shapes.add_textbox(Inches(7.1), Inches(1.65 + i * 1.8), Inches(5.2), Inches(1.5))
    tf = tb.text_frame
    tf.word_wrap = True
    p = tf.paragraphs[0]
    p.text = y_title
    p.font.name = "Tajawal"
    p.font.size = Pt(15)
    p.font.bold = True
    p.font.color.rgb = y_col
    p.alignment = PP_ALIGN.RIGHT
    p_d = tf.add_paragraph()
    p_d.text = y_desc
    p_d.font.name = "Segoe UI"
    p_d.font.size = Pt(12)
    p_d.font.color.rgb = MUTED
    p_d.alignment = PP_ALIGN.RIGHT

# ==============================================================================
# الشريحة 8: طلب الاستثمار وتوزيع رأس المال (The $10M Ask)
# ==============================================================================
slide8 = prs.slides.add_slide(blank_layout)
set_slide_background(slide8)
add_header(slide8, "فرصة الشراكة الاستثمارية: جولة Series A لتسريع التوسع الإقليمي", "THE INVESTMENT ROUND • الجولة الاستثمارية", GOLD)

# بطاقة الدعوة الاستثمارية
create_card(slide8, Inches(0.8), Inches(1.6), Inches(11.7), Inches(1.4), bg_color=RGBColor(24, 20, 10), border_color=GOLD)
tb_ask = slide8.shapes.add_textbox(Inches(1.0), Inches(1.7), Inches(11.3), Inches(1.2))
tf_ask = tb_ask.text_frame
tf_ask.word_wrap = True
p = tf_ask.paragraphs[0]
p.text = "🏆 جولة تمويلية مستهدفة: 2.5M$ - 10M$ مقابل حصة ملكية استراتيجية"
p.font.name = "Tajawal"
p.font.size = Pt(22)
p.font.bold = True
p.font.color.rgb = GOLD
p.alignment = PP_ALIGN.CENTER
p_sub = tf_ask.add_paragraph()
p_sub.text = "تهدف الجولة للاستحواذ السريع على سوق التجزئة في شمال إفريقيا والشرق الأوسط، ورقمنة 50,000 نقطة بيع."
p_sub.font.name = "Segoe UI"
p_sub.font.size = Pt(13)
p_sub.font.color.rgb = WHITE
p_sub.alignment = PP_ALIGN.CENTER

# 4 أبواب لتوزيع رأس المال
allocations = [
    ("40% - الذكاء الاصطناعي والتطوير", "تعميق بنية الـ Local-Sync، خوارزميات التنبؤ التلقائي بالطلب، وبوابات الربط المالي (APIs).", CYAN),
    ("35% - المبيعات والتوزيع الميداني", "نشر شبكة مبيعات ميدانية في 50+ مدينة رئيسية لتسريع انضمام المتاجر في أقل من 24 ساعة.", EMERALD),
    ("15% - الدعم والعمليات", "مركز دعم فني 24/7 عبر الهاتف والواتساب، ومستودعات صيانة واستبدال الأجهزة الفوري.", GOLD),
    ("10% - التوسع الإقليمي والاحتياطي", "إجراءات التراخيص القانونية والربط الضريبي والمالي في أسواق الخليج العربي.", WHITE)
]
for i, (al_title, al_desc, al_col) in enumerate(allocations):
    col_idx = i % 2
    row_idx = i // 2
    x = Inches(0.8 + col_idx * 5.95)
    y = Inches(3.2 + row_idx * 1.9)
    create_card(slide8, x, y, Inches(5.75), Inches(1.75))
    tb = slide8.shapes.add_textbox(x + Inches(0.2), y + Inches(0.15), Inches(5.35), Inches(1.5))
    tf = tb.text_frame
    tf.word_wrap = True
    p = tf.paragraphs[0]
    p.text = al_title
    p.font.name = "Tajawal"
    p.font.size = Pt(16)
    p.font.bold = True
    p.font.color.rgb = al_col
    p.alignment = PP_ALIGN.RIGHT
    p_d = tf.add_paragraph()
    p_d.text = al_desc
    p_d.font.name = "Segoe UI"
    p_d.font.size = Pt(12)
    p_d.font.color.rgb = MUTED
    p_d.alignment = PP_ALIGN.RIGHT

# ==============================================================================
# الشريحة 9: مصفوفة العائد الاستثماري الحي (ROI & Value Matrix)
# ==============================================================================
slide9 = prs.slides.add_slide(blank_layout)
set_slide_background(slide9)
add_header(slide9, "أثر القيمة وعائد الاستثمار للتاجر: استرداد التكلفة في 14 يوماً فقط", "RETURN ON INVESTMENT • محاكي العائد المالي", EMERALD)

# بطاقة نموذج المتجر النموذجي
create_card(slide9, Inches(0.8), Inches(1.6), Inches(5.7), Inches(5.3))
tb_ex = slide9.shapes.add_textbox(Inches(1.0), Inches(1.8), Inches(5.3), Inches(4.9))
tf_ex = tb_ex.text_frame
tf_ex.word_wrap = True
p = tf_ex.paragraphs[0]
p.text = "📊 دراسة حالة متجر متوسط الحجم (سوبرماركت):"
p.font.name = "Tajawal"
p.font.size = Pt(18)
p.font.bold = True
p.font.color.rgb = CYAN
p.alignment = PP_ALIGN.RIGHT

case_details = [
    "• المبيعات الشهرية: 1,500,000 د.ج (18M د.ج سنوياً)",
    "• نسبة مبيعات الكريدي: 25% من إجمالي المبيعات",
    "• نسبة الفواقد والسرقات بدون نظام: 10% من الدخل",
    "• ساعات الجرد والتدقيق اليدوي: 18 ساعة أسبوعياً",
    "\nالنتيجة بعد تطبيق Nayli Market POS:",
    "✔️ استرجاع ديون منسية: + 675,000 د.ج سنوياً",
    "✔️ إيقاف الهدر والتسريب: + 1,260,000 د.ج سنوياً",
    "✔️ إجمالي التوفير المالي: + 1,935,000 د.ج سنوياً!"
]
for cd in case_details:
    p = tf_ex.add_paragraph()
    p.text = cd
    p.font.name = "Segoe UI"
    p.font.size = Pt(13)
    p.font.color.rgb = GOLD if "إجمالي التوفير" in cd else WHITE
    p.font.bold = True if "إجمالي التوفير" in cd else False
    p.alignment = PP_ALIGN.RIGHT

# بطاقة النتائج الكبرى يميناً
create_card(slide9, Inches(6.8), Inches(1.6), Inches(5.7), Inches(5.3), bg_color=RGBColor(12, 28, 24), border_color=EMERALD)
tb_res = slide9.shapes.add_textbox(Inches(7.0), Inches(2.0), Inches(5.3), Inches(4.5))
tf_res = tb_res.text_frame
tf_res.word_wrap = True
p = tf_res.paragraphs[0]
p.text = "صافي الأموال المسترجعة سنوياً للتاجر"
p.font.name = "Segoe UI"
p.font.size = Pt(14)
p.font.color.rgb = MUTED
p.alignment = PP_ALIGN.CENTER

p_big = tf_res.add_paragraph()
p_big.text = "+ 1,935,000 د.ج"
p_big.font.name = "Tajawal"
p_big.font.size = Pt(40)
p_big.font.bold = True
p_big.font.color.rgb = EMERALD
p_big.alignment = PP_ALIGN.CENTER

p_msg = tf_res.add_paragraph()
p_msg.text = "\nأموال كانت تضيع تماماً في الدفاتر اليدوية والسرقات وأخطاء الكاشير!\n"
p_msg.font.name = "Segoe UI"
p_msg.font.size = Pt(13)
p_msg.font.color.rgb = WHITE
p_msg.alignment = PP_ALIGN.CENTER

res_points = [
    ("ساعات العمل الموفرة سنوياً:", "860 ساعة عمل للتاجر"),
    ("فترة استرداد استثمار النظام:", "أقل من 14 يوماً فقط!"),
    ("العائد على الاستثمار (ROI):", "يتجاوز 1,200% سنوياً")
]
for title, val in res_points:
    p_item = tf_res.add_paragraph()
    p_item.text = f"{title} {val}"
    p_item.font.name = "Tajawal"
    p_item.font.size = Pt(14)
    p_item.font.bold = True
    p_item.font.color.rgb = CYAN
    p_item.alignment = PP_ALIGN.CENTER

# ==============================================================================
# حفظ ملف الباوربوينت
# ==============================================================================
output_filename = "Nayli_Market_10M_Presentation.pptx"
output_path = os.path.join(r"C:\Users\Admin\source\repos\flutter_billing_app", output_filename)
prs.save(output_path)
print(f"SUCCESS: PowerPoint presentation created at {output_path}")

