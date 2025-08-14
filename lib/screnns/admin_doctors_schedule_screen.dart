import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminDoctorsScheduleScreen extends StatefulWidget {
  final String centerId;
  final String? centerName;

  const AdminDoctorsScheduleScreen({
    super.key,
    required this.centerId,
    this.centerName,
  });

  @override
  State<AdminDoctorsScheduleScreen> createState() => _AdminDoctorsScheduleScreenState();
}

class _AdminDoctorsScheduleScreenState extends State<AdminDoctorsScheduleScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  Future<List<Map<String, dynamic>>> fetchAllDoctors() async {
    try {
      // جلب جميع التخصصات
      final specializationsSnapshot = await FirebaseFirestore.instance
          .collection('medicalFacilities')
          .doc(widget.centerId)
          .collection('specializations')
          .get();

      List<Map<String, dynamic>> allDoctors = [];
      
      // البحث في كل تخصص
      for (var specDoc in specializationsSnapshot.docs) {
        final specializationData = specDoc.data();
        final specializationName = specializationData['specName'] ?? specDoc.id;
        
        final doctorsSnapshot = await FirebaseFirestore.instance
            .collection('medicalFacilities')
            .doc(widget.centerId)
            .collection('specializations')
            .doc(specDoc.id)
            .collection('doctors')
            .get();
        
        for (var doctorDoc in doctorsSnapshot.docs) {
          final doctorData = doctorDoc.data();
          // إضافة معلومات إضافية لكل طبيب
          doctorData['specialization'] = specializationName;
          doctorData['doctorId'] = doctorDoc.id;
          doctorData['specializationId'] = specDoc.id;
          allDoctors.add(doctorData);
        }
      }
      
      return allDoctors;
    } catch (e) {
      print('Error fetching doctors: $e');
      return [];
    }
  }

  List<Map<String, dynamic>> filterDoctors(List<Map<String, dynamic>> doctors) {
    if (_searchQuery.isEmpty) return doctors;
    
    return doctors.where((doctorData) {
      final doctorName = doctorData['docName']?.toString().toLowerCase() ?? '';
      final specialization = doctorData['specialization']?.toString().toLowerCase() ?? '';
      
      return doctorName.contains(_searchQuery.toLowerCase()) ||
             specialization.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  String formatWorkingSchedule(Map<String, dynamic>? workingSchedule) {
    if (workingSchedule == null) return 'غير محدد';
    
    List<String> scheduleParts = [];
    
    // أيام الأسبوع بالعربية (كما هي مخزنة في قاعدة البيانات)
    final days = [
      'الأحد',
      'الاثنين', 
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت',
    ];
    
    days.forEach((arabicDay) {
      final daySchedule = workingSchedule[arabicDay];
      if (daySchedule != null) {
        final morning = daySchedule['morning'];
        final evening = daySchedule['evening'];
        
        if (morning != null) {
          final startTime = morning['start'] ?? '';
          final endTime = morning['end'] ?? '';
          if (startTime.isNotEmpty && endTime.isNotEmpty) {
            scheduleParts.add('$arabicDay (صباحاً): $startTime - $endTime');
          }
        }
        
        if (evening != null) {
          final startTime = evening['start'] ?? '';
          final endTime = evening['end'] ?? '';
          if (startTime.isNotEmpty && endTime.isNotEmpty) {
            scheduleParts.add('$arabicDay (مساءً): $startTime - $endTime');
          }
        }
      }
    });
    
    return scheduleParts.isEmpty ? 'غير محدد' : scheduleParts.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.centerName != null ? 'جدول الأطباء - ${widget.centerName}' : 'جدول الأطباء',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          backgroundColor: const Color.fromARGB(255, 78, 17, 175),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: Column(
          children: [
            // Search section
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.grey[50],
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'البحث في الأطباء...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
            ),
            
            // Weekly schedule table
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: fetchAllDoctors(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Color.fromARGB(255, 78, 17, 175),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Colors.red[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'حدث خطأ في تحميل جدول الأطباء',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final doctors = snapshot.data ?? [];
                  final filteredDoctors = filterDoctors(doctors);

                  if (filteredDoctors.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _searchQuery.isEmpty ? Icons.medical_services : Icons.search_off,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isEmpty 
                                ? 'لا يوجد أطباء حالياً'
                                : 'لم يتم العثور على أطباء يطابقون البحث',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: _buildWeeklyScheduleTable(filteredDoctors),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyScheduleTable(List<Map<String, dynamic>> doctors) {
    final days = [
      'الأحد',
      'الاثنين', 
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت',
    ];

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DataTable(
        headingTextStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Color.fromARGB(255, 78, 17, 175),
          fontSize: 12,
        ),
        dataTextStyle: const TextStyle(fontSize: 10),
        dataRowHeight: 80,
        headingRowHeight: 60,
        columns: [
          const DataColumn(label: Text('اليوم')),
          ...doctors.map((doctor) {
            final doctorName = doctor['docName'] ?? 'طبيب غير معروف';
            final specialization = doctor['specialization'] ?? 'تخصص غير معروف';
            return DataColumn(
              label: Container(
                constraints: const BoxConstraints(maxWidth: 100),
                child: Column(
                  children: [
                                         Text(
                       doctorName,
                       style: const TextStyle(
                         fontWeight: FontWeight.bold,
                         fontSize: 10,
                       ),
                       overflow: TextOverflow.ellipsis,
                       textAlign: TextAlign.center,
                     ),
                     Text(
                       specialization,
                       style: TextStyle(
                         fontSize: 8,
                         color: Colors.grey[600],
                       ),
                       overflow: TextOverflow.ellipsis,
                       textAlign: TextAlign.center,
                     ),
                  ],
                ),
              ),
            );
          }).toList(),
        ],
        rows: days.map((day) {
          return DataRow(
            cells: [
              DataCell(
                Container(
                  padding: const EdgeInsets.all(8),
                                     child: Text(
                     day,
                     style: const TextStyle(
                       fontWeight: FontWeight.bold,
                       fontSize: 12,
                       color: Color.fromARGB(255, 78, 17, 175),
                     ),
                   ),
                ),
              ),
              ...doctors.map((doctor) {
                final workingSchedule = doctor['workingSchedule'] as Map<String, dynamic>?;
                final daySchedule = workingSchedule?[day];
                String scheduleText = 'لا يوجد دوام';
                Color cellColor = Colors.grey[100]!;
                Color textColor = Colors.grey[600]!;

                if (daySchedule != null) {
                  final morning = daySchedule['morning'];
                  final evening = daySchedule['evening'];
                  List<String> periods = [];

                  if (morning != null) {
                    final startTime = morning['start'] ?? '';
                    final endTime = morning['end'] ?? '';
                    if (startTime.isNotEmpty && endTime.isNotEmpty) {
                      periods.add('صباحاً: $startTime-$endTime');
                    }
                  }

                  if (evening != null) {
                    final startTime = evening['start'] ?? '';
                    final endTime = evening['end'] ?? '';
                    if (startTime.isNotEmpty && endTime.isNotEmpty) {
                      periods.add('مساءً: $startTime-$endTime');
                    }
                  }

                  if (periods.isNotEmpty) {
                    scheduleText = periods.join('\n');
                    cellColor = const Color.fromARGB(255, 78, 17, 175).withOpacity(0.1);
                    textColor = const Color.fromARGB(255, 78, 17, 175);
                  }
                }

                return DataCell(
                  GestureDetector(
                    onTap: () => _showEditScheduleDialog(doctor, day),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: cellColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.grey[300]!,
                          width: 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                                                     Text(
                             scheduleText,
                             style: TextStyle(
                               fontSize: 9,
                               color: textColor,
                               height: 1.1,
                             ),
                             textAlign: TextAlign.center,
                           ),
                          const SizedBox(height: 4),
                          Icon(
                            Icons.edit,
                            size: 12,
                            color: Colors.grey[500],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ],
          );
        }).toList(),
      ),
    );
  }

  void _showEditScheduleDialog(Map<String, dynamic> doctor, String day) {
    final doctorName = doctor['docName'] ?? 'طبيب غير معروف';
    final workingSchedule = doctor['workingSchedule'] as Map<String, dynamic>? ?? {};
    final daySchedule = workingSchedule[day] ?? {};
    
    // تحديد الأوقات الافتراضية
    final morningStartController = TextEditingController(
      text: daySchedule['morning']?['start'] ?? '09:00'
    );
    final morningEndController = TextEditingController(
      text: daySchedule['morning']?['end'] ?? '12:00'
    );
    final eveningStartController = TextEditingController(
      text: daySchedule['evening']?['start'] ?? '18:00'
    );
    final eveningEndController = TextEditingController(
      text: daySchedule['evening']?['end'] ?? '23:00'
    );
    
    // تفعيل الفترات تلقائياً إذا لم تكن موجودة
    bool hasMorning = daySchedule['morning'] != null;
    bool hasEvening = daySchedule['evening'] != null;
    
    // إذا لم تكن هناك فترات محددة، تفعيل الفترة الصباحية تلقائياً
    if (!hasMorning && !hasEvening) {
      hasMorning = true;
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('تعديل جدول $doctorName - $day'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Morning shift
                Row(
                  children: [
                    Checkbox(
                      value: hasMorning,
                      onChanged: (value) {
                        setState(() {
                          hasMorning = value ?? false;
                          if (!hasMorning) {
                            morningStartController.clear();
                            morningEndController.clear();
                          } else {
                            // إعادة تعيين الأوقات الافتراضية إذا كانت فارغة
                            if (morningStartController.text.isEmpty) {
                              morningStartController.text = '09:00';
                            }
                            if (morningEndController.text.isEmpty) {
                              morningEndController.text = '12:00';
                            }
                          }
                        });
                      },
                    ),
                    const Text('الفترة الصباحية'),
                  ],
                ),
                if (hasMorning) ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: morningStartController,
                          decoration: const InputDecoration(
                            labelText: 'وقت البداية',
                            hintText: 'مثال: 09:00',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: morningEndController,
                          decoration: const InputDecoration(
                            labelText: 'وقت النهاية',
                            hintText: 'مثال: 12:00',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                
                // Evening shift
                Row(
                  children: [
                    Checkbox(
                      value: hasEvening,
                      onChanged: (value) {
                        setState(() {
                          hasEvening = value ?? false;
                          if (!hasEvening) {
                            eveningStartController.clear();
                            eveningEndController.clear();
                          } else {
                            // إعادة تعيين الأوقات الافتراضية إذا كانت فارغة
                            if (eveningStartController.text.isEmpty) {
                              eveningStartController.text = '18:00';
                            }
                            if (eveningEndController.text.isEmpty) {
                              eveningEndController.text = '23:00';
                            }
                          }
                        });
                      },
                    ),
                    const Text('الفترة المسائية'),
                  ],
                ),
                if (hasEvening) ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: eveningStartController,
                          decoration: const InputDecoration(
                            labelText: 'وقت البداية',
                            hintText: 'مثال: 18:00',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: eveningEndController,
                          decoration: const InputDecoration(
                            labelText: 'وقت النهاية',
                            hintText: 'مثال: 23:00',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () async {
                await _updateDoctorSchedule(
                  doctor,
                  day,
                  hasMorning,
                  hasEvening,
                  morningStartController.text,
                  morningEndController.text,
                  eveningStartController.text,
                  eveningEndController.text,
                );
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 78, 17, 175),
                foregroundColor: Colors.white,
              ),
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateDoctorSchedule(
    Map<String, dynamic> doctor,
    String day,
    bool hasMorning,
    bool hasEvening,
    String morningStart,
    String morningEnd,
    String eveningStart,
    String eveningEnd,
  ) async {
    try {
      final doctorId = doctor['doctorId'];
      final specializationId = doctor['specializationId'];
      final workingSchedule = doctor['workingSchedule'] as Map<String, dynamic>? ?? {};
      
      // Update the day schedule
      Map<String, dynamic> daySchedule = {};
      
      if (hasMorning && morningStart.isNotEmpty && morningEnd.isNotEmpty) {
        daySchedule['morning'] = {
          'start': morningStart,
          'end': morningEnd,
        };
      }
      
      if (hasEvening && eveningStart.isNotEmpty && eveningEnd.isNotEmpty) {
        daySchedule['evening'] = {
          'start': eveningStart,
          'end': eveningEnd,
        };
      }
      
      // Update the working schedule
      workingSchedule[day] = daySchedule.isEmpty ? null : daySchedule;
      
      // Remove empty days
      workingSchedule.removeWhere((key, value) => value == null);
      
      // Update in Firestore
      await FirebaseFirestore.instance
          .collection('medicalFacilities')
          .doc(widget.centerId)
          .collection('specializations')
          .doc(specializationId)
          .collection('doctors')
          .doc(doctorId)
          .update({
        'workingSchedule': workingSchedule,
      });

      // Refresh the UI
      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تحديث جدول العمل بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ في تحديث الجدول: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
