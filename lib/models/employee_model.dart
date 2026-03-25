class EmployeeModel {
  final String empId;
  final String name;
  final String email;
  final String phone;
  final String password; // ⚠️ Reminder: Real app me ye Hash hona chahiye
  final bool isActive;
  final String role; // 'cashier', 'manager'

  // 🚀 THE SAAS ROUTING IDs (Hierarchy)
  final String branchCode; // Legacy Fallback
  final String tenantId;
  final String storeId;
  final String zoneId;
  final String regionId;

  EmployeeModel({
    required this.empId,
    required this.name,
    required this.email,
    required this.phone,
    required this.password,
    this.isActive = true,
    this.role = 'cashier',
    this.branchCode = '',
    this.tenantId = '',
    this.storeId = '',
    this.zoneId = '',
    this.regionId = '',
  });

  // 📥 Firebase se Data lene ke liye
  factory EmployeeModel.fromMap(Map<String, dynamic> map) {
    return EmployeeModel(
      empId: map['empId'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      password: map['password'] ?? '',
      isActive: map['isActive'] ?? true,
      role: map['role'] ?? 'cashier',
      branchCode: map['branchCode'] ?? '',
      tenantId: map['tenantId'] ?? '',
      storeId: map['storeId'] ?? '',
      zoneId: map['zoneId'] ?? '',
      regionId: map['regionId'] ?? '',
    );
  }

  // 🚀 Firebase me Data bhejne ke liye
  Map<String, dynamic> toMap() {
    return {
      'empId': empId,
      'name': name,
      'email': email,
      'phone': phone,
      'password': password,
      'isActive': isActive,
      'role': role,
      'branchCode': branchCode,
      'tenantId': tenantId,
      'storeId': storeId,
      'zoneId': zoneId,
      'regionId': regionId,
    };
  }
}
