import 'package:cloud_firestore/cloud_firestore.dart';

class OrderModel {
  final String orderId;
  final double totalAmount;
  final String status;
  final String paymentStatus;
  final DateTime timestamp;
  final String exitStatus;
  final bool wasEverRejected;

  // 🚀 THE SAAS ROUTING IDs (Data Flattening)
  final String branchCode; // Legacy
  final String tenantId;
  final String storeId;
  final String zoneId;
  final String regionId;

  OrderModel({
    required this.orderId,
    required this.totalAmount,
    required this.status,
    required this.paymentStatus,
    required this.timestamp,
    required this.exitStatus,
    required this.wasEverRejected,
    this.branchCode = '',
    this.tenantId = '',
    this.storeId = '',
    this.zoneId = '',
    this.regionId = '',
  });

  // 📥 Firebase se Data lene ke liye
  factory OrderModel.fromMap(Map<String, dynamic> map, String id) {
    return OrderModel(
      orderId: id,
      totalAmount: double.tryParse(map['totalAmount'].toString()) ?? 0.0,
      status: map['status'] ?? 'PENDING',
      paymentStatus: map['paymentStatus'] ?? 'PENDING',
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      exitStatus: map['exitStatus'] ?? 'PENDING',
      wasEverRejected: map['wasEverRejected'] ?? false,
      branchCode: map['branchCode'] ?? '',
      tenantId: map['tenantId'] ?? '',
      storeId: map['storeId'] ?? '',
      zoneId: map['zoneId'] ?? '',
      regionId: map['regionId'] ?? '',
    );
  }

  // 🚀 Firebase me Data save karne ke liye (Naya add kiya gaya hai!)
  Map<String, dynamic> toMap() {
    return {
      'totalAmount': totalAmount,
      'status': status,
      'paymentStatus': paymentStatus,
      'timestamp': FieldValue.serverTimestamp(), // Secure time
      'exitStatus': exitStatus,
      'wasEverRejected': wasEverRejected,
      'branchCode': branchCode,
      'tenantId': tenantId,
      'storeId': storeId,
      'zoneId': zoneId,
      'regionId': regionId,
    };
  }
}
