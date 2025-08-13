import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

class AdminBookingsScreen extends StatefulWidget {
  final String centerId;
  final String? centerName;

  const AdminBookingsScreen({
    super.key,
    required this.centerId,
    this.centerName,
  });

  @override
  State<AdminBookingsScreen> createState() => _AdminBookingsScreenState();
}

class _AdminBookingsScreenState extends State<AdminBookingsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'all'; // all, today, upcoming, past

  Future<List<Map<String, dynamic>>> fetchAllBookings() async {
    try {
      // جلب جميع التخصصات
      final specializationsSnapshot = await FirebaseFirestore.instance
          .collection('medicalFacilities')
          .doc(widget.centerId)
          .collection('specializations')
          .get();

      List<Map<String, dynamic>> allBookings = [];
      
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
        
        // البحث في كل طبيب
        for (var doctorDoc in doctorsSnapshot.docs) {
          final doctorData = doctorDoc.data();
          final doctorName = doctorData['docName'] ?? 'طبيب غير معروف';
          
          final appointmentsSnapshot = await FirebaseFirestore.instance
              .collection('medicalFacilities')
              .doc(widget.centerId)
              .collection('specializations')
              .doc(specDoc.id)
              .collection('doctors')
              .doc(doctorDoc.id)
              .collection('appointments')
              .get();
          
          for (var appointmentDoc in appointmentsSnapshot.docs) {
            final appointmentData = appointmentDoc.data();
            
            // إضافة معلومات إضافية لكل حجز
            appointmentData['doctorName'] = doctorName;
            appointmentData['specialization'] = specializationName;
            appointmentData['doctorId'] = doctorDoc.id;
            appointmentData['specializationId'] = specDoc.id;
            appointmentData['appointmentId'] = appointmentDoc.id;
            allBookings.add(appointmentData);
          }
        }
      }
      
      return allBookings;
    } catch (e) {
      return [];
    }
  }

  List<Map<String, dynamic>> filterBookings(List<Map<String, dynamic>> bookings) {
    List<Map<String, dynamic>> filteredBookings = bookings;
    
    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      filteredBookings = filteredBookings.where((booking) {
        final doctorName = booking['doctorName']?.toString().toLowerCase() ?? '';
        final patientName = booking['patientName']?.toString().toLowerCase() ?? '';
        final specialization = booking['specialization']?.toString().toLowerCase() ?? '';
        
        return doctorName.contains(_searchQuery.toLowerCase()) ||
               patientName.contains(_searchQuery.toLowerCase()) ||
               specialization.contains(_searchQuery.toLowerCase());
      }).toList();
    }
    
    // Filter by date
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    switch (_selectedFilter) {
      case 'today':
        filteredBookings = filteredBookings.where((booking) {
          final bookingDate = DateTime.tryParse(booking['date'] ?? '');
          return bookingDate != null && 
                 DateTime(bookingDate.year, bookingDate.month, bookingDate.day) == today;
        }).toList();
        break;
      case 'upcoming':
        filteredBookings = filteredBookings.where((booking) {
          final bookingDate = DateTime.tryParse(booking['date'] ?? '');
          return bookingDate != null && bookingDate.isAfter(today);
        }).toList();
        break;
      case 'past':
        filteredBookings = filteredBookings.where((booking) {
          final bookingDate = DateTime.tryParse(booking['date'] ?? '');
          return bookingDate != null && bookingDate.isBefore(today);
        }).toList();
        break;
    }
    
    return filteredBookings;
  }

  String formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return intl.DateFormat('EEEE, yyyy/MM/dd', 'ar').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  String formatTime(String timeStr) {
    return timeStr;
  }

  String getPeriodText(String period) {
    switch (period) {
      case 'morning':
        return 'صباحاً';
      case 'evening':
        return 'مساءً';
      default:
        return period;
    }
  }

  Color getStatusColor(String dateStr) {
    try {
      final bookingDate = DateTime.parse(dateStr);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final bookingDay = DateTime(bookingDate.year, bookingDate.month, bookingDate.day);
      
      if (bookingDay.isBefore(today)) {
        return Colors.grey; // Past
      } else if (bookingDay == today) {
        return Colors.orange; // Today
      } else {
        return Colors.green; // Upcoming
      }
    } catch (e) {
      return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.centerName != null ? 'الحجوزات - ${widget.centerName}' : 'الحجوزات',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          backgroundColor: const Color.fromARGB(255, 78, 17, 175),
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                setState(() {});
              },
            ),
          ],
        ),
        body: Column(
          children: [
            // Search and filter section
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.grey[50],
              child: Column(
                children: [
                  // Search bar
                  TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'البحث في الحجوزات...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Filter buttons
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('الكل', 'all'),
                        const SizedBox(width: 8),
                        _buildFilterChip('اليوم', 'today'),
                        const SizedBox(width: 8),
                        _buildFilterChip('القادمة', 'upcoming'),
                        const SizedBox(width: 8),
                        _buildFilterChip('السابقة', 'past'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Bookings list
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: fetchAllBookings(),
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
                            'حدث خطأ في تحميل الحجوزات',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final bookings = snapshot.data ?? [];
                  final filteredBookings = filterBookings(bookings);

                                    if (filteredBookings.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _searchQuery.isEmpty ? Icons.calendar_today : Icons.search_off,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isEmpty 
                                ? 'لا توجد حجوزات حالياً'
                                : 'لم يتم العثور على حجوزات تطابق البحث',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredBookings.length,
                    itemBuilder: (context, index) {
                      final booking = filteredBookings[index];
                      final doctorName = booking['doctorName'] ?? 'طبيب غير معروف';
                      final specialization = booking['specialization'] ?? 'تخصص غير معروف';
                      final patientName = booking['patientName'] ?? 'مريض غير معروف';
                      final patientPhone = booking['patiantPhone'] ?? 'غير محدد';
                      final date = booking['date'] ?? '';
                      final time = booking['time'] ?? '';
                      final period = booking['period'] ?? '';

                                             return Container(
                         margin: const EdgeInsets.only(bottom: 12),
                         decoration: BoxDecoration(
                           color: Colors.grey[50],
                           borderRadius: BorderRadius.circular(16),
                           border: Border.all(
                             color: Colors.grey[300]!,
                             width: 1,
                           ),
                           boxShadow: [
                             BoxShadow(
                               color: Colors.grey.withOpacity(0.1),
                               spreadRadius: 1,
                               blurRadius: 8,
                               offset: const Offset(0, 2),
                             ),
                           ],
                         ),
                         child: Padding(
                           padding: const EdgeInsets.all(16),
                           child: Row(
                             children: [
                               // Content
                               Expanded(
                                 child: Column(
                                   crossAxisAlignment: CrossAxisAlignment.start,
                                   children: [
                                     // Patient name (main title)
                                     Row(
                                       children: [
                                         Icon(
                                           Icons.person,
                                           size: 18,
                                           color: const Color.fromARGB(255, 78, 17, 175),
                                         ),
                                         const SizedBox(width: 8),
                                         Expanded(
                                           child: Text(
                                             patientName,
                                             style: const TextStyle(
                                               fontSize: 16,
                                               fontWeight: FontWeight.bold,
                                               color: Colors.black87,
                                             ),
                                           ),
                                         ),
                                       ],
                                     ),
                                     const SizedBox(height: 8),
                                     
                                     // Doctor name and specialization (subtitle)
                                     Row(
                                       children: [
                                         Icon(
                                           Icons.medical_services,
                                           size: 16,
                                           color: const Color.fromARGB(255, 78, 17, 175),
                                         ),
                                         const SizedBox(width: 8),
                                         Expanded(
                                           child: Text(
                                             '$doctorName - $specialization',
                                             style: TextStyle(
                                               fontSize: 14,
                                               color: Colors.grey[600],
                                             ),
                                           ),
                                         ),
                                       ],
                                     ),
                                     const SizedBox(height: 8),
                                     
                                     // Date and time (simple text)
                                     Row(
                                       children: [
                                         Icon(
                                           Icons.calendar_today,
                                           size: 16,
                                           color: const Color.fromARGB(255, 78, 17, 175),
                                         ),
                                         const SizedBox(width: 8),
                                         Expanded(
                                           child: Text(
                                             '${formatDate(date)} - ${formatTime(time)} ${getPeriodText(period)}',
                                             style: TextStyle(
                                               fontSize: 12,
                                               color: Colors.grey[500],
                                             ),
                                           ),
                                         ),
                                       ],
                                     ),
                                   ],
                                 ),
                               ),
                               
                               // Status badge
                               Container(
                                 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                 decoration: BoxDecoration(
                                   color: getStatusColor(date).withOpacity(0.1),
                                   borderRadius: BorderRadius.circular(12),
                                   border: Border.all(
                                     color: getStatusColor(date).withOpacity(0.3),
                                   ),
                                 ),
                                 child: Text(
                                   getStatusColor(date) == Colors.grey ? 'سابقة' :
                                   getStatusColor(date) == Colors.orange ? 'اليوم' : 'قادمة',
                                   style: TextStyle(
                                     fontSize: 10,
                                     color: getStatusColor(date),
                                     fontWeight: FontWeight.bold,
                                   ),
                                 ),
                               ),
                             ],
                           ),
                         ),
                       );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = value;
        });
      },
      selectedColor: const Color.fromARGB(255, 78, 17, 175).withOpacity(0.2),
      checkmarkColor: const Color.fromARGB(255, 78, 17, 175),
      labelStyle: TextStyle(
        color: isSelected ? const Color.fromARGB(255, 78, 17, 175) : Colors.grey[600],
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
}
