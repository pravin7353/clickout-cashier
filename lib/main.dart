import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_auth/firebase_auth.dart';

// 🚀 NAYA IMPORT: Yahan apne splash screen ka sahi path daal dena agar error aaye
import 'screens/auth/splash_screen.dart';
import 'core/theme/app_theme.dart';

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

  // 🧹 CLEANUP: Yahan se SharedPreferences ka lamba code hata diya.
  // Ab wo saara logic Splash Screen ke laser animation ke pichhe chalega!

  print("🎨 Drawing UI...");
  runApp(const CashierApp());
}

class CashierApp extends StatefulWidget {
  // 🧹 CLEANUP: startScreen variable hata diya
  const CashierApp({super.key});

  @override
  State<CashierApp> createState() => _CashierAppState();
}

class _CashierAppState extends State<CashierApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 🛡️ App foreground me aane par token refresh, taaki naye custom claims
    // (role/tenantId/branchCode) turant mil jayein
    if (state == AppLifecycleState.resumed) {
      FirebaseAuth.instance.currentUser?.getIdToken(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ClickOut Cashier',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      // 🚀 THE FIX: App seedha Splash Screen se shuru hogi!
      home: const SplashScreen(),
    );
  }
}
