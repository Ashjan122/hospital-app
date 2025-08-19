# SMS Service Implementation

## نظرة عامة
تم تحديث خدمة الرسائل النصية (SMS) لاستخدام API الخاص بـ Airtel Sudan لإرسال رموز التحقق عند إنشاء الحساب.

## التحديثات المطبقة

### 1. تحديث نقطة النهاية API
- **الرابط القديم**: `https://www.airtel.sd/BulkSMS/webacc.aspx`
- **الرابط الجديد**: `https://www.airtel.sd/api/html_send_sms/`

### 2. تحديث معاملات API
تم تحديث المعاملات لتتطابق مع API الجديد:
- `username` بدلاً من `user`
- `password` بدلاً من `pwd`
- `phone_number` بدلاً من `Nums`
- `message` بدلاً من `smstext`
- `sender` بدلاً من `Sender`

### 3. تحسين معالجة الاستجابة
- تحليل الاستجابة لاستخراج `apiMsgId` و `units`
- إرجاع معلومات مفصلة عن حالة الإرسال
- معالجة أفضل للأخطاء

## كيفية الاستخدام

### إرسال رمز التحقق
```dart
// إنشاء رمز التحقق
String otp = SMSService.generateOTP();

// إرسال الرمز عبر SMS
Map<String, dynamic> result = await SMSService.sendOTP(
  phoneNumber, // رقم الهاتف
  otp,         // رمز التحقق
);

// التحقق من النتيجة
if (result['success']) {
  print('تم إرسال رمز التحقق بنجاح!');
  print('معرف الرسالة: ${result['apiMsgId']}');
} else {
  print('فشل في الإرسال: ${result['message']}');
}
```

### إرسال رسالة بسيطة
```dart
Map<String, dynamic> result = await SMSService.sendSimpleSMS(
  phoneNumber,
  'مرحباً! هذه رسالة اختبار.',
);
```

### التحقق من رمز التحقق
```dart
bool isValid = SMSService.verifyOTP(
  inputOTP,      // الرمز المدخل من المستخدم
  storedOTP,     // الرمز المخزن
  otpCreatedAt,  // وقت إنشاء الرمز
);
```

## مثال على الاستجابة المتوقعة

عند نجاح الإرسال، ستكون الاستجابة مشابهة لهذا:
```
Status: completed
Total Units: 1
249124584291 -> apiMsgId: 59299 (units=1)
```

## الملفات المحدثة

1. **`lib/services/sms_service.dart`** - الخدمة الرئيسية
2. **`lib/examples/sms_example.dart`** - مثال على الاستخدام
3. **`test_sms_service.dart`** - ملف اختبار

## اختبار الخدمة

### 1. تشغيل الاختبار البسيط
```bash
dart test_sms_service.dart
```

### 2. استخدام مثال Flutter
```dart
// في ملف main.dart أو أي صفحة أخرى
import 'package:hospital_app/examples/sms_example.dart';

// في Navigator
Navigator.push(
  context,
  MaterialPageRoute(builder: (context) => const SMSExample()),
);
```

## معالجة الأخطاء

### أخطاء شائعة وحلولها

1. **خطأ في الاتصال بالإنترنت**
   - تأكد من وجود اتصال بالإنترنت
   - تحقق من إعدادات الشبكة

2. **خطأ في بيانات الاعتماد**
   - تأكد من صحة اسم المستخدم وكلمة المرور
   - تحقق من صلاحية الحساب

3. **خطأ في تنسيق رقم الهاتف**
   - تأكد من إدخال رقم صحيح
   - الخدمة تضيف تلقائياً رمز البلد 249

## الأمان

### نصائح مهمة
1. **لا تشارك بيانات الاعتماد** في الكود المصدري
2. **استخدم متغيرات البيئة** لتخزين بيانات الاعتماد
3. **تحقق من صحة المدخلات** قبل الإرسال
4. **ضع حدود لعدد المحاولات** لتجنب الإساءة

### مثال على استخدام متغيرات البيئة
```dart
// في ملف .env
SMS_USERNAME=jawda
SMS_PASSWORD=Wda%^054J)(aDSn^
SMS_SENDER=Jawda

// في الكود
String username = const String.fromEnvironment('SMS_USERNAME');
String password = const String.fromEnvironment('SMS_PASSWORD');
```

## الدعم والمساعدة

إذا واجهت أي مشاكل:
1. تحقق من سجلات الأخطاء في Console
2. تأكد من صحة بيانات الاعتماد
3. اختبر الاتصال بالإنترنت
4. راجع توثيق API الخاص بـ Airtel Sudan

## ملاحظات إضافية

- الخدمة تدعم تنسيق أرقام الهاتف السودانية تلقائياً
- رمز التحقق صالح لمدة 5 دقائق
- يتم إنشاء رمز من 6 أرقام عشوائياً
- جميع الرسائل تُرسل باللغة العربية
