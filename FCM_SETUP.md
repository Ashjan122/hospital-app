# إعداد Firebase Cloud Messaging (FCM)

## ✅ ما تم إنجازه:

### 1. إعدادات التطبيق:
- ✅ إضافة مكتبة `firebase_messaging` في `pubspec.yaml`
- ✅ إضافة مكتبة `http` لإرسال الإشعارات
- ✅ إعداد `main.dart` لطلب الإذن للإشعارات
- ✅ حفظ FCM token في SharedPreferences
- ✅ حفظ FCM token للمريض في قاعدة البيانات

### 2. أذونات Android:
- ✅ `POST_NOTIFICATIONS` - لإرسال الإشعارات
- ✅ `INTERNET` - للاتصال بالإنترنت
- ✅ `WAKE_LOCK` - لإيقاظ الجهاز
- ✅ `VIBRATE` - للاهتزاز
- ✅ `RECEIVE` - لاستقبال الإشعارات

### 3. إعدادات iOS:
- ✅ `UIBackgroundModes` - للإشعارات في الخلفية
- ✅ `NSAppTransportSecurity` - للاتصالات الآمنة

## 🔧 ما يحتاج إكماله:

### 1. مفتاح الخادم (Server Key):
```dart
// في ملف admin_bookings_screen.dart، استبدل:
'Authorization': 'key=YOUR_SERVER_KEY'

// بـ مفتاح الخادم الحقيقي من Firebase Console
```

### 2. الحصول على مفتاح الخادم:
1. اذهب إلى [Firebase Console](https://console.firebase.google.com/)
2. اختر مشروعك
3. اذهب إلى Project Settings
4. في تبويب Cloud Messaging
5. انسخ Server Key

### 3. إعداد Firebase Cloud Functions (اختياري):
```javascript
// functions/index.js
const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

exports.sendNotification = functions.https.onCall(async (data, context) => {
  const { token, title, body } = data;
  
  const message = {
    notification: {
      title: title,
      body: body,
    },
    token: token,
  };
  
  try {
    const response = await admin.messaging().send(message);
    return { success: true, messageId: response };
  } catch (error) {
    throw new functions.https.HttpsError('internal', error.message);
  }
});
```

## 📱 كيفية الاستخدام:

### 1. طلب الإذن:
- عند فتح التطبيق لأول مرة، سيطلب الإذن للإشعارات
- المستخدم يمكنه السماح أو رفض

### 2. حفظ Token:
- يتم حفظ FCM token تلقائياً عند تسجيل دخول المريض
- يتم تحديث Token عند تغييره

### 3. إرسال الإشعارات:
```dart
// في شاشة الحجوزات
await sendNotificationToPatient(
  patientId,
  'تذكير بموعد',
  'موعدك غداً الساعة 10:00 صباحاً'
);
```

## 🚀 الميزات المتاحة:

- ✅ طلب الإذن للإشعارات تلقائياً
- ✅ حفظ FCM token للمرضى
- ✅ إرسال إشعارات مخصصة
- ✅ دعم الإشعارات في الخلفية
- ✅ دعم الإشعارات عند فتح التطبيق

## 📝 ملاحظات مهمة:

1. **مفتاح الخادم**: يجب استبداله بمفتاح حقيقي من Firebase Console
2. **Firebase Cloud Functions**: يفضل استخدامها لإرسال الإشعارات بدلاً من HTTP مباشرة
3. **الاختبار**: تأكد من اختبار الإشعارات على أجهزة حقيقية
4. **الأمان**: لا تشارك مفتاح الخادم في الكود العام

## 🔍 استكشاف الأخطاء:

### إذا لم تظهر الإشعارات:
1. تأكد من منح الإذن للإشعارات
2. تحقق من FCM token في قاعدة البيانات
3. تأكد من صحة مفتاح الخادم
4. تحقق من سجلات Firebase Console

### إذا لم يتم حفظ Token:
1. تحقق من اتصال الإنترنت
2. تأكد من تسجيل دخول المريض
3. تحقق من سجلات التطبيق
