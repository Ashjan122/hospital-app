# استكشاف أخطاء عدم ظهور المرافق الطبية

## المشكلة
المرافق الطبية لا تظهر في التطبيق بعد إضافة نظام الترتيب.

## الأسباب المحتملة

### 1. مشاكل قواعد أمان Firebase
- قد تكون قواعد الأمان تمنع قراءة المجموعة
- التحقق من قواعد Firestore Security Rules

### 2. عدم وجود بيانات
- لا توجد مرافق في قاعدة البيانات
- المرافق موجودة لكن في مجموعة مختلفة

### 3. مشاكل في ترتيب البيانات
- حقل `order` غير موجود في المستندات الحالية
- خطأ في دالة الترتيب

### 4. مشاكل شبكة/اتصال
- ضعف الاتصال بالإنترنت
- مشاكل في خدمة Firebase

## الحلول المطبقة

### 1. تحسين دالة جلب البيانات
```dart
Future<List<QueryDocumentSnapshot>> fetchFacilities() async {
  try {
    print('بدء تحميل المرافق الطبية...');
    
    // جلب جميع المرافق بدون ترتيب أولاً
    final snapshot = await FirebaseFirestore.instance
        .collection('medicalFacilities')
        .get()
        .timeout(const Duration(seconds: 15));

    print('تم جلب البيانات من Firebase: ${snapshot.docs.length} مستند');

    // ترتيب محلي آمن
    final sortedDocs = List<QueryDocumentSnapshot>.from(snapshot.docs);
    
    // الترتيب مع معالجة الأخطاء
    sortedDocs.sort((a, b) {
      try {
        final aData = a.data() as Map<String, dynamic>;
        final bData = b.data() as Map<String, dynamic>;
        
        final aOrder = aData['order'] as int? ?? 999;
        final bOrder = bData['order'] as int? ?? 999;
        
        if (aOrder != bOrder) {
          return aOrder.compareTo(bOrder);
        }
        
        final aAvailable = aData['available'] as bool? ?? false;
        final bAvailable = bData['available'] as bool? ?? false;
        
        return bAvailable ? -1 : (aAvailable ? 1 : 0);
      } catch (e) {
        return 0;
      }
    });

    return sortedDocs;
  } catch (e) {
    print('خطأ في تحميل المرافق الطبية: $e');
    rethrow;
  }
}
```

### 2. إضافة معالجة أخطاء شاملة
- التحقق من `snapshot.hasError`
- عرض رسائل خطأ واضحة
- أزرار "إعادة المحاولة"

### 3. إضافة رسائل تصحيح
- طباعة عدد المستندات المحملة
- طباعة تفاصيل كل مرفق
- رسائل حالة الاتصال

### 4. اختبار اتصال Firebase
```dart
Future<void> _testFirebaseConnection() async {
  try {
    final testQuery = await FirebaseFirestore.instance
        .collection('medicalFacilities')
        .limit(1)
        .get()
        .timeout(const Duration(seconds: 5));
    
    print('✅ نجح الاتصال - عدد المستندات: ${testQuery.docs.length}');
  } catch (e) {
    print('❌ فشل الاتصال: $e');
  }
}
```

### 5. إضافة RefreshIndicator
- السحب للأسفل لإعادة التحميل
- تحديث البيانات يدوياً

## خطوات استكشاف الأخطاء

### 1. فحص وحدة التحكم
```bash
flutter run
# ابحث عن الرسائل التالية:
# "🔥 اختبار الاتصال بـ Firebase..."
# "✅ نجح الاتصال بـ Firebase"
# "تم جلب البيانات من Firebase: X مستند"
```

### 2. فحص قواعد Firestore
```javascript
// قواعد آمنة للقراءة
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /medicalFacilities/{document} {
      allow read: if true;
      allow write: if request.auth != null;
    }
  }
}
```

### 3. فحص البيانات في Firebase Console
- انتقل إلى Firebase Console
- افتح Firestore Database
- تحقق من وجود مجموعة `medicalFacilities`
- تأكد من وجود مستندات

### 4. إضافة بيانات تجريبية
```dart
// في صفحة الكنترول
final testCenter = {
  'name': 'مركز تجريبي',
  'address': 'عنوان تجريبي',
  'phone': '123456789',
  'order': 1,
  'available': true,
  'createdAt': FieldValue.serverTimestamp(),
};

await FirebaseFirestore.instance
    .collection('medicalFacilities')
    .add(testCenter);
```

## الخطوات التالية

1. **تشغيل التطبيق ومراقبة وحدة التحكم**
2. **فحص رسائل التصحيح**
3. **التحقق من وجود بيانات في Firebase**
4. **إضافة مرفق تجريبي إذا لزم الأمر**
5. **فحص قواعد الأمان**

## ملاحظات
- تم إضافة مهلة زمنية 15 ثانية لتجنب انتهاء الصلاحية
- تم تحسين معالجة الأخطاء
- تم إضافة ترتيب محلي آمن
- تم إضافة رسائل تصحيح مفصلة
