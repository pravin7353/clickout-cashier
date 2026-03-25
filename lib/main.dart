import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:shared_preferences/shared_preferences.dart'; // 👈 NAYA HATHIYAR

import 'screens/auth/login_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'core/theme/app_theme.dart';
// import 'package:clickout_cashier/utils/session_manager.dart';
import 'core/security/inactivity_logout_wrapper.dart';

void main() async {
  print("🚀 Starting Main...");
  WidgetsFlutterBinding.ensureInitialized();

  print("🔥 Initializing Firebase...");
  await Firebase.initializeApp();

  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  print("💾 Initializing Memory Card...");
  // 🚀 FIX: Ab yahan sirf EK baar 'prefs' declare hoga!
  final prefs = await SharedPreferences.getInstance();
  print("✅ Memory Card Ready!");

  final bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
  final String? empId = prefs.getString('empId');
  final String? empName = prefs.getString('empName');
  final String? branchCode = prefs.getString('branchCode');

  Widget startScreen = const LoginScreen(); // Default

  // Agar Memory Card mein data hai, toh seedha Dashboard kholo!
  if (isLoggedIn && empId != null && empName != null && branchCode != null) {
    startScreen = DashboardScreen(
      empId: empId,
      empName: empName,
      martId: branchCode,
    );
  }

  print("🎨 Drawing UI...");
  runApp(CashierApp(startScreen: startScreen));
}

class CashierApp extends StatelessWidget {
  final Widget startScreen;

  const CashierApp({super.key, required this.startScreen});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ClickOut Cashier',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,

      // 🚀 MAGIC STEP 1: Link the new Navigator Key!
      navigatorKey: globalNavigatorKey,

      builder: (context, child) {
        // 🚀 MAGIC STEP 2: Wrap the entire app in our new Shield
        return InactivityLogoutWrapper(
          // Aap chaho toh limits change kar sakte ho yahan se
          inactivityLimit: const Duration(minutes: 9),
          warningLimit: const Duration(minutes: 1),
          child: child!,
        );
      },
      home: startScreen,
    );
  }
}
