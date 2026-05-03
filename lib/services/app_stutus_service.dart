import 'package:cloud_firestore/cloud_firestore.dart';

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
