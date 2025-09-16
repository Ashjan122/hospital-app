import 'package:cloud_firestore/cloud_firestore.dart';

class PresenceService {
  static final CollectionReference _patients =
      FirebaseFirestore.instance.collection('patients');

  static Future<void> setOnline({required String patientId}) async {
    if (patientId.isEmpty) return;
    await _patients.doc(patientId).set({
      'isOnline': true,
      'lastSeenAt': FieldValue.serverTimestamp(),
      'lastLoginAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> setOffline({required String patientId}) async {
    if (patientId.isEmpty) return;
    await _patients.doc(patientId).set({
      'isOnline': false,
      'lastSeenAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> setLoginTimestamp({required String patientId}) async {
    if (patientId.isEmpty) return;
    await _patients.doc(patientId).set({
      'lastLoginAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}


