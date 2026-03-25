import 'package:cloud_firestore/cloud_firestore.dart';

class DbSeeder {
  // 🔥 IS FUNCTION KO SIRF EK BAAR RUN KARNA HAI
  static Future<void> seedInitialEmployee() async {
    final db = FirebaseFirestore.instance;
    const String empId = "EMP001"; // Login ID

    try {
      // Check karo agar pehle se hai to duplicate mat banao
      final doc = await db.collection('employees').doc(empId).get();

      if (!doc.exists) {
        await db.collection('employees').doc(empId).set({
          'empId': empId,
          'name': 'Pravin Manager',
          'email': 'pravin@clickout.com',
          'phone': '9876543210',
          'branchCode': 'MART01', // Password: Login ke liye ye chahiye
          'password': 'password123', // Simple Password
          'isActive': true,
          'role': 'manager',
          'createdAt': FieldValue.serverTimestamp(),
          'tenantId': 'tnt_clickout',
          'storeId': 'str_mumbai_01',
          'zoneId': 'zone_west',
          'regionId': 'reg_mh',
        });
        print("✅ SUCCESS: Test Employee Created!");
        print("🆔 ID: EMP001");
        print("🔑 Pass: password123");
        print("🏢 Branch: MART01");
      } else {
        print("⚠️ Employee already exists.");
      }
    } catch (e) {
      print("❌ Error seeding DB: $e");
    }
  }
}
