# دليل اختبار نظام التحديث

## 📋 البيانات الموجودة في Firestore:
```json
{
  "lastVersion": "1.0.1",
  "updatrUrl": "https://firebasestorage.googleapis.com/v0/b/hospitalapp-681f1.firebasestorage.app/o/app-release.apk?alt=media&token=2c1460ee-633d-4ef0-8e59-00faaa8f6ff5"
}
```

## 🔧 البيانات المطلوبة في Firestore:

### **البيانات الأساسية (موجودة):**
```json
{
  "lastVersion": "1.0.1",
  "updatrUrl": "https://firebasestorage.googleapis.com/v0/b/hospitalapp-681f1.firebasestorage.app/o/app-release.apk?alt=media&token=2c1460ee-633d-4ef0-8e59-00faaa8f6ff5"
}
```

### **إضافة الحقول الاختيارية (لتحسين التجربة):**
```json
{
  "lastVersion": "1.0.1",
  "updatrUrl": "https://firebasestorage.googleapis.com/v0/b/hospitalapp-681f1.firebasestorage.app/o/app-release.apk?alt=media&token=2c1460ee-633d-4ef0-8e59-00faaa8f6ff5",
  "isAvailable": true,
  "forceUpdate": false,
  "message": "يتوفر تحديث جديد للتطبيق مع تحسينات وإصلاحات"
}
```

## 🧪 كيفية الاختبار:

### **1. اختبار تلقائي:**
- افتح التطبيق
- إذا كان الإصدار الحالي (1.0.0) أقل من الجديد (1.0.1)، سيظهر dialog

### **2. اختبار يدوي:**
- سجل دخول كـ "كنترول"
- اضغط على أيقونة التحديث في شريط العنوان
- سيظهر dialog التحديث أو رسالة "لا يوجد تحديث"

### **3. تحقق من الإصدار الحالي:**
- الإصدار الحالي: `1.0.0` (في pubspec.yaml)
- الإصدار الجديد: `1.0.1` (في Firestore)
- ✅ يجب أن يظهر التحديث

## 🔍 استكشاف الأخطاء:

### **إذا لم يظهر التحديث:**
1. تحقق من `isAvailable: true`
2. تأكد من أن `lastVersion` = "1.0.1"
3. تأكد من وجود `updatrUrl`

### **إذا ظهر خطأ:**
- تحقق من اتصال الإنترنت
- تحقق من إعدادات Firestore Security Rules
- تحقق من صحة الرابط

## 📱 النتيجة المتوقعة:
- ✅ dialog جميل مع معلومات التحديث
- ✅ الإصدار الحالي: 1.0.0
- ✅ الإصدار الجديد: 1.0.1
- ✅ زر "تحديث الآن" يفتح الرابط
- ✅ زر "لاحقاً" يغلق dialog
