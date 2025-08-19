# إعداد سريع لنظام تحديث التطبيق

## الخطوات المطلوبة في Firestore:

### 1. إنشاء Collection
- اذهب إلى Firestore Console
- أنشئ collection جديد باسم: `appConfig`

### 2. إنشاء Document
- في collection `appConfig`
- أنشئ document جديد باسم: `appUpdate`

### 3. إضافة البيانات
```json
{
  "lastVersion": "1.0.1",
  "updatrUrl": "https://your-download-link.com/app.apk",
  "isAvailable": true,
  "forceUpdate": false,
  "message": "يتوفر تحديث جديد للتطبيق مع تحسينات وإصلاحات"
}
```

## كيفية العمل:
- ✅ عند فتح التطبيق، يتم التحقق من وجود تحديث
- ✅ إذا كان هناك تحديث أحدث، يظهر dialog جميل
- ✅ المستخدم يمكنه الضغط على "تحديث الآن" لفتح رابط التحميل
- ✅ إذا كان التحديث إجباري، لا يمكن إغلاق dialog
- ✅ بعد التحديث، لا يظهر التنبيه مرة أخرى في نفس اليوم

## إدارة التحديثات:
- **إيقاف التحديث**: `"isAvailable": false`
- **تحديث إجباري**: `"forceUpdate": true`
- **تغيير الرسالة**: `"message": "رسالة جديدة"`

## الملفات المضافة:
- `lib/services/app_update_service.dart` - خدمة التحديث
- `lib/widgets/app_update_dialog.dart` - dialog التحديث
- `lib/widgets/app_update_wrapper.dart` - wrapper للتحقق التلقائي
- `APP_UPDATE_SETUP.md` - دليل مفصل
