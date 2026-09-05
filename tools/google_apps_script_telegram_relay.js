/**
 * =========================================================================
 * Nayli POS - Cloud Licensing & Telegram Relay System (Google Apps Script)
 * =========================================================================
 * 
 * هذا السكريبت يعمل مباشرة على سيرفرات Google السحابية (USA / Europe).
 * الميزة الأساسية:
 * 1. سيرفرات Google غير محجوبة إطلاقاً في الجزائر أو العالم.
 * 2. سيرفرات Google تتصل بـ Telegram API بسرعة فائقة (أقل من 0.2 ثانية) وبدون حجب أو بطء.
 * 3. عند ضغط الزبون على "تفعيل أونلاين"، يتلقى Google Script الطلب ويسجله في Google Sheet فوراً
 *    ويرسل إشعار تلغرام تفاعلي للمطور بأزرار التفعيل الفوري (دائم، سنوي، شهري، رفض).
 * 4. عند ضغط المطور على الزر في تلغرام، يقوم السكريبت بتحديث الجدول فوراً ويصبح جهاز الزبون مفعل!
 */

// ضع التوكن ومعرف الشات الخاص ببوت المطور هنا
const TELEGRAM_BOT_TOKEN = '8667390926:AAEuQg4ZK8z7KmwAaemoGGdZFDxI-IiqPOI';
const DEVELOPER_CHAT_ID = '5115465267';

// اسم ورقة العمل في Google Sheet
const SHEET_NAME = 'Licenses';

/**
 * دالة استقبال الطلبات من التطبيق (Desktop & Mobile)
 */
function doGet(e) {
  try {
    var params = e.parameter || {};
    var action = params.action || 'check_or_join';
    var deviceId = params.deviceId;
    var storeName = params.storeName || 'متجر كاشير';
    var phone = params.phone || 'غير مسجل';
    var deviceType = params.deviceType || 'PC';
    var notifyTelegram = params.notifyTelegram;

    if (!deviceId) {
      return ContentService.createTextOutput(JSON.stringify({
        isActivated: false,
        error: 'missing_device_id'
      })).setMimeType(ContentService.MimeType.JSON);
    }

    var sheet = getOrCreateSheet();
    var rowData = findDevice(sheet, deviceId);

    // إذا كان الجهاز مسجلاً مسبقاً ومفعلاً
    if (rowData && rowData.isActivated) {
      return ContentService.createTextOutput(JSON.stringify({
        isActivated: true,
        plan: rowData.plan || 'P',
        storeName: rowData.storeName || storeName,
        maxDevices: rowData.maxDevices || 1,
        message: 'الجهاز مرخص ومفعل'
      })).setMimeType(ContentService.MimeType.JSON);
    }

    // إذا لم يكن مسجلاً، نسجله في الجدول كـ غير مفعل (قيد المراجعة)
    var isNewDevice = false;
    if (!rowData) {
      sheet.appendRow([
        deviceId,
        storeName,
        phone,
        deviceType,
        false, // isActivated
        'P',   // default plan
        1,     // maxDevices
        new Date() // requestDate
      ]);
      isNewDevice = true;
    }

    // إرسال إشعار التيليجرام إذا كان جهازاً جديداً أو طُلب ذلك بسبب حجب التلغرام محلياً
    if (isNewDevice || notifyTelegram === '1') {
      sendTelegramActivationAlert(deviceId, storeName, phone, deviceType);
    }

    return ContentService.createTextOutput(JSON.stringify({
      isActivated: false,
      message: 'طلبك قيد المراجعة لدى المطور'
    })).setMimeType(ContentService.MimeType.JSON);

  } catch (err) {
    return ContentService.createTextOutput(JSON.stringify({
      isActivated: false,
      error: err.toString()
    })).setMimeType(ContentService.MimeType.JSON);
  }
}

/**
 * دالة استقبال ضغطات الأزرار التفاعلية من تيليجرام (Webhook Callback)
 */
function doPost(e) {
  try {
    var update = JSON.parse(e.postData.contents);
    if (update.callback_query) {
      handleTelegramCallback(update.callback_query);
    }
    return ContentService.createTextOutput('OK');
  } catch (err) {
    return ContentService.createTextOutput('ERROR: ' + err.toString());
  }
}

/**
 * إرسال رسالة تيليجرام التفاعلية للمطور من سيرفرات جوجل الحرة
 */
function sendTelegramActivationAlert(deviceId, storeName, phone, deviceType) {
  if (!TELEGRAM_BOT_TOKEN || !DEVELOPER_CHAT_ID) return;

  var url = 'https://api.telegram.org/bot' + TELEGRAM_BOT_TOKEN + '/sendMessage';
  
  var text = '🔔 <b>طلب تفعيل ترخيص جديد (Nayli POS)</b>\n' +
             '━━━━━━━━━━━━━━━━━\n' +
             '🏬 <b>المحل:</b> ' + storeName + '\n' +
             '📱 <b>الهاتف:</b> ' + phone + '\n' +
             '💻 <b>النوع:</b> ' + deviceType + '\n' +
             '🔑 <b>كود الجهاز:</b> <code>' + deviceId + '</code>\n' +
             '⏰ <b>الوقت:</b> ' + Utilities.formatDate(new Date(), 'GMT+1', 'yyyy-MM-dd HH:mm') + '\n' +
             '━━━━━━━━━━━━━━━━━\n' +
             '👇 <b>اختر نوع الباقة وسعة الأجهزة للتفعيل المباشر:</b>';

  var keyboard = {
    inline_keyboard: [
      [
        { text: '🌟 دائم (جهاز 1)', callback_data: 'P1:' + deviceId },
        { text: '🌟 دائم (3 أجهزة)', callback_data: 'P3:' + deviceId },
        { text: '🌟 دائم (5 أجهزة)', callback_data: 'P5:' + deviceId }
      ],
      [
        { text: '📅 سنوي (Y)', callback_data: 'Y:' + deviceId },
        { text: '⏳ تجريبي 30 يوم (M)', callback_data: 'M:' + deviceId },
        { text: '❌ رفض / حظر', callback_data: 'REJ:' + deviceId }
      ]
    ]
  };

  var payload = {
    chat_id: DEVELOPER_CHAT_ID,
    text: text,
    parse_mode: 'HTML',
    reply_markup: JSON.stringify(keyboard)
  };

  var options = {
    method: 'post',
    contentType: 'application/json',
    payload: JSON.stringify(payload),
    muteHttpExceptions: true
  };

  UrlFetchApp.fetch(url, options);
}

/**
 * معالجة ضغط أزرار تيليجرام وتحديث Google Sheet فوراً
 */
function handleTelegramCallback(callbackQuery) {
  var data = callbackQuery.data; // مثل: P1:DEVICE_ID
  var callbackQueryId = callbackQuery.id;
  var messageId = callbackQuery.message.message_id;
  var chatId = callbackQuery.message.chat.id;

  var parts = data.split(':');
  var actionCode = parts[0];
  var deviceId = parts[1];

  var sheet = getOrCreateSheet();
  var alertText = '';
  var newPlan = 'P';
  var maxDevices = 1;
  var activate = true;

  if (actionCode === 'P1') {
    newPlan = 'P'; maxDevices = 1; alertText = '✅ تم تفعيل باقة دائمة (جهاز 1)';
  } else if (actionCode === 'P3') {
    newPlan = 'P'; maxDevices = 3; alertText = '✅ تم تفعيل باقة دائمة (3 أجهزة)';
  } else if (actionCode === 'P5') {
    newPlan = 'P'; maxDevices = 5; alertText = '✅ تم تفعيل باقة دائمة (5 أجهزة)';
  } else if (actionCode === 'Y') {
    newPlan = 'Y'; maxDevices = 1; alertText = '✅ تم تفعيل باقة سنوية (سنة واحدة)';
  } else if (actionCode === 'M') {
    newPlan = 'M'; maxDevices = 1; alertText = '✅ تم تفعيل باقة تجريبية (30 يوم)';
  } else if (actionCode === 'REJ') {
    activate = false; alertText = '❌ تم رفض وتجميد هذا الجهاز';
  }

  // تحديث السطر في Google Sheet
  updateDeviceActivation(sheet, deviceId, activate, newPlan, maxDevices);

  // إشعار المطور في تيليجرام
  var answerUrl = 'https://api.telegram.org/bot' + TELEGRAM_BOT_TOKEN + '/answerCallbackQuery';
  UrlFetchApp.fetch(answerUrl, {
    method: 'post',
    contentType: 'application/json',
    payload: JSON.stringify({
      callback_query_id: callbackQueryId,
      text: alertText,
      show_alert: false
    }),
    muteHttpExceptions: true
  });

  // تعديل نص الرسالة لإظهار أن الطلب قد نُفّذ
  var editUrl = 'https://api.telegram.org/bot' + TELEGRAM_BOT_TOKEN + '/editMessageText';
  UrlFetchApp.fetch(editUrl, {
    method: 'post',
    contentType: 'application/json',
    payload: JSON.stringify({
      chat_id: chatId,
      message_id: messageId,
      text: callbackQuery.message.text + '\n\n' + alertText + ' بنجاح! 🚀',
      parse_mode: 'HTML'
    }),
    muteHttpExceptions: true
  });
}

/**
 * الحصول على ورقة العمل أو إنشاؤها
 */
function getOrCreateSheet() {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var sheet = ss.getSheetByName(SHEET_NAME);
  if (!sheet) {
    sheet = ss.insertSheet(SHEET_NAME);
    sheet.appendRow(['DeviceId', 'StoreName', 'Phone', 'DeviceType', 'IsActivated', 'Plan', 'MaxDevices', 'Date']);
  }
  return sheet;
}

/**
 * البحث عن جهاز في الجدول
 */
function findDevice(sheet, deviceId) {
  var data = sheet.getDataRange().getValues();
  for (var i = 1; i < data.length; i++) {
    if (String(data[i][0]).trim() === String(deviceId).trim()) {
      return {
        rowIndex: i + 1,
        deviceId: data[i][0],
        storeName: data[i][1],
        phone: data[i][2],
        isActivated: data[i][4] === true || String(data[i][4]).toLowerCase() === 'true',
        plan: data[i][5],
        maxDevices: Number(data[i][6]) || 1
      };
    }
  }
  return null;
}

/**
 * تحديث حالة التفعيل في الجدول
 */
function updateDeviceActivation(sheet, deviceId, activate, plan, maxDevices) {
  var data = sheet.getDataRange().getValues();
  for (var i = 1; i < data.length; i++) {
    if (String(data[i][0]).trim() === String(deviceId).trim()) {
      sheet.getRange(i + 1, 5).setValue(activate); // IsActivated
      sheet.getRange(i + 1, 6).setValue(plan);     // Plan
      sheet.getRange(i + 1, 7).setValue(maxDevices); // MaxDevices
      return true;
    }
  }
  return false;
}
