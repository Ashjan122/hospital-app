import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hospital_app/screnns/specialties_screen.dart';
import 'package:hospital_app/screnns/login_screen.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class HospitalScreen extends StatefulWidget {
  const HospitalScreen({super.key});

  @override
  State<HospitalScreen> createState() => _HospitalScreenState();
}

class _HospitalScreenState extends State<HospitalScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<QueryDocumentSnapshot> _allFacilities = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();

    
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('📩 رسالة أثناء فتح التطبيق');
      print('🔹 البيانات: ${message.data}');

      if (message.notification != null) {
        print('🔔 إشعار: ${message.notification!.title}');
      }
    });

    
    FirebaseMessaging.instance.getToken().then((token) {
      print('📱 توكن الجهاز: $token');
      
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<QueryDocumentSnapshot>> fetchFacilities() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('medicalFacilities')
        .orderBy('available', descending: true)
        .get();

    _allFacilities = snapshot.docs;
    return snapshot.docs;
  }

  List<QueryDocumentSnapshot> getFilteredFacilities() {
    if (_searchQuery.isEmpty) {
      return _allFacilities;
    }
    
    return _allFacilities.where((facility) {
      final name = facility['name']?.toString().toLowerCase() ?? '';
      final searchLower = _searchQuery.toLowerCase();
      
      return name.contains(searchLower);
    }).toList();
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        leading: _isSearching
            ? IconButton(
                onPressed: () {
                  setState(() {
                    _isSearching = false;
                    _searchQuery = '';
                    _searchController.clear();
                  });
                },
                icon: Icon(Icons.close, color: Color.fromARGB(255, 78, 17, 175)),
              )
            : IconButton(
                onPressed: () {
                  setState(() {
                    _isSearching = true;
                  });
                },
                icon: Icon(Icons.search, color: Color.fromARGB(255, 78, 17, 175)),
              ),
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
                  hintText: 'البحث عن مرافق طبية...',
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
                "المرافق الطبية",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: const Color.fromARGB(255, 78, 17, 175),
                  fontSize: 30,
                ),
              ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Color.fromARGB(255, 78, 17, 175)),
            onPressed: () async {
              // Clear saved login data
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();

              // Navigate to login screen
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
      body: FutureBuilder<List<QueryDocumentSnapshot>>(
        future: fetchFacilities(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text("لا توجد بيانات"));
          }

          final facilities = _searchQuery.isEmpty ? snapshot.data! : getFilteredFacilities();

          return Padding(
            padding: const EdgeInsets.all(12.0),
            child: _searchQuery.isNotEmpty && facilities.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'لا يوجد مرافق تطابق البحث',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: facilities.length,
                    itemBuilder: (context, index) {
                      final doc = facilities[index];
                final name = doc['name'] ?? '';
                final isAvailable = doc['available'] ?? false;

                return InkWell(
                  onTap: () {
                    if (isAvailable) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SpecialtiesScreen(
                            facilityId: doc.id,
                          ),
                        ),
                      );
                    }
                  },
                  child: Container(
                    margin: EdgeInsets.symmetric(vertical: 10),
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.3),
                          blurRadius: 10,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.medication,
                          size: 40,
                          color: isAvailable
                              ? Color.fromARGB(255, 78, 17, 175)
                              : Colors.grey,
                        ),
                        SizedBox(height: 10),
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isAvailable ? Colors.black : Colors.grey,
                          ),
                        ),
                        if (!isAvailable)
                          Text(
                            'قريبا',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 20,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
