# دليل تحسين أداء التطبيق

## 🚀 المشاكل المحتملة وحلولها

### **1. مشكلة الـ Loading الطويل**

#### **الأسباب المحتملة:**
- استعلامات Firestore متعددة ومتتالية
- عدم وجود تخزين مؤقت (Cache)
- استعلامات غير محسنة
- عدم وجود timeout للعمليات

#### **الحلول:**

##### **أ. استخدام Widgets محسنة:**
```dart
// بدلاً من
FutureBuilder<List<QueryDocumentSnapshot>>(
  future: fetchDoctors(),
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return Center(child: CircularProgressIndicator());
    }
    // ...
  },
)

// استخدم
OptimizedFutureBuilder<List<QueryDocumentSnapshot>>(
  future: fetchDoctors(),
  timeout: const Duration(seconds: 8),
  builder: (context, data) {
    // بناء الواجهة
  },
  loadingWidget: const OptimizedLoadingWidget(
    message: 'جاري تحميل الأطباء...',
  ),
)
```

##### **ب. تحسين استعلامات Firestore:**
```dart
// بدلاً من استعلامات متعددة
for (var facilityDoc in facilitiesSnapshot.docs) {
  final specializationsSnapshot = await FirebaseFirestore.instance
      .collection('medicalFacilities')
      .doc(facilityDoc.id)
      .collection('specializations')
      .get();
  // ...
}

// استخدم استعلام واحد مع where
final allData = await FirebaseFirestore.instance
    .collection('medicalFacilities')
    .where('available', isEqualTo: true)
    .get();
```

##### **ج. إضافة timeout للعمليات:**
```dart
Future<T> optimizedOperation<T>(Future<T> Function() operation) async {
  try {
    return await operation().timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        throw TimeoutException('انتهت مهلة العملية');
      },
    );
  } catch (e) {
    print('خطأ في العملية: $e');
    rethrow;
  }
}
```

### **2. تحسين تحميل البيانات**

#### **أ. استخدام StreamBuilder بدلاً من FutureBuilder للبيانات المتغيرة:**
```dart
StreamBuilder<QuerySnapshot>(
  stream: FirebaseFirestore.instance
      .collection('medicalFacilities')
      .snapshots(),
  builder: (context, snapshot) {
    // بناء الواجهة
  },
)
```

#### **ب. تحسين تحميل الصور:**
```dart
// استخدم CachedNetworkImage
CachedNetworkImage(
  imageUrl: imageUrl,
  placeholder: (context, url) => const CircularProgressIndicator(),
  errorWidget: (context, url, error) => const Icon(Icons.error),
  memCacheWidth: 300, // تحسين استخدام الذاكرة
)
```

### **3. تحسين واجهة المستخدم**

#### **أ. استخدام ListView.builder بدلاً من ListView:**
```dart
// بدلاً من
ListView(
  children: items.map((item) => ItemWidget(item)).toList(),
)

// استخدم
ListView.builder(
  itemCount: items.length,
  itemBuilder: (context, index) => ItemWidget(items[index]),
)
```

#### **ب. تحسين بناء Widgets:**
```dart
// استخدم const للـ widgets الثابتة
const OptimizedLoadingWidget(
  message: 'جاري التحميل...',
  color: Colors.blue,
)
```

### **4. تحسين إدارة الحالة**

#### **أ. استخدام setState بحكمة:**
```dart
// تجنب setState المتكرر
void updateData() {
  if (mounted) {
    setState(() {
      _data = newData;
    });
  }
}
```

#### **ب. استخدام mounted check:**
```dart
Future<void> loadData() async {
  final data = await fetchData();
  if (mounted) {
    setState(() {
      _data = data;
    });
  }
}
```

## 🛠️ الأدوات المضافة

### **1. OptimizedLoadingWidget**
```dart
const OptimizedLoadingWidget(
  message: 'جاري تحميل البيانات...',
  color: Color.fromARGB(255, 78, 17, 175),
  size: 40.0,
)
```

### **2. OptimizedFutureBuilder**
```dart
OptimizedFutureBuilder<List<Map<String, dynamic>>>(
  future: fetchData(),
  timeout: const Duration(seconds: 8),
  builder: (context, data) {
    return ListView.builder(
      itemCount: data.length,
      itemBuilder: (context, index) => ItemWidget(data[index]),
    );
  },
  loadingWidget: const OptimizedLoadingWidget(message: 'جاري التحميل...'),
  errorWidget: CustomErrorWidget(),
  emptyWidget: CustomEmptyWidget(),
)
```

### **3. OptimizedStreamBuilder**
```dart
OptimizedStreamBuilder<QuerySnapshot>(
  stream: FirebaseFirestore.instance.collection('data').snapshots(),
  builder: (context, snapshot) {
    return ListView.builder(
      itemCount: snapshot.docs.length,
      itemBuilder: (context, index) => ItemWidget(snapshot.docs[index]),
    );
  },
)
```

## 📋 قائمة التحسينات المطلوبة

### **أولوية عالية:**
1. ✅ إضافة timeout لجميع العمليات
2. ✅ استخدام OptimizedLoadingWidget
3. ✅ تحسين استعلامات Firestore
4. ✅ إضافة mounted checks

### **أولوية متوسطة:**
1. 🔄 تحسين تحميل الصور
2. 🔄 استخدام StreamBuilder للبيانات المتغيرة
3. 🔄 إضافة تخزين مؤقت محلي

### **أولوية منخفضة:**
1. 📝 تحسين بناء Widgets
2. 📝 إضافة lazy loading
3. 📝 تحسين استخدام الذاكرة

## 🎯 النتائج المتوقعة

### **قبل التحسين:**
- ⏱️ وقت تحميل: 5-10 ثواني
- 🔄 إعادة تحميل متكرر
- 📱 تجربة مستخدم بطيئة

### **بعد التحسين:**
- ⚡ وقت تحميل: 1-3 ثواني
- 💾 تخزين مؤقت ذكي
- 🚀 تجربة مستخدم سلسة

## 🔧 كيفية التطبيق

### **1. استبدال FutureBuilder:**
```dart
// في كل صفحة، استبدل
FutureBuilder -> OptimizedFutureBuilder
```

### **2. تحسين استعلامات Firestore:**
```dart
// استخدم استعلامات محسنة
// أضف timeout
// استخدم where بدلاً من loops
```

### **3. إضافة loading widgets محسنة:**
```dart
// استبدل
CircularProgressIndicator() -> OptimizedLoadingWidget()
```

## 📊 مراقبة الأداء

### **أدوات المراقبة:**
- Flutter Inspector
- Performance Overlay
- Firebase Performance Monitoring

### **مؤشرات الأداء:**
- وقت تحميل الصفحة
- عدد استعلامات Firestore
- استخدام الذاكرة
- معدل الأخطاء
