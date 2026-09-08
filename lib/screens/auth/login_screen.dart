import 'package:flutter/material.dart';
import 'package:clickout_cashier/core/theme/app_theme.dart';
import 'package:clickout_cashier/screens/dashboard/dashboard_screen.dart';
import 'package:clickout_cashier/services/analytics_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:clickout_cashier/auth/unified_auth_service.dart';
import 'package:clickout_cashier/utils/session_manager.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _branchCodeController = TextEditingController();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  final AnalyticsService _analytics = AnalyticsService();
  bool _isLoading = false;
  bool _isOtpSent = false;
  String? _verificationId;

  void _handleSendOtp() async {
    if (_branchCodeController.text.isEmpty || _phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("⚠️ Please fill Branch Code and Phone Number"),
        ),
      );
      return;
    }

    /*setState(() => _isLoading = true);

    await UnifiedAuthService.sendPhoneOtp(
      phone: "+91${_phoneController.text.trim()}",
      onCodeSent: (verificationId) {
*/
    //=================================================================
    //bypass hone ke baad bhi loading chalti rahegi, jab tak OTP screen pe nahi pahunch jate, taki user ko lage ki kuch to ho raha hai
    //=======================================================

    setState(() => _isLoading = true);

    // 🔒 BRANCH VALIDATION — Phone + BranchCode match check
    String cleanNumber = _phoneController.text.replaceAll(
      RegExp(r'[^0-9]'),
      '',
    );
    final branchCode = _branchCodeController.text.trim().toUpperCase();

    final staffCheck = await FirebaseFirestore.instance
        .collection('staff')
        .where('phone', isEqualTo: cleanNumber)
        .where('branchCode', isEqualTo: branchCode)
        .where('isActive', isEqualTo: true)
        .where('isDeleted', isEqualTo: false)
        .limit(1)
        .get();

    if (staffCheck.docs.isEmpty) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "❌ Access Denied: Phone not registered for this branch.",
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    String finalPhone = "+91$cleanNumber";

    // 🎯 EXACT FIREBASE MATCHING
    if (cleanNumber == "8976543606") {
      finalPhone = "+91 89765 43606";
    } else if (cleanNumber == "9323137353") {
      finalPhone = "+91 93232 37353"; // Guard number
    }

    // 🕵️ DEBUG LOG: Ye aapko VS Code / Android Studio ke console me dikhayega ki actually jaa kya raha hai
    debugPrint("🚀🚀 SENDING TO FIREBASE EXACTLY AS: '$finalPhone'");

    await UnifiedAuthService.sendPhoneOtp(
      phone: finalPhone,
      onCodeSent: (verificationId) {
        //=================================================================
        //bypass hone ke baad bhi loading chalti rahegi, jab tak OTP screen pe nahi pahunch jate, taki user ko lage ki kuch to ho raha hai
        //=======================================================
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
        // 🚀 THE FIX: Ab app crash nahi hoga, ye error dikhayega
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
      final userCred = await UnifiedAuthService.verifyOtpAndLogin(
        verificationId: _verificationId!,
        smsCode: _otpController.text.trim(),
        roleCollection: 'staff', // 🚀 FIX 1: Collection ka naam 'staff' hoga
        initialData: {
          'branchCode': _branchCodeController.text.trim(),
          'role': 'CASHIER',
        },
      );

      if (mounted && userCred != null && userCred.user != null) {
        // 🛡️ Custom claims (role/tenantId/branchCode) turant fresh karne ke liye
        await Future.delayed(const Duration(seconds: 2));
        await FirebaseAuth.instance.currentUser?.getIdToken(true);

        // 🚀 FIX: UnifiedAuthService ne UID link kar diya hai, toh sidha UID se exact profile fetch karo!
        final staffQuery = await FirebaseFirestore.instance
            .collection('staff')
            .where('uid', isEqualTo: userCred.user!.uid)
            .limit(1)
            .get();

        if (staffQuery.docs.isEmpty) {
          await UnifiedAuthService.logout('staff');
          throw "Access Denied: Profile link failed.";
        }

        final doc = staffQuery.docs.first;
        final data = doc.data();
        final name = data['name'] ?? 'Staff Member';

        // 🚨 SAAS DATA CHECKER (Duplicate Blocker)
        if (data['tenantId'] == null || data['storeId'] == null) {
          await UnifiedAuthService.logout('staff');
          throw "⚠️ DUPLICATE TRASH DETECTED: Ye ek khali profile hai! Kripya Firebase me jake is number ki duplicate entry delete karein aur sirf Admin wali entry rakhein.";
        }

        // 🚨 ZERO TRUST AUTHORIZATION CHECK (The Bouncer)
        bool isActive = data['isActive'] == true;
        bool isDeleted = data['isDeleted'] == true;

        if (!isActive || isDeleted) {
          await UnifiedAuthService.logout('staff');
          throw "Access Denied: Your account is pending admin approval or disabled.";
        }

        // 🚀 THE SAAS INJECTION: Load routing IDs into Memory
        SessionManager.setStoreContext(
          tId: data['tenantId'] ?? 'default_tenant',
          sId: data['storeId'] ?? 'default_store',
          zId: data['zoneId'] ?? 'default_zone',
          rId: data['regionId'] ?? 'default_region',
          bCode: data['branchCode'] ?? _branchCodeController.text.trim(),
        );

        try {
          await _analytics.setUser(userCred.user!.uid);
          await _analytics.logLogin(_branchCodeController.text.trim());
        } catch (analyticsError) {
          debugPrint("Analytics Error Ignored: $analyticsError");
        }

        await SessionManager.saveSession(
          uid: userCred.user!.uid,
          empName: name,
          tId: data['tenantId'] ?? '',
          sId: data['storeId'] ?? '',
          zId: data['zoneId'] ?? '',
          rId: data['regionId'] ?? '',
          bCode: data['branchCode'] ?? _branchCodeController.text.trim(),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => DashboardScreen(
              empId: userCred.user!.uid,
              empName: name,
              martId: SessionManager.branchCode,
            ),
          ),
        );
      }
    } catch (e, stack) {
      try {
        await _analytics.logError(e, stack);
      } catch (_) {} // 🛡️ CRASH SHIELD

      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("❌ Login Failed: ${e.toString()}"),
            backgroundColor: Colors.red,
          ),
        );
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
                        TextField(
                          controller: _branchCodeController,
                          enabled: !_isOtpSent,
                          decoration: const InputDecoration(
                            labelText: "Branch Code",
                            prefixIcon: Icon(Icons.store),
                          ),
                        ),
                        const SizedBox(height: 10),
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
