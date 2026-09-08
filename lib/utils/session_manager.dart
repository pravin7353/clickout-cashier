import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  static String empName = '';
  static String uid = '';

  // 🔒 Save session to SharedPreferences
  static Future<void> saveSession({
    required String uid,
    required String empName,
    required String tId,
    required String sId,
    required String zId,
    required String rId,
    required String bCode,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('uid', uid);
    await prefs.setString('empName', empName);
    await prefs.setString('tenantId', tId);
    await prefs.setString('storeId', sId);
    await prefs.setString('zoneId', zId);
    await prefs.setString('regionId', rId);
    await prefs.setString('branchCode', bCode);
    setStoreContext(tId: tId, sId: sId, zId: zId, rId: rId, bCode: bCode);
    SessionManager.empName = empName;
    SessionManager.uid = uid;
  }

  // 🔓 Load session from SharedPreferences
  static Future<bool> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTenant = prefs.getString('tenantId') ?? '';
    final savedStore = prefs.getString('storeId') ?? '';
    if (savedTenant.isEmpty || savedStore.isEmpty) return false;
    tenantId = savedTenant;
    storeId = savedStore;
    zoneId = prefs.getString('zoneId') ?? '';
    regionId = prefs.getString('regionId') ?? '';
    branchCode = prefs.getString('branchCode') ?? '';
    empName = prefs.getString('empName') ?? '';
    uid = prefs.getString('uid') ?? '';
    return true;
  }

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
    empName = '';
    uid = '';
    SharedPreferences.getInstance().then((prefs) => prefs.clear());
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
  // 🚀 CLEANUP: Faltu timeout aur login status variables hata diye kyunki ab hum hamesha logged-in rehte hain!

  @override
  void initState() {
    super.initState();
    _resetTimer();
  }

  Future<void> _stopTimer() async {
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
    debugPrint("🔒 Session Timer Stopped (User Logged Out)");
  }

  void _resetTimer() {
    // 🚀 OTP PAISA BACHAO ABHIYAN!
    _timer?.cancel();
  }

  // 🚀 CLEANUP: _handleTimeout function hi hata diya kyunki ab timeout hona hi nahi hai!

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
