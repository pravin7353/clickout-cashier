import 'dart:async';
import 'package:flutter/material.dart';
import '../../screens/auth/login_screen.dart';
import '../services/auth_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class SessionManager extends StatefulWidget {
  final Widget child;
  const SessionManager({super.key, required this.child});

  // ==========================================================
  // 🚀 SAAS ENTERPRISE MULTI-TENANT CONTEXT (The Magic IDs)
  // ==========================================================
  static String tenantId = '';
  static String storeId = '';
  static String zoneId = '';
  static String regionId = '';
  static String branchCode = ''; // Legacy ID

  // Ye function login ya QR scan success hone par call karna hai
  static void setStoreContext({
    required String tId,
    required String sId,
    required String zId,
    required String rId,
    required String bCode,
  }) {
    tenantId = tId;
    storeId = sId;
    zoneId = zId;
    regionId = rId;
    branchCode = bCode;
    debugPrint("🏢 Store Context Locked: Tenant[$tId] -> Store[$sId]");
  }

  static void clearSessionData() {
    tenantId = '';
    storeId = '';
    zoneId = '';
    regionId = '';
    branchCode = '';
  }
  // ==========================================================

  static void resetTimer() {
    _SessionManagerState? state =
        _sessionKey.currentState as _SessionManagerState?;
    state?._resetTimer();
  }

  static void stopTimer() {
    _SessionManagerState? state =
        _sessionKey.currentState as _SessionManagerState?;
    state?._stopTimer();
  }

  static final GlobalKey _sessionKey = GlobalKey();

  @override
  State<SessionManager> createState() => _SessionManagerState();
}

class _SessionManagerState extends State<SessionManager> {
  Timer? _timer;
  final Duration _timeoutDuration = const Duration(minutes: 20);
  bool _isLoggedIn = true; // 🚀 By Default Active

  @override
  void initState() {
    super.initState();
    _resetTimer();
  }

  Future<void> _stopTimer() async {
    _isLoggedIn = false;
    _timer?.cancel();
    _timer = null;

    // 🚀 THE FIX: MEMORY CARD WIPE OUT
    SessionManager.clearSessionData(); // Naya security feature!
    await AuthService().logout();

    // 🚀 SAARI SCREENS BHI CLEAR KARKE LOGIN PE BHEJ DO
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
    print("🔒 Session Timer Stopped (User Logged Out)");
  }

  void _resetTimer() {
    if (!_isLoggedIn) return;
    if (_timer != null) {
      _timer!.cancel();
    }
    _timer = Timer(_timeoutDuration, _handleTimeout);
  }

  void _handleTimeout() async {
    if (!_isLoggedIn) return;
    print("⚠️ SESSION EXPIRED: Logging out user...");
    await _stopTimer();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      key: SessionManager._sessionKey,
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _resetTimer(),
      onPointerMove: (_) => _resetTimer(),
      onPointerUp: (_) => _resetTimer(),
      child: widget.child,
    );
  }
}
