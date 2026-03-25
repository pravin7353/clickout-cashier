import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/order_model.dart';
import '../utils/session_manager.dart'; // 👈 THE MASTER KEY IMPORTED

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 📦 1. RECENT ORDERS (Strictly Isolated for this Store ONLY)
  Stream<List<OrderModel>> getRecentCollections(String empId) {
    // 🛡️ Data Leakage Protection: Sirf is tenant aur store ka data!
    return _db
        .collection('orders')
        .where('tenantId', isEqualTo: SessionManager.tenantId)
        .where('storeId', isEqualTo: SessionManager.storeId)
        .where('status', isEqualTo: 'completed')
        // .where('collectedBy', isEqualTo: empId) // Abhi ke liye comment kiya hai
        .orderBy('timestamp', descending: true)
        .limit(20)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => OrderModel.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  // 🔍 2. GET ORDER BY QR CODE (Robust Fetch with Logging)
  Future<DocumentSnapshot?> getOrderById(String orderId) async {
    try {
      final doc = await _db.collection('orders').doc(orderId).get();

      if (!doc.exists) {
        debugPrint("⚠️ API Warning: Order not found for ID: $orderId");
        return null;
      }

      // 🛡️ Cross-Tenant Security Check:
      // Agar ye order kisi aur company ka hai, to block kar do!
      final data = doc.data() as Map<String, dynamic>;
      if (data['tenantId'] != SessionManager.tenantId) {
        debugPrint(
          "🚨 SECURITY ALERT: Attempted to fetch order of another tenant!",
        );
        return null;
      }

      return doc;
    } catch (e, stack) {
      debugPrint("❌ Database Error fetching order $orderId: $e");
      debugPrint("Stack Trace: $stack");
      return null;
    }
  }

  // ✅ 3. MARK PAYMENT AS DONE (Update with Context)
  Future<void> collectPayment(String orderId, String empId) async {
    await _db.collection('orders').doc(orderId).update({
      'status': 'completed',
      'paymentStatus': 'PAID',
      'paymentMode': 'CASH',
      'collectedBy': empId,
      'timestamp': FieldValue.serverTimestamp(),

      // 🚀 Just to be 100% safe, re-stamp the routing IDs on update
      'tenantId': SessionManager.tenantId,
      'storeId': SessionManager.storeId,
      'branchCode': SessionManager.branchCode,
    });
  }

  // 🛒 4. CREATE NEW ORDER (Data Flattening Magic)
  // Jab Cashier khud naya bill banayega, ye chalega
  Future<void> createNewOrder(
    double totalAmount,
    List<Map<String, dynamic>> items,
  ) async {
    try {
      await _db.collection('orders').add({
        // 🚀 THE SAAS ROUTING IDs (Data Flattening)
        'tenantId': SessionManager.tenantId,
        'storeId': SessionManager.storeId,
        'zoneId': SessionManager.zoneId,
        'regionId': SessionManager.regionId,
        'branchCode': SessionManager.branchCode, // Legacy Fallback
        // 💰 Order Details
        'totalAmount': totalAmount,
        'items': items,
        'status': 'PENDING',
        'paymentStatus': 'PENDING',
        'exitStatus': 'PENDING',
        'wasEverRejected': false,
        'timestamp': FieldValue.serverTimestamp(),
      });
      debugPrint(
        "✅ Order Created Successfully in Store: ${SessionManager.storeId}",
      );
    } catch (e) {
      debugPrint("❌ Error creating order: $e");
      throw Exception('Order creation failed');
    }
  }
}
