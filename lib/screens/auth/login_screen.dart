import 'package:flutter/material.dart';
import 'package:clickout_cashier/core/theme/app_theme.dart';
import 'package:clickout_cashier/screens/dashboard/dashboard_screen.dart';
import 'package:clickout_cashier/services/analytics_service.dart';
import 'package:clickout_cashier/auth/unified_auth_service.dart';
import 'package:clickout_cashier/utils/session_manager.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  final AnalyticsService _analytics = AnalyticsService();
  bool _isLoading = false;
  bool _isOtpSent = false;
  String? _verificationId;

  void _handleSendOtp() async {
    final rawPhone = _phoneController.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (rawPhone.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("⚠️ Please enter a valid 10-digit mobile number"),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    // 🔒 Phone-only staff pre-check (avoids wasting SMS credits)
    try {
      final staffSnap = await FirebaseFirestore.instance
          .collection('staff')
          .where('phone', whereIn: [rawPhone, '+91$rawPhone'])
          .where('isActive', isEqualTo: true)
          .where('isDeleted', isEqualTo: false)
          .limit(1)
          .get();

      if (staffSnap.docs.isEmpty) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("This number is not registered as staff. Contact your admin."),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    } catch (e) {
      debugPrint("Staff pre-check warning: $e");
    }

    final finalPhone = "+91$rawPhone";
    debugPrint("🚀 SENDING OTP TO: '$finalPhone'");

    await UnifiedAuthService.sendPhoneOtp(
      phone: finalPhone,
      onCodeSent: (verificationId) {
        if (!mounted) return;
        setState(() {
          _verificationId = verificationId;
          _isOtpSent = true;
          _isLoading = false;
        });
      },
      onError: (error) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ $error"), backgroundColor: Colors.red),
        );
      },
    );
  }

  void _handleVerifyLogin() async {
    if (_otpController.text.length != 6) return;
    setState(() => _isLoading = true);

    try {
      // Step 1: Firebase Phone Auth
      final userCred = await UnifiedAuthService.verifyOtpAndLogin(
        verificationId: _verificationId!,
        smsCode: _otpController.text.trim(),
        roleCollection: 'staff',
        initialData: {'role': 'CASHIER'},
      );

      if (!mounted || userCred == null || userCred.user == null) return;

      // Step 2: Force-refresh token so Cloud Function sees the verified phone claim
      await FirebaseAuth.instance.currentUser?.getIdToken(true);

      // Step 3: Call resolveStaffSession to auto-resolve tenantId/storeId/branchCode
      final callable = FirebaseFunctions.instance.httpsCallable(
        'resolveStaffSession',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 15)),
      );
      final result = await callable.call({'role': 'cashier'});
      final sessionData = Map<String, dynamic>.from(result.data as Map);

      // Step 4: Validate completeness
      final tenantId = (sessionData['tenantId'] ?? '').toString();
      final storeId = (sessionData['storeId'] ?? '').toString();
      final branchCode = (sessionData['branchCode'] ?? '').toString();
      final name = (sessionData['name'] ?? 'Cashier').toString();
      final docId = (sessionData['docId'] ?? '').toString();

      if (tenantId.isEmpty || storeId.isEmpty) {
        await UnifiedAuthService.logout('staff');
        throw "⚠️ Staff profile incomplete (missing tenantId/storeId). Contact your admin.";
      }

      // Step 5: Persist session
      SessionManager.setStoreContext(
        tId: tenantId,
        sId: storeId,
        zId: sessionData['zoneId']?.toString() ?? '',
        rId: sessionData['regionId']?.toString() ?? '',
        bCode: branchCode,
      );

      try {
        await _analytics.setUser(userCred.user!.uid);
        await _analytics.logLogin(branchCode);
      } catch (analyticsError) {
        debugPrint("Analytics Error Ignored: $analyticsError");
      }

      await SessionManager.saveSession(
        uid: userCred.user!.uid,
        empName: name,
        tId: tenantId,
        sId: storeId,
        zId: sessionData['zoneId']?.toString() ?? '',
        rId: sessionData['regionId']?.toString() ?? '',
        bCode: branchCode,
        docId: docId,
      );

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => DashboardScreen(
            empId: userCred.user!.uid,
            empName: name,
            martId: branchCode,
          ),
        ),
      );
    } catch (e, stack) {
      try {
        await _analytics.logError(e, stack);
      } catch (_) {} // 🛡️ CRASH SHIELD

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        final errStr = e.toString().toLowerCase();
        final isNotFound = (e is FirebaseFunctionsException && e.code == 'not-found') ||
            errStr.contains('not-found') ||
            errStr.contains('no active staff record');

        if (isNotFound) {
          // Blocking dialog: don't allow proceeding, offer re-entering number
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              title: const Text("Access Denied"),
              content: const Text(
                "This number is not registered as a cashier. Contact your admin.",
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _isOtpSent = false;
                      _otpController.clear();
                    });
                  },
                  child: const Text("Re-enter Number"),
                ),
              ],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("❌ Login Failed: ${e.toString()}"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: AppTheme.primaryColor,
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Icon(
                  Icons.storefront_rounded,
                  size: 80,
                  color: Colors.white,
                ),
                const SizedBox(height: 20),
                const Text(
                  "CASHIER LOGIN",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 40),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        if (!_isOtpSent) ...[
                          TextField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            maxLength: 10,
                            decoration: const InputDecoration(
                              labelText: "Mobile Number",
                              prefixText: "+91 ",
                              prefixIcon: Icon(Icons.phone),
                              counterText: "",
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleSendOtp,
                              child: _isLoading
                                  ? const CircularProgressIndicator(
                                      color: Colors.white,
                                    )
                                  : const Text("GET OTP"),
                            ),
                          ),
                        ] else ...[
                          TextField(
                            controller: _otpController,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            textAlign: TextAlign.center,
                            decoration: const InputDecoration(
                              labelText: "Enter 6-Digit OTP",
                              prefixIcon: Icon(Icons.message),
                              counterText: "",
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleVerifyLogin,
                              child: _isLoading
                                  ? const CircularProgressIndicator(
                                      color: Colors.white,
                                    )
                                  : const Text("VERIFY & LOGIN"),
                            ),
                          ),
                          TextButton(
                            onPressed: () => setState(() => _isOtpSent = false),
                            child: const Text("Change Number"),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
