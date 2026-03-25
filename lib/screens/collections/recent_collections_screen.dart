import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:clickout_cashier/core/theme/app_theme.dart';
import 'package:clickout_cashier/screens/invoice/invoice_screen.dart';
import 'package:clickout_cashier/utils/session_manager.dart';

class RecentCollectionsScreen extends StatefulWidget {
  // 🔒 SECURITY: Branch Code required
  final String branchCode;

  const RecentCollectionsScreen({super.key, required this.branchCode});

  @override
  State<RecentCollectionsScreen> createState() =>
      _RecentCollectionsScreenState();
}

class _RecentCollectionsScreenState extends State<RecentCollectionsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchText = "";

  // 🔄 STREAM VARIABLE (Refresh ke liye zaroori hai)
  Stream<QuerySnapshot>? _ordersStream;

  @override
  void initState() {
    super.initState();
    _loadOrders(); // 🚀 App khulte hi data load karo
  }

  // 🛠️ DATA LOADING FUNCTION
  void _loadOrders() {
    setState(() {
      _ordersStream = FirebaseFirestore.instance
          .collection('orders')
          // 🛡️ THE SAAS ISOLATION RULE
          .where('tenantId', isEqualTo: SessionManager.tenantId)
          .where('storeId', isEqualTo: SessionManager.storeId)
          .where('status', isEqualTo: 'completed')
          .orderBy('timestamp', descending: true)
          .limit(50)
          .snapshots();
    });
  }

  // 🔄 REFRESH HANDLER (Jab user pull karega)
  Future<void> _handleRefresh() async {
    // 1. Thoda wait karo (UX ke liye, taaki spinner dikhe)
    await Future.delayed(const Duration(milliseconds: 800));

    // 2. Stream ko dobara load karo (Re-fetch)
    _loadOrders();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Transaction History"),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // 🔍 SEARCH BAR
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchText = value.toLowerCase().trim();
                });
              },
              style: const TextStyle(color: Colors.black87),
              decoration: InputDecoration(
                hintText: "Search Order ID (e.g. 8A2F)",
                hintStyle: TextStyle(color: Colors.grey[400]),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: _searchText.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchText = "");
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),

          // 📜 LIST SECTION WITH REFRESH
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _ordersStream, // 👈 Variable use kiya
              builder: (context, snapshot) {
                // 🔴 ERROR STATE
                if (snapshot.hasError) {
                  return _buildScrollablePlaceholder(
                    _buildErrorContent(snapshot.error.toString()),
                  );
                }

                // ⏳ LOADING STATE
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                var docs = snapshot.data!.docs;

                // ⚪ EMPTY STATE
                if (docs.isEmpty) {
                  return _buildScrollablePlaceholder(_buildEmptyContent());
                }

                // 🧹 CLIENT SIDE FILTERING
                var filteredDocs = docs.where((doc) {
                  var id = doc.id.toLowerCase();
                  return id.contains(_searchText);
                }).toList();

                // 🔍 NO SEARCH RESULTS
                if (filteredDocs.isEmpty) {
                  return _buildScrollablePlaceholder(_buildNoSearchContent());
                }

                // ✅ DATA LIST (Wrapped in RefreshIndicator)
                return RefreshIndicator(
                  onRefresh: _handleRefresh, // 👈 Pull Action
                  color: AppTheme.primaryColor,
                  child: ListView.builder(
                    physics:
                        const AlwaysScrollableScrollPhysics(), // Important for Refresh
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredDocs.length,
                    itemBuilder: (context, index) {
                      var data =
                          filteredDocs[index].data() as Map<String, dynamic>;
                      String orderId = filteredDocs[index].id;

                      String dateStr = "Unknown";
                      if (data['timestamp'] != null) {
                        try {
                          DateTime dt = (data['timestamp'] as Timestamp)
                              .toDate();
                          dateStr = DateFormat('dd MMM, hh:mm a').format(dt);
                        } catch (e) {
                          dateStr = "Just Now";
                        }
                      }

                      return Card(
                        elevation: 0,
                        color: Colors.white,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => InvoiceScreen(
                                  orderData: data,
                                  orderId: orderId,
                                ),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                // Icon
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.blue[50],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.receipt_long,
                                    color: Colors.blueAccent,
                                  ),
                                ),
                                const SizedBox(width: 16),

                                // Details
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Order #${orderId.substring(0, 5).toUpperCase()}",
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        dateStr,
                                        style: TextStyle(
                                          color: Colors.grey[500],
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Amount
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      "₹${data['totalAmount']}",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                        color: AppTheme.primaryColor,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    if (data['scannedByName'] != null)
                                      Text(
                                        "By: ${data['scannedByName'].toString().split(' ')[0]}",
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey[400],
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 🎨 HELPERS FOR SCROLLABLE EMPTY STATES
  // ==========================================
  // Ye wrapper zaroori hai taaki "Empty Screen" par bhi Pull-to-Refresh kaam kare
  Widget _buildScrollablePlaceholder(Widget content) {
    return RefreshIndicator(
      onRefresh: _handleRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.7, // Full height
            child: content,
          ),
        ],
      ),
    );
  }

  // 1. Empty Content
  Widget _buildEmptyContent() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.history_toggle_off,
              size: 60,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            "No collections yet",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Pull down to refresh", // ✨ User Hint
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  // 2. No Search Content
  Widget _buildNoSearchContent() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 60, color: Colors.grey[300]),
          const SizedBox(height: 20),
          Text(
            "No matching results",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  // 3. Error Content
  Widget _buildErrorContent(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, size: 60, color: Colors.redAccent),
            const SizedBox(height: 20),
            const Text(
              "Something went wrong",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Pull down to try again",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            Text(
              error,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10, color: Colors.grey[300]),
            ),
          ],
        ),
      ),
    );
  }
}
