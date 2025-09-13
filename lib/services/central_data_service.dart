import 'package:cloud_firestore/cloud_firestore.dart';

class CentralDataService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Cache للبيانات
  static final Map<String, List<Map<String, dynamic>>> _searchCache = {};
  static final Map<String, DateTime> _cacheTimestamps = {};
  
  // Cache للمراكز
  static List<Map<String, dynamic>>? _cachedFacilities;
  static DateTime? _facilitiesCacheTime;
  static const Duration _dataCacheExpiry = Duration(hours: 1);
  
  // Cache شامل للبحث السريع
  static List<Map<String, dynamic>>? _allDataCache;
  static DateTime? _allDataCacheTime;

  // دوال إدارة الـ Cache


  static void _clearCache() {
    _searchCache.clear();
    _cacheTimestamps.clear();
  }

  // دالة لمسح الـ Cache يدوياً
  static void clearAllCache() {
    _clearCache();
    _cachedFacilities = null;
    _facilitiesCacheTime = null;
    _allDataCache = null;
    _allDataCacheTime = null;
    print('تم مسح جميع الـ Cache');
  }

  // جلب جميع البيانات للبحث المحلي السريع
  static Future<List<Map<String, dynamic>>> _getAllDataForSearch() async {
    if (_allDataCache != null && 
        _allDataCacheTime != null && 
        DateTime.now().difference(_allDataCacheTime!) < _dataCacheExpiry) {
      return _allDataCache!;
    }
    
    print('تحميل البيانات للبحث السريع...');
    final allData = <Map<String, dynamic>>[];
    
    final facilities = await _getCachedFacilities();
    final activeFacilities = facilities.where((f) => f['isActive'] == true).toList();
    final facilitiesToSearch = activeFacilities.isEmpty ? facilities : activeFacilities;
    
    // تحميل متوازي للسرعة
    final futures = <Future>[];
    
    for (final facility in facilitiesToSearch) {
      final facilityName = facility['name'] as String;
      final facilityId = facility['id'] as String;
      
      futures.add(_loadFacilityData(facility, facilityName, facilityId, allData));
    }
    
    // انتظار تحميل جميع البيانات
    await Future.wait(futures);
    
    _allDataCache = allData;
    _allDataCacheTime = DateTime.now();
    print('تم تحميل ${allData.length} عنصر للبحث السريع');
    return allData;
  }
  
  static Future<void> _loadFacilityData(
    Map<String, dynamic> facility, 
    String facilityName, 
    String facilityId, 
    List<Map<String, dynamic>> allData
  ) async {
    try {
      final facilityRef = facility['reference'] as DocumentReference;
      final specializationsSnapshot = await facilityRef
          .collection('specializations')
          .get()
          .timeout(const Duration(seconds: 1));
      
      for (final specDoc in specializationsSnapshot.docs) {
        final specData = specDoc.data();
        final specName = specData['specName'] ?? '';
        final specId = specDoc.id;
        
        // إضافة التخصص
        allData.add({
          'type': 'specialty',
          'id': specId,
          'name': specName,
          'description': specData['description'] ?? '',
          'centerName': facilityName,
          'searchMatch': 'name',
        });
        
        // إضافة الأطباء
        try {
          final doctorsSnapshot = await specDoc.reference
              .collection('doctors')
              .get()
              .timeout(const Duration(milliseconds: 500));
          
          for (final doctorDoc in doctorsSnapshot.docs) {
            final doctorData = doctorDoc.data();
            final doctorName = doctorData['docName'] ?? '';
            final doctorId = doctorDoc.id;
            
            // طباعة بيانات الطبيب للتأكد من workingSchedule
            print('طبيب: $doctorName');
            print('workingSchedule من قاعدة البيانات: ${doctorData['workingSchedule']}');
            print('نوع workingSchedule: ${doctorData['workingSchedule'].runtimeType}');
            
            // جلب workingSchedule من قاعدة البيانات
            Map<String, dynamic> workingSchedule = {};
            
            // محاولة جلب workingSchedule من البيانات
            if (doctorData['workingSchedule'] != null) {
              if (doctorData['workingSchedule'] is Map<String, dynamic>) {
                workingSchedule = Map<String, dynamic>.from(doctorData['workingSchedule']);
              } else if (doctorData['workingSchedule'] is Map) {
                workingSchedule = Map<String, dynamic>.from(doctorData['workingSchedule'] as Map);
              }
            }
            
            print('workingSchedule بعد التحويل: $workingSchedule');
            print('workingSchedule.isEmpty: ${workingSchedule.isEmpty}');
            
            // جدول عمل افتراضي في حالة عدم وجود workingSchedule
            if (workingSchedule.isEmpty) {
              workingSchedule = {
                'السبت': {
                  'morning': {'start': '09:00', 'end': '12:00', 'capacity': 20},
                  'evening': {'start': '16:00', 'end': '20:00', 'capacity': 20}
                },
                'الأحد': {
                  'morning': {'start': '09:00', 'end': '12:00', 'capacity': 20},
                  'evening': {'start': '16:00', 'end': '20:00', 'capacity': 20}
                },
                'الاثنين': {
                  'morning': {'start': '09:00', 'end': '12:00', 'capacity': 20},
                  'evening': {'start': '16:00', 'end': '20:00', 'capacity': 20}
                },
                'الثلاثاء': {
                  'morning': {'start': '09:00', 'end': '12:00', 'capacity': 20},
                  'evening': {'start': '16:00', 'end': '20:00', 'capacity': 20}
                },
                'الأربعاء': {
                  'morning': {'start': '09:00', 'end': '12:00', 'capacity': 20},
                  'evening': {'start': '16:00', 'end': '20:00', 'capacity': 20}
                },
                'الخميس': {
                  'morning': {'start': '09:00', 'end': '12:00', 'capacity': 20},
                  'evening': {'start': '16:00', 'end': '20:00', 'capacity': 20}
                },
                'الجمعة': {
                  'morning': {'start': '09:00', 'end': '12:00', 'capacity': 20},
                  'evening': {'start': '16:00', 'end': '20:00', 'capacity': 20}
                }
              };
              print('تم استخدام جدول عمل افتراضي للطبيب: $doctorName');
            }
            
            allData.add({
              'type': 'doctor',
              'id': doctorId,
              'name': doctorName,
              'specialization': specName,
              'centerName': facilityName,
              'phoneNumber': doctorData['phoneNumber'] ?? '',
              'photoUrl': doctorData['photoUrl'] ?? '',
              'morningPatientLimit': doctorData['morningPatientLimit'] ?? 20,
              'eveningPatientLimit': doctorData['eveningPatientLimit'] ?? 20,
              'searchMatch': 'name',
              'facilityId': facilityId,
              'specializationId': specId,
              'workingSchedule': workingSchedule,
            });
          }
        } catch (e) {
          // تجاهل الأخطاء
        }
      }
    } catch (e) {
      // تجاهل الأخطاء
    }
  }

  // جلب المراكز مع Cache
  static Future<List<Map<String, dynamic>>> _getCachedFacilities() async {
    if (_cachedFacilities != null && 
        _facilitiesCacheTime != null && 
        DateTime.now().difference(_facilitiesCacheTime!) < _dataCacheExpiry) {
      print('جلب المراكز من Cache: ${_cachedFacilities!.length}');
      return _cachedFacilities!;
    }

    print('جلب المراكز من قاعدة البيانات...');
    final snapshot = await _firestore
        .collection('medicalFacilities')
        .get()
        .timeout(const Duration(seconds: 8));

    _cachedFacilities = snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'name': data['name'] ?? '',
        'description': data['description'] ?? '',
        'address': data['address'] ?? '',
        'phoneNumber': data['phoneNumber'] ?? '',
        'isActive': data['isActive'] ?? false,
        'reference': doc.reference,
      };
    }).toList();

    _facilitiesCacheTime = DateTime.now();
    print('تم حفظ ${_cachedFacilities!.length} مركز في Cache');
    return _cachedFacilities!;
  }

  // جلب جميع التخصصات الطبية من المجموعة المركزية
  static Future<List<Map<String, dynamic>>> getAllSpecialties() async {
    try {
      final snapshot = await _firestore
          .collection('medicalSpecialties')
          .get()
          .timeout(const Duration(seconds: 8));

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'] ?? doc.id,
          'description': data['description'] ?? '',
        };
      }).toList();
    } catch (e) {
      print('خطأ في جلب التخصصات: $e');
      return [];
    }
  }

  // جلب جميع الأطباء من المجموعة المركزية
  static Future<List<Map<String, dynamic>>> getAllDoctors() async {
    try {
      final snapshot = await _firestore
          .collection('allDoctors')
          .get()
          .timeout(const Duration(seconds: 8));

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'] ?? doc.id,
          'specialization': data['specialization'] ?? '',
          'phoneNumber': data['phoneNumber'] ?? '',
          'photoUrl': data['photoUrl'] ?? '',
        };
      }).toList();
    } catch (e) {
      print('خطأ في جلب الأطباء: $e');
      return [];
    }
  }

  // جلب جميع شركات التأمين من المجموعة المركزية
  static Future<List<Map<String, dynamic>>> getAllInsuranceCompanies() async {
    try {
      final snapshot = await _firestore
          .collection('insuranceCompanies')
          .get()
          .timeout(const Duration(seconds: 8));

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'] ?? doc.id,
          'description': data['description'] ?? '',
          'phone': data['phone'] ?? '',
        };
      }).toList();
    } catch (e) {
      print('خطأ في جلب شركات التأمين: $e');
      return [];
    }
  }

  // إضافة تخصص إلى مركز معين (حفظ الـ ID فقط)
  static Future<void> addSpecialtyToCenter(String centerId, String specialtyId) async {
    try {
      // جلب بيانات التخصص من المجموعة المركزية
      final specialtyDoc = await _firestore
          .collection('medicalSpecialties')
          .doc(specialtyId)
          .get();

      if (specialtyDoc.exists) {
        final specialtyData = specialtyDoc.data()!;
        
        // إضافة التخصص إلى المركز مع حفظ الـ ID المرجعي
        await _firestore
            .collection('medicalFacilities')
            .doc(centerId)
            .collection('specializations')
            .doc(specialtyId)
            .set({
          'centralSpecialtyId': specialtyId,
          'specName': specialtyData['name'] ?? specialtyId,
          'description': specialtyData['description'] ?? '',
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('خطأ في إضافة التخصص للمركز: $e');
      rethrow;
    }
  }

  // إضافة طبيب إلى مركز معين (حفظ الـ ID فقط)
  static Future<void> addDoctorToCenter(
    String centerId, 
    String specializationId, 
    String doctorId,
    Map<String, dynamic> additionalData,
  ) async {
    try {
      // جلب بيانات الطبيب من المجموعة المركزية
      final doctorDoc = await _firestore
          .collection('allDoctors')
          .doc(doctorId)
          .get();

      if (doctorDoc.exists) {
        final doctorData = doctorDoc.data()!;
        
        // إضافة الطبيب إلى المركز مع حفظ الـ ID المرجعي
        await _firestore
            .collection('medicalFacilities')
            .doc(centerId)
            .collection('specializations')
            .doc(specializationId)
            .collection('doctors')
            .doc(doctorId)
            .set({
          'centralDoctorId': doctorId,
          'docName': doctorData['name'] ?? doctorId,
          'phoneNumber': doctorData['phoneNumber'] ?? '',
          'photoUrl': doctorData['photoUrl'] ?? '',
          'specialization': doctorData['specialization'] ?? '',
          'morningPatientLimit': additionalData['morningPatientLimit'] ?? 20,
          'eveningPatientLimit': additionalData['eveningPatientLimit'] ?? 20,
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('خطأ في إضافة الطبيب للمركز: $e');
      rethrow;
    }
  }

  // إضافة شركة تأمين إلى مركز معين (حفظ الـ ID فقط)
  static Future<void> addInsuranceCompanyToCenter(String centerId, String insuranceId) async {
    try {
      // جلب بيانات شركة التأمين من المجموعة المركزية
      final insuranceDoc = await _firestore
          .collection('insuranceCompanies')
          .doc(insuranceId)
          .get();

      if (insuranceDoc.exists) {
        final insuranceData = insuranceDoc.data()!;
        
        // إضافة شركة التأمين إلى المركز مع حفظ الـ ID المرجعي
        await _firestore
            .collection('medicalFacilities')
            .doc(centerId)
            .collection('insuranceCompanies')
            .doc(insuranceId)
            .set({
          'centralInsuranceId': insuranceId,
          'name': insuranceData['name'] ?? insuranceId,
          'description': insuranceData['description'] ?? '',
          'phone': insuranceData['phone'] ?? '',
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('خطأ في إضافة شركة التأمين للمركز: $e');
      rethrow;
    }
  }

  // ===== دوال إضافة بيانات تجريبية =====

  // إضافة تخصصات تجريبية
  static Future<void> addSampleSpecialties() async {
    try {
      final specialties = [
        {
          'id': 'cardiology',
          'name': 'أمراض القلب',
          'description': 'تخصص في تشخيص وعلاج أمراض القلب والأوعية الدموية',
        },
        {
          'id': 'neurology',
          'name': 'أمراض الأعصاب',
          'description': 'تخصص في تشخيص وعلاج أمراض الجهاز العصبي',
        },
        {
          'id': 'orthopedics',
          'name': 'جراحة العظام',
          'description': 'تخصص في تشخيص وعلاج أمراض العظام والمفاصل',
        },
        {
          'id': 'dermatology',
          'name': 'أمراض الجلد',
          'description': 'تخصص في تشخيص وعلاج أمراض الجلد',
        },
        {
          'id': 'pediatrics',
          'name': 'طب الأطفال',
          'description': 'تخصص في رعاية وعلاج الأطفال',
        },
      ];

      for (final specialty in specialties) {
        await _firestore
            .collection('medicalSpecialties')
            .doc(specialty['id'])
            .set(specialty);
      }

      print('تم إضافة التخصصات التجريبية بنجاح');
    } catch (e) {
      print('خطأ في إضافة التخصصات التجريبية: $e');
    }
  }

  // إضافة أطباء تجريبيين
  static Future<void> addSampleDoctors() async {
    try {
      final doctors = [
        {
          'id': 'dr_ahmed_ali',
          'name': 'د. أحمد علي',
          'specialization': 'cardiology',
          'phoneNumber': '+249123456789',
          'photoUrl': 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcQupVHd_oeqnkds0k3EjT1SX4ctwwblwYP2Uw&s',
        },
        {
          'id': 'dr_fatima_mohammed',
          'name': 'د. فاطمة محمد',
          'specialization': 'neurology',
          'phoneNumber': '+249123456790',
          'photoUrl': 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcQupVHd_oeqnkds0k3EjT1SX4ctwwblwYP2Uw&s',
        },
        {
          'id': 'dr_omar_hassan',
          'name': 'د. عمر حسن',
          'specialization': 'orthopedics',
          'phoneNumber': '+249123456791',
          'photoUrl': 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcQupVHd_oeqnkds0k3EjT1SX4ctwwblwYP2Uw&s',
        },
        {
          'id': 'dr_sara_ahmed',
          'name': 'د. سارة أحمد',
          'specialization': 'dermatology',
          'phoneNumber': '+249123456792',
          'photoUrl': 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcQupVHd_oeqnkds0k3EjT1SX4ctwwblwYP2Uw&s',
        },
        {
          'id': 'dr_khalid_omar',
          'name': 'د. خالد عمر',
          'specialization': 'pediatrics',
          'phoneNumber': '+249123456793',
          'photoUrl': 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcQupVHd_oeqnkds0k3EjT1SX4ctwwblwYP2Uw&s',
        },
      ];

      for (final doctor in doctors) {
        await _firestore
            .collection('allDoctors')
            .doc(doctor['id'])
            .set(doctor);
      }

      print('تم إضافة الأطباء التجريبيين بنجاح');
    } catch (e) {
      print('خطأ في إضافة الأطباء التجريبيين: $e');
    }
  }

  // إضافة شركات تأمين تجريبية
  static Future<void> addSampleInsuranceCompanies() async {
    try {
      final companies = [
        {
          'id': 'blue_cross',
          'name': 'بلو كروس',
          'description': 'شركة تأمين صحي رائدة في السودان',
          'phone': '+249123456794',
        },
        {
          'id': 'sudan_insurance',
          'name': 'شركة التأمين السودانية',
          'description': 'شركة تأمين وطنية شاملة',
          'phone': '+249123456795',
        },
        {
          'id': 'medical_insurance',
          'name': 'تأمين طبي',
          'description': 'تأمين صحي متخصص',
          'phone': '+249123456796',
        },
        {
          'id': 'health_care',
          'name': 'رعاية صحية',
          'description': 'شركة تأمين صحي حديثة',
          'phone': '+249123456797',
        },
      ];

      for (final company in companies) {
        await _firestore
            .collection('insuranceCompanies')
            .doc(company['id'])
            .set(company);
      }

      print('تم إضافة شركات التأمين التجريبية بنجاح');
    } catch (e) {
      print('خطأ في إضافة شركات التأمين التجريبية: $e');
    }
  }

  // إضافة جميع البيانات التجريبية
  static Future<void> addAllSampleData() async {
    try {
      await addSampleSpecialties();
      await addSampleDoctors();
      await addSampleInsuranceCompanies();
      print('تم إضافة جميع البيانات التجريبية بنجاح');
    } catch (e) {
      print('خطأ في إضافة البيانات التجريبية: $e');
    }
  }

  // البحث الفوري السريع مع Cache
  static Future<List<Map<String, dynamic>>> searchDoctorsAndSpecialties(String query) async {
    try {
      if (query.trim().isEmpty) return [];
      
      final searchQuery = query.toLowerCase().trim();
      
      // البحث الفوري بدون Cache للسرعة القصوى
      final allData = await _getAllDataForSearch();
      
      // بحث سريع ومحسن
      final results = <Map<String, dynamic>>[];
      
      for (final item in allData) {
        final type = item['type'] as String;
        
        // استبعاد المراكز الطبية من النتائج تماماً
        if (type == 'facility') continue;
        
        final name = (item['name'] as String).toLowerCase();
        final specialization = (item['specialization'] as String? ?? '').toLowerCase();
        
        // إذا كان البحث عن تخصص، اعرض الأطباء فقط (لا تعرض بطاقة التخصص نفسه)
        if (type == 'specialty' && name.contains(searchQuery)) continue;
        if (specialization.contains(searchQuery) && type == 'specialty') continue;
        
        // البحث السريع في اسم الطبيب والتخصص
        if (name.contains(searchQuery) || specialization.contains(searchQuery)) {
          results.add(item);
        }
      }
      
      return results;
    } catch (e) {
      print('خطأ في البحث: $e');
      return [];
    }
  }

  // فحص البيانات الموجودة
  static Future<void> checkExistingData() async {
    try {
      print('=== فحص البيانات الموجودة ===');
      
      // فحص المراكز الطبية
      final facilitiesSnapshot = await _firestore.collection('medicalFacilities').get();
      print('عدد المراكز الطبية: ${facilitiesSnapshot.docs.length}');
      for (final doc in facilitiesSnapshot.docs) {
        final data = doc.data();
        print('- ${doc.id}: ${data['name'] ?? 'بدون اسم'} (نشط: ${data['isActive'] ?? 'غير محدد'})');
      }
      
      // فحص التخصصات
      final specialtiesSnapshot = await _firestore.collection('medicalSpecialties').get();
      print('عدد التخصصات المركزية: ${specialtiesSnapshot.docs.length}');
      for (final doc in specialtiesSnapshot.docs) {
        print('- ${doc.id}: ${(doc.data()['name'] as String?) ?? 'بدون اسم'}');
      }
      
      // فحص الأطباء
      final doctorsSnapshot = await _firestore.collection('allDoctors').get();
      print('عدد الأطباء المركزيين: ${doctorsSnapshot.docs.length}');
      for (final doc in doctorsSnapshot.docs) {
        print('- ${doc.id}: ${(doc.data()['name'] as String?) ?? 'بدون اسم'}');
      }
      
      // فحص شركات التأمين
      final insuranceSnapshot = await _firestore.collection('insuranceCompanies').get();
      print('عدد شركات التأمين: ${insuranceSnapshot.docs.length}');
      for (final doc in insuranceSnapshot.docs) {
        print('- ${doc.id}: ${doc.data()['name'] ?? 'بدون اسم'}');
      }
      
    } catch (e) {
      print('خطأ في فحص البيانات: $e');
    }
  }

  // فحص هيكل قاعدة البيانات
  static Future<void> checkDatabaseStructure() async {
    try {
      print('=== فحص هيكل قاعدة البيانات ===');
      
      final facilitiesSnapshot = await _firestore.collection('medicalFacilities').get();
      print('عدد المراكز: ${facilitiesSnapshot.docs.length}');
      
      for (final facilityDoc in facilitiesSnapshot.docs) {
        final facilityData = facilityDoc.data();
        print('\nالمركز: ${facilityData['name']} (${facilityDoc.id})');
        
        // فحص التخصصات
        final specializationsSnapshot = await facilityDoc.reference
            .collection('specializations')
            .get();
        print('  التخصصات: ${specializationsSnapshot.docs.length}');
        
        for (final specDoc in specializationsSnapshot.docs) {
          final specData = specDoc.data();
          print('    - ${specData['specName']} (${specDoc.id})');
          
          // فحص الأطباء
          final doctorsSnapshot = await specDoc.reference
              .collection('doctors')
              .get();
          print('      الأطباء: ${doctorsSnapshot.docs.length}');
          
          for (final doctorDoc in doctorsSnapshot.docs) {
            final doctorData = doctorDoc.data();
            print('        - ${doctorData['docName']} (${doctorDoc.id})');
          }
        }
      }
    } catch (e) {
      print('خطأ في فحص هيكل قاعدة البيانات: $e');
    }
  }
}
