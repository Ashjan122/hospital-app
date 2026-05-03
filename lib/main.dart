import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hospital_app/firebase_options.dart';
import 'package:hospital_app/screnns/login_screen.dart';
import 'package:hospital_app/screnns/maintenance_screen.dart';
import 'package:hospital_app/screnns/patient_home_screen.dart';
import 'package:hospital_app/widgets/app_update_wrapper.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print("رسالة في الخلفية: ${message.messageId}");
}

Future<void> initializeFirebaseMessaging() async {
  final messaging = FirebaseMessaging.instance;

  await messaging.requestPermission(alert: true, badge: true, sound: true);

  String? token = await messaging.getToken();
  if (token != null) {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fcm_token', token);
  }

  messaging.onTokenRefresh.listen((newToken) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('fcm_token', newToken);
  });
}

/// ❌ خدمة قديمة (ما عاد نستخدمها في التشغيل الأساسي)
class AppStatusService {
  static Future<bool> isAppActive() async {
    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('appConfig')
              .doc('version')
              .get();

      return doc.data()?['isActive'] ?? true;
    } catch (e) {
      return true;
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await initializeFirebaseMessaging();

  runApp(const HospitalApp());
}

class HospitalApp extends StatelessWidget {
  const HospitalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(textTheme: GoogleFonts.tajawalTextTheme()),

      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(0.85)),
          child: child!,
        );
      },

      /// 🔥 هنا التعديل الحقيقي (Realtime)
      home: StreamBuilder<DocumentSnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('appConfig')
                .doc('version')
                .snapshots(),

        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          final data = snapshot.data?.data() as Map<String, dynamic>?;

          final isActive = data?['isActive'] ?? true;

          /// 🔴 التطبيق مقفول فوراً
          if (!isActive) {
            return const MaintenanceScreen();
          }

          /// 🟢 التطبيق شغال
          return AppUpdateWrapper(
            child: FutureBuilder<SharedPreferences>(
              future: SharedPreferences.getInstance(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }

                if (snapshot.hasData) {
                  final prefs = snapshot.data!;
                  final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
                  final userType = prefs.getString('userType');

                  if (isLoggedIn && userType == 'patient') {
                    return const PatientHomeScreen();
                  }

                  return const LoginScreen();
                }

                return const LoginScreen();
              },
            ),
          );
        },
      ),
    );
  }
}
