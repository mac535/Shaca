import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'handshake_screen.dart'; // 🚀 IMPORT THE HANDSHAKE SCREEN!

class OwnerDashboardScreen extends StatefulWidget {
  const OwnerDashboardScreen({super.key});

  @override
  State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ImagePicker _picker = ImagePicker();
  String? _uploadingRentalId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  // 📸 1. UPLOAD LOGIC
  Future<void> _takeLivePhotoAndApprove(String rentalId, String toolId, String toolName) async {
    try {
      final XFile? photo = await _picker.pickImage(source: ImageSource.camera, imageQuality: 70);
      if (photo == null) return;

      setState(() => _uploadingRentalId = rentalId);

      File imageFile = File(photo.path);
      String fileName = 'live_photos/${DateTime.now().millisecondsSinceEpoch}_$rentalId.jpg';
      Reference ref = FirebaseStorage.instance.ref().child(fileName);
      await ref.putFile(imageFile);
      String downloadUrl = await ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('rentals').doc(rentalId).update({
        'liveImageUrl': downloadUrl,
        'status': 'pending_payment',
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Photo sent! Waiting for them to pay fast."), backgroundColor: Colors.green),
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Upload failed: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _uploadingRentalId = null);
    }
  }

  // 🛑 2. DECLINE LOGIC
  Future<void> _declineRequest(String rentalId) async {
    try {
      await FirebaseFirestore.instance.collection('rentals').doc(rentalId).update({
        'status': 'declined',
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Request declined."), backgroundColor: Colors.orange),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    }
  }

  // 🚀 WE DELETED THE OLD '_markAsReturned' BECAUSE THE HANDSHAKE SCREEN DOES IT SECURELY NOW!

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Scaffold(body: Center(child: Text("Please log in.")));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lender Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFFF8C00),
          labelColor: const Color(0xFFFF8C00),
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: "New Requests"),
            Tab(text: "Handovers & Active"), // 🚀 Updated tab name
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Just New Requests
          _buildRequestList(user.uid, ['pending_verification']),
          // Tab 2: Waiting for pickup OR currently rented out
          _buildRequestList(user.uid, ['paid_pending_pickup', 'Active']),
        ],
      ),
    );
  }

  // 🚀 Modified to accept a LIST of statuses
  Widget _buildRequestList(String userId, List<String> statuses) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('rentals')
          .where('lenderId', isEqualTo: userId)
          .where('status', whereIn: statuses) // 🚀 Fetch multiple states at once
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFFF8C00)));
        }

        if (snapshot.hasError) {
          debugPrint("Dashboard Error: ${snapshot.error}");
          return const Center(child: Text("An error occurred loading your dashboard."));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox_outlined, size: 80, color: Colors.grey[400]),
                const SizedBox(height: 16),
                const Text("No items right now.", style: TextStyle(fontSize: 18, color: Colors.grey)),
              ],
            ),
          );
        }

        final requests = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            var request = requests[index].data() as Map<String, dynamic>;
            String rentalId = requests[index].id;
            String toolId = request['toolId'];
            String currentStatus = request['status'] ?? ''; // Get the exact status

            DateTime? startDate = request['startDate'] != null ? (request['startDate'] as Timestamp).toDate() : null;
            int days = request['days'] ?? 1;
            double amount = (request['totalPaid'] ?? request['totalCost'] ?? 0).toDouble();

            bool isUploading = _uploadingRentalId == rentalId;

            // Determine badge text and color based on exact status
            String badgeText = "Action Required";
            Color badgeColor = Colors.orange;

            if (currentStatus == 'Active') {
              badgeText = "In Progress";
              badgeColor = Colors.green;
            } else if (currentStatus == 'paid_pending_pickup') {
              badgeText = "Ready for Handover";
              badgeColor = Colors.blue;
            }

            return Card(
              elevation: 3,
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text(request['toolName'] ?? 'Tool', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)), overflow: TextOverflow.ellipsis)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: badgeColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            badgeText,
                            style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        )
                      ],
                    ),
                    const Divider(height: 24),
                    if (startDate != null)
                      Row(children: [const Icon(Icons.calendar_today, size: 16, color: Colors.grey), const SizedBox(width: 8), Text("Date: ${DateFormat('MMM dd, yyyy').format(startDate)}") ]),
                    const SizedBox(height: 8),
                    Row(children: [const Icon(Icons.timer, size: 16, color: Colors.grey), const SizedBox(width: 8), Text("Duration: $days Days") ]),
                    const SizedBox(height: 8),
                    Row(children: [const Icon(Icons.payments, size: 16, color: Colors.green), const SizedBox(width: 8), Text("Earnings: ₹${amount.toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)) ]),
                    const SizedBox(height: 20),

                    // 🔘 ACTION BUTTONS: Pending Verification
                    if (currentStatus == 'pending_verification')
                      Row(
                        children: [
                          Expanded(
                            flex: 1,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.red),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onPressed: isUploading ? null : () => _declineRequest(rentalId),
                              child: const Text("Decline"),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFF8C00),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onPressed: isUploading ? null : () => _takeLivePhotoAndApprove(rentalId, toolId, request['toolName']),
                              icon: isUploading
                                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                              label: Text(
                                  isUploading ? "Uploading..." : "Send Photo",
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
                              ),
                            ),
                          ),
                        ],
                      ),

                    // 🚀 NEW BUTTON: Handover to Borrower
                    if (currentStatus == 'paid_pending_pickup')
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(
                                builder: (_) => HandshakeScreen(
                                  rentalId: rentalId,
                                  rentalData: request,
                                  isLender: true, // 🚀 THEY ARE THE OWNER
                                  actionType: 'pickup',
                                )
                            ));
                          },
                          icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
                          label: const Text("Scan Borrower's Code", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),

                    // 🚀 NEW BUTTON: Accept Return
                    if (currentStatus == 'Active')
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(
                                builder: (_) => HandshakeScreen(
                                  rentalId: rentalId,
                                  rentalData: request,
                                  isLender: true, // 🚀 THEY ARE THE OWNER
                                  actionType: 'return',
                                )
                            ));
                          },
                          icon: const Icon(Icons.assignment_return, color: Colors.white),
                          label: const Text("Accept Return (Scan Code)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}