import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'session_timer_service.dart';
import '../../services/auth_service.dart'; // Adjust path based on your folder structure
import '../../screens/auth/login_screen.dart'; // Adjust path based on your folder structure

// 🌐 Global Navigator Key to force navigation from anywhere
final GlobalKey<NavigatorState> globalNavigatorKey = GlobalKey<NavigatorState>();

class InactivityLogoutWrapper extends StatefulWidget {
  final Widget child;
  final Duration inactivityLimit; // e.g., 9 Minutes
  final Duration warningLimit; // e.g., 1 Minute

  const InactivityLogoutWrapper({
    super.key,
    required this.child,
    this.inactivityLimit = const Duration(minutes: 9),
    this.warningLimit = const Duration(minutes: 1),
  });

  @override
  State<InactivityLogoutWrapper> createState() => _InactivityLogoutWrapperState();
}

class _InactivityLogoutWrapperState extends State<InactivityLogoutWrapper> {
  late SessionTimerService _timerService;
  bool _isDialogShowing = false;
  StreamSubscription<User?>? _authSubscription; // 🚀 NAYA HATHIYAR: Auth Listener

  @override
  void initState() {
    super.initState();
    _timerService = SessionTimerService(
      inactivityDuration: widget.inactivityLimit,
      countdownDuration: widget.warningLimit,
      onWarning: _showWarningDialog,
      onLogout: _performLogout,
    );

    // 🧠 THE FIX: Auth State Listener
    // Ye check karega ki user actually logged in hai ya nahi.
    // Agar manually logout kar diya, toh timer turant kill ho jayega!
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user == null) {
        _timerService.stop(); // 🛑 Stop timer on Login Screen
        if (_isDialogShowing && globalNavigatorKey.currentContext != null) {
          Navigator.pop(globalNavigatorKey.currentContext!);
          _isDialogShowing = false;
        }
      } else {
        _timerService.start(); // ▶️ Start only when logged in
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel(); // Memory leak roko
    _timerService.stop();
    super.dispose();
  }

  // 🚨 UI: The 60-Second Warning Dialog
  void _showWarningDialog() {
    if (_isDialogShowing) return;
    _isDialogShowing = true;

    showDialog(
      context: globalNavigatorKey.currentContext!,
      barrierDismissible: false, // 🛑 Bahar click karke band nahi kar sakte
      builder: (context) {
        int secondsRemaining = widget.warningLimit.inSeconds;

        return StatefulBuilder(
          builder: (context, setState) {
            // Live 1-second ticker inside dialog
            Timer.periodic(const Duration(seconds: 1), (timer) {
              if (!mounted || !_isDialogShowing) {
                timer.cancel();
                return;
              }
              if (secondsRemaining > 0) {
                setState(() => secondsRemaining--);
              } else {
                timer.cancel();
              }
            });

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 30),
                  SizedBox(width: 10),
                  Text("Session Expiring!"),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "For security reasons, your session is about to be terminated due to inactivity.",
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "Logging out in: $secondsRemaining seconds",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.redAccent,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    _isDialogShowing = false;
                    Navigator.pop(context); // Close dialog
                    _performLogout(); // Logout manually
                  },
                  child: const Text("Logout Now", style: TextStyle(color: Colors.red)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  onPressed: () {
                    _isDialogShowing = false;
                    Navigator.pop(context); // Close dialog
                    _timerService.continueSession(); // Reset backend timer
                  },
                  child: const Text("Continue Session", style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // 🚪 ENGINE: The Ultimate Wipeout Sequence
  Future<void> _performLogout() async {
    _timerService.stop();
    
    // Safety check: Agar dialog already khula hai aur time khatam ho gaya
    if (_isDialogShowing && globalNavigatorKey.currentContext != null) {
      Navigator.pop(globalNavigatorKey.currentContext!);
    }
    _isDialogShowing = false;

    debugPrint("🔒 INACTIVITY DETECTED: Executing Secure Logout...");

    try {
      // 1. Wipe Local Data
      await AuthService().logout(); // Apne purane code se bulaya hai

      // 2. Wipe Firebase Authentication
      await FirebaseAuth.instance.signOut();

      // 3. Nuke the UI Stack and route to Login
      globalNavigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false, 
      );
    } catch (e) {
      debugPrint("❌ Logout Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      // 🖐️ GESTURE DETECTION RADAR
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _timerService.reset(),
      onPointerMove: (_) => _timerService.reset(),
      onPointerUp: (_) => _timerService.reset(),
      onPointerCancel: (_) => _timerService.reset(),
      child: widget.child,
    );
  }
}