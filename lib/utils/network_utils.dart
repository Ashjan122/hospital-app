import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';

bool isNetworkError(dynamic e) {
  if (e is SocketException) return true;
  if (e is TimeoutException) return true;
  final msg = e.toString().toLowerCase();
  return msg.contains('network') ||
      msg.contains('socket') ||
      msg.contains('timeout') ||
      msg.contains('connection') ||
      msg.contains('unavailable') ||
      msg.contains('failed host lookup') ||
      msg.contains('no address associated');
}

Widget buildNetworkErrorWidget({
  required VoidCallback onRetry,
  String label = 'فشل التحميل بسبب انقطاع الانترنت',
}) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off_rounded, size: 72, color: Colors.orange[400]),
          const SizedBox(height: 16),
          Text(
            label,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'تأكد من اتصالك بالانترنت ثم حاول مجدداً',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('إعادة المحاولة'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2FBDAF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
