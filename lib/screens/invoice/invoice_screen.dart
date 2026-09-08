import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:clickout_cashier/core/theme/app_theme.dart';
import 'package:flutter/services.dart';

class InvoiceScreen extends StatelessWidget {
  final Map<String, dynamic> orderData;
  final String orderId;

  const InvoiceScreen({
    super.key,
    required this.orderData,
    required this.orderId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryColor,
      appBar: AppBar(
        title: const Text("Transaction Details"),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .doc(orderId)
            .snapshots(),
        builder: (context, snapshot) {
          Map<String, dynamic> liveData = orderData;
          if (snapshot.hasData && snapshot.data!.exists) {
            liveData = snapshot.data!.data() as Map<String, dynamic>;
          }

          final items = List<Map<String, dynamic>>.from(
            liveData['items'] ?? [],
          );
          final double totalAmount =
              double.tryParse(liveData['totalAmount'].toString()) ?? 0.0;

          String formattedDate = "Unknown Date";
          if (liveData['timestamp'] != null) {
            final timestamp = liveData['timestamp'];
            DateTime dt = DateTime.now();
            try {
              dt = timestamp is Timestamp ? timestamp.toDate() : DateTime.now();
            } catch (e) {
              dt = DateTime.now();
            }
            formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(dt);
          }

          String currentExitStatus = (liveData['exitStatus'] ?? 'PENDING')
              .toString()
              .toUpperCase();
          bool isApproved =
              currentExitStatus == 'EXITED' ||
              currentExitStatus == 'COMPLETED' ||
              currentExitStatus == 'APPROVED';
          bool isRejected = currentExitStatus == 'REJECTED';

          Color bannerColor = isApproved
              ? Colors.blue[50]!
              : (isRejected ? Colors.red[50]! : Colors.orange[50]!);
          Color textColor = isApproved
              ? Colors.blue[700]!
              : (isRejected ? Colors.red[800]! : Colors.orange[800]!);
          IconData bannerIcon = isApproved
              ? Icons.verified_user
              : (isRejected ? Icons.gpp_bad : Icons.warning_amber_rounded);
          String bannerText = isApproved
              ? "Gate Pass: Verified & Exited"
              : (isRejected
                    ? "Gate Pass: Verification Failed"
                    : "Gate Pass: Pending Guard Scan");

          return Column(
            children: [
              const SizedBox(height: 10),
              Expanded(
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(20),
                          ),
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 50,
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              "Payment Successful",
                              style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            Text(
                              "₹${totalAmount.toStringAsFixed(0)}",
                              style: const TextStyle(
                                color: Colors.black87,
                                fontWeight: FontWeight.bold,
                                fontSize: 32,
                                fontFamily: 'DejaVuSansMono',
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        color: bannerColor,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(bannerIcon, color: textColor, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              bannerText,
                              style: TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 🚀 FIX 1: Custom Row for Order ID with Copy Icon
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 5,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      "Order ID",
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                    Row(
                                      children: [
                                        Text(
                                          "#${orderId.substring(0, 8).toUpperCase()}",
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        GestureDetector(
                                          onTap: () {
                                            Clipboard.setData(
                                              ClipboardData(
                                                text: orderId
                                                    .substring(0, 8)
                                                    .toUpperCase(),
                                              ),
                                            );
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  "Order ID Copied!",
                                                ),
                                                duration: Duration(seconds: 1),
                                                backgroundColor: Colors.green,
                                              ),
                                            );
                                          },
                                          child: const Icon(
                                            Icons.copy,
                                            size: 16,
                                            color: Colors.blueAccent,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              _buildRow("Date", formattedDate),
                              _buildRow("Payment Mode", "CASH"),
                              // 🚀 FIX 2: Show Actual Name instead of ugly UID
                              _buildRow(
                                "Cashier",
                                liveData['scannedByName'] ?? "Store Cashier",
                              ),

                              const Divider(height: 30, thickness: 1),

                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    "TOTAL PAID",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    "₹${totalAmount.toStringAsFixed(0)}",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(
                        height: 20,
                      ), // 🚀 FIX 3: Print receipt button removed completely
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
