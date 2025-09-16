import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:hospital_app/firebase_options.dart';
import 'package:hospital_app/screnns/login_screen.dart';
// import 'package:hospital_app/screnns/onboarding_screen.dart';
import 'package:hospital_app/screnns/register_screen.dart';
import 'package:hospital_app/screnns/patient_home_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hospital_app/widgets/app_update_wrapper.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print("رسالة في الخلفية: ${message.messageId}");
  print("عنوان الرسالة: ${message.notification?.title}");
  print("محتوى الرسالة: ${message.notification?.body}");
}

Future<void> initializeFirebaseMessaging() async {
  final messaging = FirebaseMessaging.instance;
  
  // طلب الإذن للإشعارات
  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    announcement: false,
    badge: true,
    carPlay: false,
    criticalAlert: false,
    provisional: false,
    sound: true,
  );
  
  print('إذن الإشعارات: ${settings.authorizationStatus}');
  
  // الحصول على token
  String? token = await messaging.getToken();
  if (token != null) {
    print('FCM Token: $token');
    // حفظ token في SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fcm_token', token);
  }
  
  // الاستماع لتغييرات token
  messaging.onTokenRefresh.listen((newToken) {
    print('Token محدث: $newToken');
    // حفظ token الجديد
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('fcm_token', newToken);
    });
  });
  
  // إعداد الإشعارات في المقدمة
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print('رسالة في المقدمة: ${message.messageId}');
    print('عنوان الرسالة: ${message.notification?.title}');
    print('محتوى الرسالة: ${message.notification?.body}');
    
    // يمكن إضافة منطق إضافي هنا لعرض الإشعارات
  });
  
  // إعداد الإشعارات عند فتح التطبيق
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    print('تم فتح التطبيق من الإشعار: ${message.messageId}');
    // يمكن إضافة منطق التنقل هنا
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  // إعداد Firebase Messaging
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await initializeFirebaseMessaging();
  
  FirebaseAuth.instance.authStateChanges().listen((User? user) {
    if (user == null) {
      print('المستخدم مسجل خروج.');
    } else {
      print('المستخدم مسجل دخول.');
    }
  });

  runApp(const HospitalApp());
}

class HospitalApp extends StatelessWidget {
  const HospitalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AppUpdateWrapper(
        child: FutureBuilder<SharedPreferences>(
          future: SharedPreferences.getInstance(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }
            
            if (snapshot.hasData) {
              final prefs = snapshot.data!;
              final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
              final userType = prefs.getString('userType');
              final hasRegisteredOnce = prefs.getBool('hasRegisteredOnce') ?? false;

              if (isLoggedIn && userType == 'patient') {
                return const PatientHomeScreen();
              }
              if (hasRegisteredOnce) {
                return const LoginScreen();
              }
              return const RegisterScreen();
            }
            
            // في حالة الخطأ، نعرض شاشة تسجيل الدخول
            return const LoginScreen();
          },
        ),
      ),
    );
  }
}
