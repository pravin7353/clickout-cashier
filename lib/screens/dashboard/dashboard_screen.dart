import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vibration/vibration.dart';
import 'package:intl/intl.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'package:clickout_cashier/core/theme/app_theme.dart';
import 'package:clickout_cashier/screens/invoice/invoice_screen.dart';
import 'package:clickout_cashier/screens/collections/recent_collections_screen.dart';
import 'package:clickout_cashier/utils/session_manager.dart';
import 'package:clickout_cashier/widgets/daily_summary_card.dart';
import 'package:clickout_cashier/services/analytics_service.dart';

class DashboardScreen extends StatefulWidget {
  final String empName;
  final String empId;
  final String martId;

  const DashboardScreen({
    super.key,
    required this.empName,
    required this.empId,
    required this.martId,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late StreamSubscription<ConnectivityResult> _connectivitySubscription;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _checkInitialConnection();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      ConnectivityResult result,
    ) {
      _updateConnectionStatus(result);
    });

    // 🧹 THE MASTER HACK: MORNING SWEEPER FIRED ON BOOT!
    _runMorningSweeper();
  }

  // 🕛 THE VIRTUAL SERVER: Cleans Yesterday's Junk Automatically
  Future<void> _runMorningSweeper() async {
    try {
      final now = DateTime.now();
      final startOfToday = DateTime(now.year, now.month, now.day);

      // 1. Find all PENDING orders (SaaS ISOLATED)
      final snapshot = await FirebaseFirestore.instance
          .collection('orders')
          // 🛑 PURANI LINE HATA DO: .where('branchCode', isEqualTo: widget.martId)
          // 🚀 NAYI LINES LAGA DO: Data Isolation for Multi-Tenant
          .where('tenantId', isEqualTo: SessionManager.tenantId)
          .where('storeId', isEqualTo: SessionManager.storeId)
          .where('exitStatus', whereIn: ['PENDING', 'READY_FOR_EXIT'])
          .limit(100) // 🛑 Truck over-load nahi hoga!
          .get();

      if (snapshot.docs.isEmpty) return; // All clean!

      WriteBatch batch = FirebaseFirestore.instance.batch();
      int sweptCount = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final timestamp = data['timestamp'] as Timestamp?;

        if (timestamp != null) {
          final orderDate = timestamp.toDate();

          // 2. Agar ye order AAJ ka nahi hai (matlab kal ka kachra hai)
          if (orderDate.isBefore(startOfToday)) {
            batch.update(doc.reference, {
              'exitStatus': 'EXPIRED_BY_SYSTEM', // ⛔ Guard will block this
              'qrConsumed': true, // 🔒 Lock QR
              'qrExpiresAt': FieldValue.serverTimestamp(), // Force Expire
              'isDeleted': true, // 🧹 Hide from Customer Live
              'wasEverRejected': true, // ⬛ Push permanently to Black Box
              'systemRemark': 'AUTO_MORNING_SWEEP', // Forensic mark
              'archivedAt': FieldValue.serverTimestamp(),
            });
            sweptCount++;
          }
        }
      }

      // 3. Ek sath saara data Firebase par thop do! (Saves reads/writes)
      if (sweptCount > 0) {
        await batch.commit();
        debugPrint(
          "🧹 MORNING SWEEP COMPLETE: $sweptCount junk orders moved to Black Box.",
        );
      }
    } catch (e) {
      debugPrint("🧹 Sweeper Error: $e");
    }
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }

  Future<void> _checkInitialConnection() async {
    final result = await Connectivity().checkConnectivity();
    _updateConnectionStatus(result);
  }

  void _updateConnectionStatus(ConnectivityResult result) {
    setState(() {
      _isOffline = result == ConnectivityResult.none;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Cashier Portal"),
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text("End Shift?"),
                    content: const Text("Are you sure you want to logout?"),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          "Cancel",
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          SessionManager.stopTimer();
                          Navigator.pop(context);
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        child: const Text(
                          "Logout",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
        body: Column(
          children: [
            if (_isOffline)
              Container(
                width: double.infinity,
                color: Colors.redAccent,
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.wifi_off, color: Colors.white, size: 16),
                    SizedBox(width: 8),
                    Text(
                      "No Internet Connection - Saving Data Locally",
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
            Container(
              padding: const EdgeInsets.all(20),
              color: AppTheme.primaryColor.withOpacity(0.1),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: AppTheme.primaryColor,
                        child: Icon(Icons.person, color: Colors.white),
                      ),
                      const SizedBox(width: 15),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Welcome, ${widget.empName}",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppTheme.primaryDark,
                            ),
                          ),
                          Text(
                            "ID: ${widget.empId}",
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RecentCollectionsScreen(
                            branchCode: widget.martId,
                          ),
                        ),
                      );
                    },
                    child: const Text(
                      "View All",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            DailySummaryCard(branchCode: widget.martId),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 5, 20, 5),
              child: Row(
                children: [
                  Icon(Icons.history, size: 18, color: Colors.grey),
                  SizedBox(width: 5),
                  Text(
                    "Recent Collections (Today)",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('orders')
                    .where('branchCode', isEqualTo: widget.martId)
                    .where('status', isEqualTo: 'completed')
                    .orderBy('timestamp', descending: true)
                    .limit(20)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: Colors.red,
                              size: 40,
                            ),
                            SizedBox(height: 10),
                            Text(
                              "Connection Error",
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  var orders = snapshot.data!.docs;

                  if (orders.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.history,
                            size: 80,
                            color: Colors.grey[300],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            "No collections yet.",
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: orders.length,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    itemBuilder: (context, index) {
                      var order = orders[index].data() as Map<String, dynamic>;

                      String time = "Unknown Time";
                      if (order['timestamp'] != null) {
                        try {
                          DateTime dt = (order['timestamp'] as Timestamp)
                              .toDate();
                          time = DateFormat('hh:mm a').format(dt);
                        } catch (e) {
                          time = "Just Now";
                        }
                      } else {
                        time = "Syncing...";
                      }

                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => InvoiceScreen(
                                  orderData: order,
                                  orderId: orders[index].id,
                                ),
                              ),
                            );
                          },
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check,
                                color: Colors.green,
                              ),
                            ),
                            title: Text(
                              "Order #${orders[index].id.substring(0, 5).toUpperCase()}",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text("Paid via Cash • $time"),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  "₹${order['totalAmount']}",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: AppTheme.primaryDark,
                                  ),
                                ),
                                if (orders[index].metadata.hasPendingWrites)
                                  const Icon(
                                    Icons.cloud_upload,
                                    size: 14,
                                    color: Colors.orange,
                                  )
                                else
                                  const Icon(
                                    Icons.arrow_forward_ios,
                                    size: 12,
                                    color: Colors.grey,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ScannerPage(
                  empId: widget.empId,
                  empName: widget.empName,
                  branchCode: widget.martId,
                ),
              ),
            );
          },
          backgroundColor: AppTheme.primaryColor,
          elevation: 4,
          icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
          label: const Text(
            "SCAN CUSTOMER QR",
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 📸 SCANNER PAGE (Maintained from previous fix)
// ==========================================
class ScannerPage extends StatefulWidget {
  final String empId;
  final String empName;
  final String branchCode;

  const ScannerPage({
    super.key,
    required this.empId,
    required this.empName,
    required this.branchCode,
  });

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  bool isProcessing = false;
  DateTime? _lastScanTime;

  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  final AnalyticsService _analytics = AnalyticsService();

  final MobileScannerController cameraController = MobileScannerController(
    detectionTimeoutMs: 1500,
  );

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          "Scan Payment QR",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            color: Colors.white,
            icon: const Icon(Icons.flash_on, color: Colors.yellow),
            onPressed: () {
              try {
                cameraController.toggleTorch();
              } catch (e) {
                debugPrint("Torch Error: $e");
              }
            },
          ),
          IconButton(
            color: Colors.white,
            icon: const Icon(Icons.cameraswitch),
            onPressed: () {
              try {
                cameraController.switchCamera();
              } catch (e) {
                debugPrint("Switch Error: $e");
              }
            },
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          MobileScanner(
            controller: cameraController,
            onDetect: (capture) {
              if (isProcessing) return;

              final now = DateTime.now();
              if (_lastScanTime != null &&
                  now.difference(_lastScanTime!).inMilliseconds < 2000) {
                return;
              }
              _lastScanTime = now;

              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  processPayment(barcode.rawValue!);
                  break;
                }
              }
            },
          ),
          CustomPaint(painter: ScannerOverlayPainter(), child: Container()),
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Column(
              children: [
                const Icon(
                  Icons.qr_code_scanner,
                  color: Colors.white70,
                  size: 40,
                ),
                const SizedBox(height: 10),
                const Text(
                  "Align Customer's Gate Pass QR\nwithin the frame to collect payment",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
                if (isProcessing) ...[
                  const SizedBox(height: 20),
                  const CircularProgressIndicator(color: Colors.white),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<String> _getDeviceId() async {
    try {
      if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await _deviceInfo.androidInfo;
        return androidInfo.id;
      } else if (Platform.isIOS) {
        IosDeviceInfo iosInfo = await _deviceInfo.iosInfo;
        return iosInfo.identifierForVendor ?? 'Unknown iOS';
      }
    } catch (e) {
      return 'Error Getting ID';
    }
    return 'Unknown Device';
  }

  void processPayment(String orderId) async {
    if (!mounted) return;

    setState(() => isProcessing = true);
    SessionManager.resetTimer();

    if (await Vibration.hasVibrator()) {
      Vibration.vibrate(duration: 100);
    }

    try {
      DocumentReference orderRef = FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId);
      String deviceId = await _getDeviceId();
      double totalAmount = 0.0;

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentSnapshot doc = await transaction.get(orderRef);

        if (!doc.exists) throw Exception("INVALID_QR");

        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        totalAmount = double.tryParse(data['totalAmount'].toString()) ?? 0.0;

        if (data['status'] == 'completed' || data['paymentStatus'] == 'PAID') {
          throw Exception("ALREADY_PAID");
        }

        // 🧠 HACK PREVENTION: Do not process EXPIRED orders
        if (data['exitStatus'] == 'EXPIRED_BY_SYSTEM') {
          throw Exception("EXPIRED_QR");
        }

        transaction.update(orderRef, {
          'status': 'completed',
          'paymentStatus': 'PAID',
          'paymentMode': 'CASH',
          'exitStatus': 'READY_FOR_EXIT',
          'collectedBy': widget.empId,
          'scannedByEmpId': widget.empId,
          'scannedByName': widget.empName,

          // 🚀 SAAS ROUTING IDs STAMPED
          'tenantId': SessionManager.tenantId,
          'storeId': SessionManager.storeId,
          'branchCode': SessionManager.branchCode,

          'deviceId': deviceId,
          'scanTimestamp': FieldValue.serverTimestamp(),
          'timestamp': FieldValue.serverTimestamp(),
        });
      });

      await _analytics.logScanSuccess(
        orderId: orderId,
        amount: totalAmount,
        branchCode: widget.branchCode,
      );

      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text("Payment Collected! ✅"),
          content: Text(
            "Order ID: $orderId\nAmount: ₹$totalAmount\n\n(Saved. Will sync when online)",
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text("DONE"),
            ),
          ],
        ),
      );
    } catch (e, stack) {
      if (e.toString().contains("INVALID_QR")) {
        showError("Invalid QR Code!");
      } else if (e.toString().contains("ALREADY_PAID")) {
        _analytics.logDuplicateScan(orderId);
        showError("Already Paid!");
      } else if (e.toString().contains("EXPIRED_QR")) {
        showError("QR EXPIRED! This order was moved to Black Box.");
      } else {
        _analytics.logError(e, stack);
        showError("Network or DB Error. Try again.");
      }
    } finally {
      if (mounted) {
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) {
            setState(() {
              isProcessing = false;
              _lastScanTime = null;
            });
          }
        });
      }
    }
  }

  void showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }
}

class ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.65)
      ..style = PaintingStyle.fill;
    final double scanAreaSize = size.width * 0.7;
    final Rect scanRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2.2),
      width: scanAreaSize,
      height: scanAreaSize,
    );
    final Path backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final Path cutoutPath = Path()
      ..addRRect(RRect.fromRectAndRadius(scanRect, const Radius.circular(16)));
    canvas.drawPath(
      Path.combine(PathOperation.difference, backgroundPath, cutoutPath),
      paint,
    );
    final borderPaint = Paint()
      ..color = Colors.cyanAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;
    const double cl = 30.0;
    canvas.drawPath(
      Path()
        ..moveTo(scanRect.left, scanRect.top + cl)
        ..lineTo(scanRect.left, scanRect.top)
        ..lineTo(scanRect.left + cl, scanRect.top),
      borderPaint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(scanRect.right - cl, scanRect.top)
        ..lineTo(scanRect.right, scanRect.top)
        ..lineTo(scanRect.right, scanRect.top + cl),
      borderPaint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(scanRect.left, scanRect.bottom - cl)
        ..lineTo(scanRect.left, scanRect.bottom)
        ..lineTo(scanRect.left + cl, scanRect.bottom),
      borderPaint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(scanRect.right - cl, scanRect.bottom)
        ..lineTo(scanRect.right, scanRect.bottom)
        ..lineTo(scanRect.right, scanRect.bottom - cl),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
