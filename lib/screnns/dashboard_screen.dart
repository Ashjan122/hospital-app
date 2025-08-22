import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hospital_app/screnns/login_screen.dart';
import 'package:hospital_app/screnns/admin_doctors_screen.dart';
import 'package:hospital_app/screnns/admin_specialties_screen.dart';
import 'package:hospital_app/screnns/admin_doctors_schedule_screen.dart';
import 'package:hospital_app/screnns/admin_bookings_screen.dart';
import 'package:hospital_app/screnns/admin_users_screen.dart';
import 'package:hospital_app/screnns/admin_insurance_companies_screen.dart';
import 'package:hospital_app/screnns/about_screen.dart';

class DashboardScreen extends StatelessWidget {
  final String? centerId;
  final String? centerName;

  const DashboardScreen({
    super.key,
    this.centerId,
    this.centerName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          centerName != null ? 'لوحة تحكم $centerName' : 'لوحة التحكم',
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
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const AboutScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
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
      body: Container(
        color: Colors.white,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Welcome section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      
                      Text(
                        centerName != null ? 'مرحباً بك في $centerName' : 'مرحباً بك، المدير!',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color.fromARGB(255, 78, 17, 175),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'إدارة عمليات المستشفى',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Grid section
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    children: [
                      _buildDashboardCard(
                        context,
                        'الأطباء',
                        Icons.medical_services,
                        const Color.fromARGB(255, 78, 17, 175),
                        () {
                          if (centerId != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AdminDoctorsScreen(
                                  centerId: centerId!,
                                  centerName: centerName,
                                ),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('يرجى تسجيل الدخول أولاً'),
                                backgroundColor: Color.fromARGB(255, 78, 17, 175),
                              ),
                            );
                          }
                        },
                      ),
                      _buildDashboardCard(
                        context,
                        'التخصصات',
                        Icons.medical_services,
                        const Color.fromARGB(255, 78, 17, 175),
                        () {
                          if (centerId != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AdminSpecialtiesScreen(
                                  centerId: centerId!,
                                  centerName: centerName,
                                ),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('يرجى تسجيل الدخول أولاً'),
                                backgroundColor: Color.fromARGB(255, 78, 17, 175),
                              ),
                            );
                          }
                        },
                      ),
                      _buildDashboardCard(
                        context,
                        'شركات التأمين',
                        Icons.security,
                        const Color.fromARGB(255, 78, 17, 175),
                        () {
                          if (centerId != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AdminInsuranceCompaniesScreen(
                                  centerId: centerId!,
                                  centerName: centerName,
                                ),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('يرجى تسجيل الدخول أولاً'),
                                backgroundColor: Color.fromARGB(255, 78, 17, 175),
                              ),
                            );
                          }
                        },
                      ),
                      _buildDashboardCard(
                        context,
                        'جدول الأطباء',
                        Icons.schedule,
                        const Color.fromARGB(255, 78, 17, 175),
                        () {
                          if (centerId != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AdminDoctorsScheduleScreen(
                                  centerId: centerId!,
                                  centerName: centerName,
                                ),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('يرجى تسجيل الدخول أولاً'),
                                backgroundColor: Color.fromARGB(255, 78, 17, 175),
                              ),
                            );
                          }
                        },
                      ),
                      _buildDashboardCard(
                        context,
                        'المستخدمين',
                        Icons.people,
                        const Color.fromARGB(255, 78, 17, 175),
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AdminUsersScreen(),
                            ),
                          );
                        },
                      ),
                      _buildDashboardCard(
                        context,
                        'الحجوزات',
                        Icons.calendar_today,
                        const Color.fromARGB(255, 78, 17, 175),
                        () {
                          if (centerId != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AdminBookingsScreen(
                                  centerId: centerId!,
                                  centerName: centerName,
                                ),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('يرجى تسجيل الدخول أولاً'),
                                backgroundColor: Color.fromARGB(255, 78, 17, 175),
                              ),
                            );
                          }
                        },
                      ),
                      _buildDashboardCard(
                        context,
                        'التقارير',
                        Icons.analytics,
                        const Color.fromARGB(255, 78, 17, 175),
                        () {
                          if (centerId != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('التقارير - $centerName'),
                                backgroundColor: const Color.fromARGB(255, 78, 17, 175),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('التقارير قريباً'),
                                backgroundColor: Color.fromARGB(255, 78, 17, 175),
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: color.withAlpha(26),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Icon(
                icon,
                size: 30,
                color: color,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'اضغط للوصول',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
