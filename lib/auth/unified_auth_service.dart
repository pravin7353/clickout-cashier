import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
//import 'package:flutter/foundation.dart';

class UnifiedAuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ==========================================================
  // 🚀 1. PHONE OTP ENGINE (Customers, Guards, Cashiers)
  // ==========================================================
  // 🧠 SMART TRACKER: Ye yaad rakhega ki kis time par kitne OTP gaye
  static final Map<String, List<int>> _otpHistory = {};

  static Future<void> sendPhoneOtp({
    required String phone,
    required Function(String verificationId) onCodeSent,
    required Function(String error) onError,
  }) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final history = _otpHistory[phone] ?? [];

      // 🧹 Pehle ke 60 seconds se purane records hata do
      history.removeWhere((timestamp) => now - timestamp > 60000);

      // 🛑 Agar pichle 60 seconds me 2 baar OTP bhej chuke hain, toh block karo
      if (history.length >= 2) {
        throw "Too many attempts. Please wait 60 seconds.";
      }

      await _auth.verifyPhoneNumber(
        phoneNumber: phone,
        // Web ReCAPTCHA handles this automatically if setup correctly
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-resolution (mostly Android)
          await _auth.signInWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          onError(e.message ?? "Verification failed.");
        },
        codeSent: (String verificationId, int? resendToken) async {
          // 🚀 Record this attempt's timestamp
          history.add(DateTime.now().millisecondsSinceEpoch);
          _otpHistory[phone] = history;

          onCodeSent(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
      );
    } catch (e) {
      onError(e.toString());
    }
  }

  static Future<UserCredential?> verifyOtpAndLogin({
    required String verificationId,
    required String smsCode,
    required String roleCollection, // 'users', 'guards', or 'cashiers'
    required Map<String, dynamic> initialData, // Data to save if new user
  }) async {
    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      UserCredential userCred = await _auth.signInWithCredential(credential);

      // 🧠 AUTO-CREATION & ROLE ASSIGNMENT (LINK ADMIN PROFILES)
      if (userCred.user != null) {
        String phoneWithCode = userCred.user!.phoneNumber ?? '';
        String phoneWithoutCode = phoneWithCode
            .replaceAll('+91', '')
            .replaceAll(' ', '');

        // 🚀 THE FIX: Check if Admin already created this staff by Phone Number!
        var existingDocs = await _db
            .collection(roleCollection)
            .where('phone', whereIn: [phoneWithCode, phoneWithoutCode])
            .limit(1)
            .get();

        DocumentReference docRef;

        if (existingDocs.docs.isNotEmpty) {
          // ✅ Admin panel wala profile mil gaya! Usko use karo.
          docRef = existingDocs.docs.first.reference;
        } else {
          // 🆕 Naya user hai (Customer flow ya unregistered staff)
          docRef = _db.collection(roleCollection).doc(userCred.user!.uid);

          bool isAutoActive = (roleCollection == 'users');
          await docRef.set({
            ...initialData,
            'uid': userCred.user!.uid,
            'phone': phoneWithCode,
            'createdAt': FieldValue.serverTimestamp(),
            'isActive': isAutoActive,
          });
        }

        // 🔄 Sync Auth UID and Update Session ID (Anti-hijack)
        await docRef.update({
          'uid': userCred.user!.uid,
          'lastLoginAt': FieldValue.serverTimestamp(),
          'activeSessionId': DateTime.now().millisecondsSinceEpoch.toString(),
        });
      }
      return userCred;
    } catch (e) {
      throw "Invalid OTP. Please try again.";
    }
  }

  // ==========================================================
  // 📧 2. ADMIN MAGIC LINK (Passwordless - Ultra Secure)
  // ==========================================================

  static Future<void> sendAdminMagicLink(String email, String bundleId) async {
    try {
      // Check if email actually belongs to an admin first
      final query = await _db
          .collection('admin_users')
          .where('email', isEqualTo: email)
          .get();
      if (query.docs.isEmpty) throw "Access Denied: Unregistered Admin Email.";

      var acs = ActionCodeSettings(
        url:
            'https://clickout-admin.web.app/finishSignUp?cartId=1234', // Replace with your hosting URL
        handleCodeInApp: true,
        iOSBundleId: bundleId,
        androidPackageName: bundleId,
        androidInstallApp: false,
        androidMinimumVersion: '12',
      );

      await _auth.sendSignInLinkToEmail(email: email, actionCodeSettings: acs);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'emailForSignIn',
        email,
      ); // Save locally to verify later
    } catch (e) {
      throw e.toString();
    }
  }

  static Future<void> verifyMagicLink(String emailLink) async {
    final prefs = await SharedPreferences.getInstance();
    String? email = prefs.getString('emailForSignIn');

    if (email == null) throw "Session expired. Try logging in again.";

    if (_auth.isSignInWithEmailLink(emailLink)) {
      try {
        await _auth.signInWithEmailLink(email: email, emailLink: emailLink);
        // Clear email from storage
        await prefs.remove('emailForSignIn');
      } catch (e) {
        throw "Error signing in with link: $e";
      }
    }
  }

  // ==========================================================
  // 🚪 3. GLOBAL LOGOUT
  // ==========================================================
  static Future<void> logout(String roleCollection) async {
    final user = _auth.currentUser;
    if (user != null) {
      // Destroy Session ID
      await _db
          .collection(roleCollection)
          .doc(user.uid)
          .update({'activeSessionId': FieldValue.delete()})
          .catchError((_) {}); // Ignore if document doesn't exist
    }
    await _auth.signOut();
  }
}
