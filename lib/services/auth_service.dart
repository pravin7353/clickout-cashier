import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart'; // 👈 NAYA HATHIYAR
import '../models/employee_model.dart';

class AuthService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 🔐 LOGIN LOGIC
  Future<EmployeeModel?> loginEmployee({
    required String empId,
    required String password,
    required String branchCode,
  }) async {
    try {
      debugPrint("🔍 Searching for ID: '$empId' on LIVE SERVER...");

      QuerySnapshot querySnapshot = await _firestore
          .collection('employees')
          .where('empId', isEqualTo: empId)
          .limit(1)
          .get(const GetOptions(source: Source.server));

      if (querySnapshot.docs.isEmpty) {
        throw "Employee ID not found!";
      }

      DocumentSnapshot doc = querySnapshot.docs.first;
      final data = doc.data() as Map<String, dynamic>;
      final employee = EmployeeModel.fromMap(data);

      String dbPassword = data['password'] ?? '';

      if (dbPassword != password) {
        if (dbPassword.isEmpty) {
          throw "Password not set in Database! Contact Admin.";
        }
        throw "Incorrect Password!";
      }

      if (employee.branchCode != branchCode) {
        throw "You are not assigned to this Branch ($branchCode)!";
      }

      if (!employee.isActive) {
        throw "Your account is deactivated. Contact Manager.";
      }

      // 🚀 THE FIX: LOGIN HOTE HI MEMORY CARD MEIN SAVE KARO
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('empId', employee.empId);
      await prefs.setString('empName', employee.name);
      await prefs.setString('branchCode', employee.branchCode);

      return employee;
    } catch (e) {
      debugPrint("❌ Login Error: $e");
      rethrow;
    }
  }

  // 🚪 LOGOUT
  Future<void> logout() async {
    // 🚀 THE FIX: LOGOUT HOTE HI MEMORY CARD KHALI KARO
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
