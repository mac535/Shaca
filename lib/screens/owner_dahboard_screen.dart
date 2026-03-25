import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dispute_screen.dart';

class OwnerDashboardScreen extends StatefulWidget {
  const OwnerDashboardScreen({super.key});

  @override
  State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen> {
  // 🚨 YOUR RAZORPAY KEYS (Use the ones from your successful payment test)
  final String rzpKeyId = "rzp_test_SUEgr0VtN9Exrh";
  final String rzpKeySecret = "YOUR_SECRET_KEY_HERE"; // 🔑 IMPORTANT: Get this from Razorpay Dashboard

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Owner Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
          bottom: const TabBar(
            indicatorColor: Color(0xFFFF8C00),
            labelColor: Color(0xFFFF8C00),
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(text: "New Requests"),
              Tab(text: "Returns & Refunds"),
            ],
          ),
        ),
        body: currentUser == null
            ? const Center(child: Text("Please log in"))
            : TabBarView(
          children: [
            _buildIncomingRequests(currentUser.uid),
            _buildPendingRefunds(currentUser.uid),
          ],
        ),
      ),
    );
  }

  // --- TAB 1: NEW REQUESTS ---
  Widget _buildIncomingRequests(String uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('rentals')
          .where('lenderId', isEqualTo: uid)
          .where('status', isEqualTo: 'pending_verification')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return const Center(child: Text("No new requests."));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            var data = docs[index].data() as Map<String, dynamic>;
            String borrowerId = data['borrowerId'];

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              // ==========================================
              // ⭐ FETCH THE BORROWER'S TRUST SCORE LIVE
              // ==========================================
              child: FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance.collection('users').doc(borrowerId).get(),
                  builder: (context, userSnapshot) {
                    if (!userSnapshot.hasData) return const ListTile(title: Text("Loading request..."));

                    var borrowerData = userSnapshot.data!.data() as Map<String, dynamic>?;
                    double trustScore = (borrowerData != null && borrowerData.containsKey('trustScore'))
                        ? (borrowerData['trustScore'] as num).toDouble()
                        : 5.0; // Default to 5.0
                    String borrowerName = borrowerData?['name'] ?? "Community Member";

                    return ListTile(
                      leading: const Icon(Icons.handshake, color: Colors.blue, size: 30),
                      title: Text(data['toolName'] ?? "Tool", style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text("Requested by: $borrowerName"),
                          Row(
                            children: [
                              const Icon(Icons.star, color: Colors.amber, size: 16),
                              const SizedBox(width: 4),
                              Text("$trustScore Trust Score", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                      ),
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                        onPressed: () => docs[index].reference.update({'status': 'paid_pending_pickup'}),
                        child: const Text("Approve", style: TextStyle(color: Colors.white)),
                      ),
                    );
                  }
              ),
            );
          },
        );
      },
    );
  }

  // --- TAB 2: RETURNS & REFUNDS ---
  Widget _buildPendingRefunds(String uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('rentals')
          .where('lenderId', isEqualTo: uid)
          .where('status', isEqualTo: 'Returned_pending_review')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return const Center(child: Text("No tools waiting for review."));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            var data = docs[index].data() as Map<String, dynamic>;
            return Card(
              color: Colors.orange.shade50,
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data['toolName'] ?? "Tool", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 4),
                    Text("Security Deposit: ₹${data['securityDeposit']}"),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                            onPressed: () => _showReviewDialog(docs[index].id, data, false),
                            child: const Text("Full Refund", style: TextStyle(color: Colors.white)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                            onPressed: () => _showReviewDialog(docs[index].id, data, true),
                            child: const Text("Report Damage"),
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- REVIEW DIALOG ---
  void _showReviewDialog(String rentalId, Map<String, dynamic> data, bool isDamaged) {
    int rating = 5;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isDamaged ? "Report Damage" : "Review Borrower"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("How was your experience with this borrower?"),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) => IconButton(
                  icon: Icon(i < rating ? Icons.star : Icons.star_border, color: Colors.amber),
                  onPressed: () => setDialogState(() => rating = i + 1),
                )),
              ),
              if (!isDamaged) const Text("Clicking 'Refund' will return the deposit via Razorpay.",
                  style: TextStyle(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Close the dialog

                // 🚀 ROUTING LOGIC: Where do we go next?
                if (isDamaged) {
                  // They claim damage! Send them to upload photo evidence.
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DisputeScreen(rentalId: rentalId),
                    ),
                  );
                } else {
                  // Tool is fine! Run the refund instantly.
                  _executeFinalAction(rentalId, data, rating, false);
                }
              },
              child: Text(isDamaged ? "Next: Provide Evidence" : "Confirm Refund"),
            )
          ],
        ),
      ),
    );
  }

  // --- THE RAZORPAY REPAYMENT + DB UPDATE ---
  Future<void> _executeFinalAction(String rentalId, Map<String, dynamic> data, int rating, bool isDamaged) async {
    showDialog(context: context, builder: (_) => const Center(child: CircularProgressIndicator()));

    bool success = true;
    if (!isDamaged) {
      // 💸 CALL RAZORPAY API
      success = await _processRepayment(data['paymentId'], data['securityDeposit']);
    }

    if (success) {
      await FirebaseFirestore.instance.collection('rentals').doc(rentalId).update({
        'status': isDamaged ? 'Disputed' : 'Completed',
        'securityDepositStatus': isDamaged ? 'Withheld' : 'Refunded',
        'lenderReviewed': true,
      });
      // Also update the borrower's trust score...
      await _updateBorrowerScore(data['borrowerId'], rating);
    }

    if (mounted) {
      Navigator.pop(context); // Close loading
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(success ? "Action Successful" : "Razorpay Refund Failed!"),
        backgroundColor: success ? Colors.green : Colors.red,
      ));
    }
  }

  Future<bool> _processRepayment(String? paymentId, dynamic amount) async {
    if (paymentId == null) return false;

    // Razorpay uses Paise
    int amountInPaise = (double.parse(amount.toString()) * 100).toInt();
    String basicAuth = 'Basic ${base64Encode(utf8.encode('$rzpKeyId:$rzpKeySecret'))}';

    try {
      var response = await http.post(
        Uri.parse('https://api.razorpay.com/v1/payments/$paymentId/refund'),
        headers: {'Authorization': basicAuth, 'Content-Type': 'application/json'},
        body: jsonEncode({"amount": amountInPaise}),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<void> _updateBorrowerScore(String borrowerId, int newRating) async {
    var ref = FirebaseFirestore.instance.collection('users').doc(borrowerId);
    var doc = await ref.get();
    if (doc.exists) {
      double currentScore = (doc.data() as Map<String, dynamic>)['trustScore']?.toDouble() ?? 5.0;
      int count = (doc.data() as Map<String, dynamic>)['reviewCount']?.toInt() ?? 0;
      double newScore = ((currentScore * count) + newRating) / (count + 1);
      await ref.update({'trustScore': newScore, 'reviewCount': count + 1});
    }
  }
}