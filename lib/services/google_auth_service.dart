import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GoogleAuthService {
  static final GoogleSignIn _googleSignIn = GoogleSignIn();
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // تسجيل دخول فقط — يرفض إن لم يكن هناك حساب مسبق
  static Future<Map<String, dynamic>> signInOnly() async {
    return _handleGoogleAuth(allowRegistration: false);
  }

  // إنشاء حساب — يسجّل دخول إن كان الحساب موجوداً، وينشئه إن لم يكن
  static Future<Map<String, dynamic>> signUpOrSignIn() async {
    return _handleGoogleAuth(allowRegistration: true);
  }

  static Future<Map<String, dynamic>> _handleGoogleAuth({
    required bool allowRegistration,
  }) async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return {'success': false, 'message': 'تم إلغاء العملية'};
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential =
          await _auth.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user == null) {
        return {'success': false, 'message': 'فشل في التحقق من حساب Google'};
      }

      // البحث بالـ UID أولاً
      final existingByUid = await FirebaseFirestore.instance
          .collection('patients')
          .where('googleId', isEqualTo: user.uid)
          .get();

      String patientId;
      String patientName;

      if (existingByUid.docs.isNotEmpty) {
        final doc = existingByUid.docs.first;
        patientId = doc.id;
        patientName = doc.data()['name'] ?? user.displayName ?? 'مريض';
      } else {
        // البحث بالبريد الإلكتروني
        final existingByEmail = await FirebaseFirestore.instance
            .collection('patients')
            .where('email', isEqualTo: user.email)
            .get();

        if (existingByEmail.docs.isNotEmpty) {
          final doc = existingByEmail.docs.first;
          patientId = doc.id;
          patientName = doc.data()['name'] ?? user.displayName ?? 'مريض';
          await FirebaseFirestore.instance
              .collection('patients')
              .doc(patientId)
              .update({'googleId': user.uid});
        } else {
          // لا يوجد حساب
          if (!allowRegistration) {
            await _googleSignIn.signOut();
            await _auth.signOut();
            return {
              'success': false,
              'message': 'لا يوجد حساب مرتبط بهذا البريد الإلكتروني. يرجى إنشاء حساب أولاً.',
            };
          }

          // إنشاء حساب جديد
          patientName = user.displayName ?? 'مريض';
          final docRef =
              FirebaseFirestore.instance.collection('patients').doc();
          patientId = docRef.id;
          await docRef.set({
            'name': patientName,
            'phone': user.phoneNumber ?? '',
            'email': user.email ?? '',
            'googleId': user.uid,
            'password': '',
            'createdAt': FieldValue.serverTimestamp(),
            'verified': true,
          });
        }
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('userType', 'patient');
      await prefs.setString('userEmail', user.email ?? '');
      await prefs.setString('userName', patientName);
      await prefs.setString('userId', patientId);
      await prefs.setString('userPhone', user.phoneNumber ?? '');
      await prefs.setBool('hasRegisteredOnce', true);

      return {'success': true, 'patientId': patientId, 'patientName': patientName};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}
