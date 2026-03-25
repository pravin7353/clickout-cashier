import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
//import 'package:flutter/foundation.dart';

class AnalyticsService {
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  final FirebaseCrashlytics _crashlytics = FirebaseCrashlytics.instance;

  // 🆔 Set User Identity (Jab banda login kare)
  Future<void> setUser(String empId) async {
    await _analytics.setUserId(id: empId);
    await _crashlytics.setUserIdentifier(empId);
  }

  // ✅ EVENT: Login Success
  Future<void> logLogin(String branchCode) async {
    await _analytics.logLogin(
      loginMethod: 'employee_auth',
      parameters: {'branch_code': branchCode},
    );
  }

  // ✅ EVENT: Scan Success
  Future<void> logScanSuccess({
    required String orderId,
    required double amount,
    required String branchCode,
  }) async {
    await _analytics.logEvent(
      name: 'scan_success',
      parameters: {
        'order_id': orderId,
        'value': amount,
        'currency': 'INR',
        'branch_code': branchCode,
      },
    );
  }

  // ⚠️ EVENT: Duplicate Scan Blocked (Fraud Prevention)
  Future<void> logDuplicateScan(String orderId) async {
    await _analytics.logEvent(
      name: 'duplicate_scan_attempt',
      parameters: {'order_id': orderId},
    );
    // Non-fatal error bhi bhej sakte hain
    await _crashlytics.log("Duplicate scan blocked for Order: $orderId");
  }

  // 🔴 Helper to Log Errors manually
  Future<void> logError(dynamic exception, StackTrace? stack) async {
    await _crashlytics.recordError(exception, stack);
  }
}
