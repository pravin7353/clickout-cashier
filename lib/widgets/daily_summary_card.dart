import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/theme/app_theme.dart';
import '../utils/session_manager.dart';

class DailySummaryCard extends StatelessWidget {
  final String branchCode;

  const DailySummaryCard({super.key, required this.branchCode});

  @override
  Widget build(BuildContext context) {
    // 📅 Calculate Start of Today (Midnight)
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    return StreamBuilder<QuerySnapshot>(
      // 🚀 OPTIMIZED QUERY: Only 1 read per document update (No N+1 problem)
      stream: FirebaseFirestore.instance
          .collection('orders')
          // 🛡️ THE SAAS ISOLATION RULE
          .where('tenantId', isEqualTo: SessionManager.tenantId)
          .where('storeId', isEqualTo: SessionManager.storeId)
          .where(
            'timestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
          )
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildMessageCard(
            "Index Missing!\nCheck Terminal.",
            Colors.redAccent,
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildMessageCard("Analyzing Retail Data...", Colors.white54);
        }

        // 🧠 STRICT BUSINESS LOGIC COUNTERS
        double totalCollection = 0;
        int totalScans = 0;
        int successCount = 0;
        int pendingCount = 0;
        int rejectCount = 0;
        int fixedCount = 0;

        if (snapshot.hasData && snapshot.data != null) {
          for (var doc in snapshot.data!.docs) {
            var data = doc.data() as Map<String, dynamic>;

            String payStatus = (data['paymentStatus'] ?? '')
                .toString()
                .toUpperCase();
            String exitStatus = (data['exitStatus'] ?? '')
                .toString()
                .toUpperCase();
            bool wasEverRejected = data['wasEverRejected'] == true;

            // Rule 1: Scans & Collection (Only if Cashier processed it)
            if (payStatus == 'PAID' || data['status'] == 'completed') {
              totalScans++;
              totalCollection +=
                  double.tryParse(data['totalAmount'].toString()) ?? 0.0;

              // Rule 2: Success
              if (exitStatus == 'APPROVED' ||
                  exitStatus == 'COMPLETED' ||
                  exitStatus == 'EXITED') {
                successCount++;

                // Rule 5: Fixed After Reject 🔥
                if (wasEverRejected) {
                  fixedCount++;
                }
              }
              // Rule 4: Reject at Gate
              else if (exitStatus == 'REJECTED') {
                rejectCount++;
              }
              // Rule 3: Pending at Gate (Any other state like PENDING, READY_FOR_EXIT)
              else {
                pendingCount++;
              }
            }
          }
        }

        // 🎨 UI PRESENTATION
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.primaryColor,
                AppTheme.primaryColor.withOpacity(0.8),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            children: [
              // HEADER
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Today's Analytics",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      "${now.day}/${now.month}/${now.year}",
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 📊 ROW 1: Cashier Metrics
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatItem(
                    "Collection",
                    "₹${totalCollection.toStringAsFixed(0)}",
                    Icons.account_balance_wallet,
                    color: Colors.greenAccent,
                  ),
                  _buildDivider(),
                  _buildStatItem("Scans", "$totalScans", Icons.qr_code_scanner),
                  _buildDivider(),
                  _buildStatItem(
                    "Success",
                    "$successCount",
                    Icons.verified_user,
                  ),
                ],
              ),

              const SizedBox(height: 15),
              const Divider(color: Colors.white24, height: 1),
              const SizedBox(height: 15),

              // 📊 ROW 2: Gate Control & Effectiveness
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatItem(
                    "Pending",
                    "$pendingCount",
                    Icons.hourglass_empty,
                    color: pendingCount > 0
                        ? Colors.orangeAccent
                        : Colors.white,
                  ),
                  _buildDivider(),
                  _buildStatItem(
                    "Rejected",
                    "$rejectCount",
                    Icons.gpp_bad,
                    color: rejectCount > 0 ? Colors.redAccent : Colors.white,
                  ),
                  _buildDivider(),
                  _buildStatItem(
                    "Fixed 🔥",
                    "$fixedCount",
                    Icons.build_circle,
                    color: fixedCount > 0 ? Colors.yellowAccent : Colors.white,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // 🛠️ SMART HELPER: Fixed width so grid aligns perfectly
  Widget _buildStatItem(
    String label,
    String value,
    IconData icon, {
    Color color = Colors.white,
  }) {
    return SizedBox(
      width: 80,
      child: Column(
        children: [
          Icon(
            icon,
            color: color == Colors.white ? Colors.white70 : color,
            size: 22,
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(height: 35, width: 1, color: Colors.white24);
  }

  Widget _buildMessageCard(String message, Color textColor) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
