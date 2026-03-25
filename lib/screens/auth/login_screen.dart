import 'package:flutter/material.dart';
import 'package:clickout_cashier/core/theme/app_theme.dart';
import 'package:clickout_cashier/screens/dashboard/dashboard_screen.dart';
import 'package:clickout_cashier/services/analytics_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:clickout_cashier/auth/unified_auth_service.dart';
import 'package:clickout_cashier/utils/session_manager.dart';

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

    setState(() => _isLoading = true);

    await UnifiedAuthService.sendPhoneOtp(
      phone: "+91${_phoneController.text.trim()}",
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
        roleCollection: 'employees',
        initialData: {
          'branchCode': _branchCodeController.text.trim(),
          'role': 'CASHIER',
        },
      );

      if (mounted && userCred != null && userCred.user != null) {
        final doc = await FirebaseFirestore.instance
            .collection(
              'employees',
            ) // 👈 CHANGED: Pehle 'cashiers' tha, ab 'employees'
            .doc(userCred.user!.uid)
            .get();

        final data = doc.data() ?? {};
        final name = data['name'] ?? 'Cashier';

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

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => DashboardScreen(
              empId: userCred.user!.uid,
              empName: name,
              martId: SessionManager.branchCode, // Use from Session
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
