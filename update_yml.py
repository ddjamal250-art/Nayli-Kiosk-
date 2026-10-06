import sys
f1 = '.github/workflows/build_windows_setup.yml'
with open(f1, 'r', encoding='utf-8') as f: lines = f.readlines()
with open(f1, 'w', encoding='utf-8') as f:
  for l in lines:
    if 'generate_release_notes: false' in l:
      f.write(l)
      f.write('          body: |\n')
      f.write('            ## 🚀 Nayli Kiosk Desktop POS v2.4.6 - التحديث الرسمي الشامل\n\n')
      f.write('            ### 📥 روابط التحميل المباشرة بنقرة واحدة (Direct 1-Click Downloads):\n')
      f.write('            - **[تحميل مثبت البرنامج التلقائي (Nayli-Kiosk-Desktop-Setup.exe)](https://github.com/${{ github.repository }}/releases/download/v2.4.6/Nayli-Kiosk-Desktop-Setup.exe)**\n')
      f.write('            - **[تحميل النسخة المحمولة بدون تثبيت (Nayli-Kiosk-Desktop-Portable.zip)](https://github.com/${{ github.repository }}/releases/download/v2.4.6/Nayli-Kiosk-Desktop-Portable.zip)**\n\n')
      f.write('            ---\n')
      f.write('            ✅ **المميزات والإصلاحات الكبرى في هذا التحديث (v2.4.6):**\n')
      f.write('            1. **الذكاء الاصطناعي للفواتير (Gemini AI):** دمج الذكاء الاصطناعي بشكل ثابت لجميع التجار لقراءة الفواتير وتفريغ المنتجات آلياً إلى المخزون (بدون الحاجة لضبط API معقد) مع إمكانية التعديل للمحترفين.\n')
      f.write('            2. **مسح المنتجات وإدخالها فورياً:** ترقية خانة البحث في المخزون لتقبل المسح بالباركود وتعبئة البيانات تلقائياً بلمح البصر دون أي بحث مرئي بطيء.\n')
      f.write('            3. **تنظيف الشفرة واستقرار النظام:** حل شامل لجميع تحذيرات وأخطاء الترجمة المخفية ليصبح النظام خالياً تماماً من الأخطاء البرمجية ويعمل بكفاءة مطلقة.\n')
      f.write('            4. **تفعيل مراقبة حركة الصندوق اللحظية (Live Cash Drawer):** تحويل قسم حالة الصندوق إلى مراقبة لحظية حقيقية.\n')
      f.write('          files: |\n')
      f.write('            build/installer/Nayli-Kiosk-Desktop-Setup.exe\n')
      f.write('            build/installer/Nayli-Kiosk-Desktop-Portable.zip\n')
      break
    else:
      f.write(l)
print('Done!')
