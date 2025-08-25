import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:hospital_app/screnns/doctors_screen.dart';
import 'package:hospital_app/widgets/optimized_loading_widget.dart';

class SpecialtiesScreen extends StatefulWidget {
  final String facilityId;
  const SpecialtiesScreen({super.key, required this.facilityId});

  @override
  State<SpecialtiesScreen> createState() => _SpecialtiesScreenState();
}

class _SpecialtiesScreenState extends State<SpecialtiesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<QueryDocumentSnapshot> _allSpecialties = [];
  bool _isSearching = false;

  Future<List<QueryDocumentSnapshot>> fetchSpecialties() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('medicalFacilities')
          .doc(widget.facilityId)
          .collection('specializations')
          .where('isActive', isEqualTo: true)
          .get()
          .timeout(const Duration(seconds: 8));

      _allSpecialties = snapshot.docs;
      return snapshot.docs;
    } catch (e) {
      print('خطأ في تحميل التخصصات: $e');
      return [];
    }
  }

  List<QueryDocumentSnapshot> getFilteredSpecialties() {
    if (_searchQuery.isEmpty) {
      return _allSpecialties;
    }
    
    return _allSpecialties.where((specialty) {
      final data = specialty.data() as Map<String, dynamic>;
      final specName = data['specName']?.toString().toLowerCase() ?? '';
      final searchLower = _searchQuery.toLowerCase();
      
      return specName.contains(searchLower);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          actions: [
            _isSearching
                ? IconButton(
                    onPressed: () {
                      setState(() {
                        _isSearching = false;
                        _searchQuery = '';
                        _searchController.clear();
                      });
                    },
                    icon: Icon(Icons.close, color: Color(0xFF2FBDAF)),
                  )
                : IconButton(
                    onPressed: () {
                      setState(() {
                        _isSearching = true;
                      });
                    },
                    icon: Icon(Icons.search, color: Color(0xFF2FBDAF)),
                  ),
          ],
          title: _isSearching
              ? TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'البحث عن تخصص طبي...',
                    border: InputBorder.none,
                    hintStyle: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 16,
                    ),
                  ),
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                  ),
                )
              : Text(
                  "التخصصات الطبية",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2FBDAF),
                    fontSize: 30,
                  ),
                ),
        ),
        body: SafeArea(
          child: FutureBuilder<List<QueryDocumentSnapshot>>(
            future: fetchSpecialties(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const OptimizedLoadingWidget(
                  message: 'جاري تحميل التخصصات...',
                  color: Color(0xFF2FBDAF),
                );
              }

              final specialties = _searchQuery.isEmpty ? snapshot.data ?? [] : getFilteredSpecialties();
              if (specialties.isEmpty) {
                return Center(
                  child: _searchQuery.isNotEmpty
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'لا يوجد تخصصات تطابق البحث',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.medical_services_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'لا توجد تخصصات حالياً',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                );
              }

              return ListView.builder(
                itemCount: specialties.length,
                itemBuilder: (context, index) {
                  final doc = specialties[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final specName = data['specName'] ?? 'تخصص غير معروف';
                  final specId = doc.id;

                  return InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DoctorsScreen(
                            facilityId: widget.facilityId,
                            specId: specId,
                          ),
                        ),
                      );
                    },
                    child: SizedBox(
                      width: 300,
                      height: 100,
                      child: Card(
                        elevation: 6,
                        margin: EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ListTile(
                          leading: Icon(
                            Icons.medical_services,
                            color: Color(0xFF2FBDAF),
                          ),
                          title: Text(
                            specName,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          trailing: Icon(Icons.arrow_forward_ios, size: 16),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}