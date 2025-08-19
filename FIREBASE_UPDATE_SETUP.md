# إعداد بيانات التحديث في Firebase

## 📋 البيانات المطلوبة في Firestore

### **المسار:**
```
Collection: appConfig
Document: appUpdate
```

### **الحقول المطلوبة:**

#### **1. lastVersion (String)**
- **القيمة:** `"1.0.2"`
- **الوصف:** رقم الإصدار الجديد المتاح

#### **2. updatrUrl (String)**
- **القيمة:** `"https://firebasestorage.googleapis.com/v0/b/hospitalapp-681f1.firebasestorage.app/o/app-release.apk?alt=media&token=2bc9b926-81c5-4bb3-82d4-e85825836173"`
- **الوصف:** رابط تحميل الإصدار الجديد

#### **3. isAvailable (Boolean) - اختياري**
- **القيمة:** `true`
- **الوصف:** هل التحديث متاح أم لا
- **الافتراضي:** `true`

#### **4. forceUpdate (Boolean) - اختياري**
- **القيمة:** `false`
- **الوصف:** هل التحديث إجباري أم لا
- **الافتراضي:** `false`

#### **5. message (String) - اختياري**
- **القيمة:** `"يتوفر تحديث جديد للتطبيق"`
- **الوصف:** رسالة التحديث
- **الافتراضي:** `"يتوفر تحديث جديد للتطبيق"`

## 🔧 كيفية الإعداد

### **1. إنشاء Collection:**
```
Collection Name: appConfig
```

### **2. إنشاء Document:**
```
Document ID: appUpdate
```

### **3. إضافة الحقول:**

```json
{
  "lastVersion": "1.0.2",
  "updatrUrl": "https://firebasestorage.googleapis.com/v0/b/hospitalapp-681f1.firebasestorage.app/o/app-release.apk?alt=media&token=2bc9b926-81c5-4bb3-82d4-e85825836173",
  "isAvailable": true,
  "forceUpdate": false,
  "message": "يتوفر تحديث جديد للتطبيق"
}
```

## 🎯 كيف يعمل النظام

### **1. عند فتح التطبيق:**
- ✅ يتم التحقق من وجود تحديث جديد
- ✅ مقارنة الإصدار الحالي مع `lastVersion`
- ✅ إذا كان الإصدار الحالي أقدم، يظهر dialog

### **2. في Dialog التحديث:**
- ✅ عرض الإصدار الحالي والإصدار الجديد
- ✅ رسالة التحديث المخصصة
- ✅ زر "تحديث الآن" يفتح `updatrUrl`
- ✅ زر "لاحقاً" (إذا لم يكن التحديث إجباري)

### **3. التحديث الإجباري:**
- ✅ إذا كان `forceUpdate: true`، لا يمكن إغلاق dialog
- ✅ يجب تحديث التطبيق للاستمرار

## 📱 مثال للبيانات الحالية

```json
{
  "lastVersion": "1.0.2",
  "updatrUrl": "https://firebasestorage.googleapis.com/v0/b/hospitalapp-681f1.firebasestorage.app/o/app-release.apk?alt=media&token=2bc9b926-81c5-4bb3-82d4-e85825836173",
  "isAvailable": true,
  "forceUpdate": false,
  "message": "يتوفر تحديث جديد للتطبيق"
}
```

## 🚀 النتيجة

**عند فتح التطبيق، إذا كان الإصدار الحالي أقدم من 1.0.2، سيظهر dialog التحديث تلقائياً في أي صفحة!**
