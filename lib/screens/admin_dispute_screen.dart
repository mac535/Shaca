import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AdminDisputeScreen extends StatefulWidget {
  const AdminDisputeScreen({super.key});

  @override
  State<AdminDisputeScreen> createState() => _AdminDisputeScreenState();
}

class _AdminDisputeScreenState extends State<AdminDisputeScreen> {
  // 🚨 YOUR RAZORPAY KEYS
  final String rzpKeyId = "rzp_test_SUEgr0VtN9Exrh";
  final String rzpKeySecret = "YOUR_SECRET_KEY_HERE";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Admin: Active Disputes", style: TextStyle(color: Colors.white)), backgroundColor: Colors.red[800]),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('rentals').where('status', isEqualTo: 'Disputed').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final disputes = snapshot.data!.docs;
          if (disputes.isEmpty) return const Center(child: Text("No active disputes! 🎉"));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: disputes.length,
            itemBuilder: (context, index) {
              var rental = disputes[index].data() as Map<String, dynamic>;
              String rentalId = disputes[index].id;
              double maxDeposit = (rental['securityDeposit'] ?? 0).toDouble();

              return Card(
                elevation: 4,
                margin: const EdgeInsets.only(bottom: 20),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Tool: ${rental['toolName']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      const SizedBox(height: 8),
                      Text("Lender's Claim: ${rental['damageDescription'] ?? 'No description'}"),
                      const SizedBox(height: 10),

                      // 📸 Display the evidence
                      if (rental['damageImageUrl'] != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(rental['damageImageUrl'], height: 150, width: double.infinity, fit: BoxFit.cover),
                        ),

                      const SizedBox(height: 16),
                      Text("Max Deposit Available: ₹$maxDeposit", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                      const SizedBox(height: 10),

                      // ⚖️ Admin Resolution Action
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, minimumSize: const Size(double.infinity, 45)),
                        onPressed: () => _showResolutionDialog(rentalId, rental, maxDeposit),
                        child: const Text("Resolve & Move Money", style: TextStyle(color: Colors.white)),
                      )
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // --- THE ADMIN RESOLUTION POPUP ---
  void _showResolutionDialog(String rentalId, Map<String, dynamic> rental, double maxDeposit) {
    TextEditingController refundController = TextEditingController(text: maxDeposit.toStringAsFixed(0));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Resolve Dispute"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("How much of the deposit should be REFUNDED to the Renter? (The rest goes to the Lender for repairs)."),
            const SizedBox(height: 16),
            TextField(
              controller: refundController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: "Refund Amount (Max ₹$maxDeposit)",
                prefixText: "₹ ",
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () {
              double refundAmount = double.tryParse(refundController.text) ?? 0;
              if (refundAmount > maxDeposit || refundAmount < 0) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid amount!")));
                return;
              }
              Navigator.pop(context);
              _processAdminResolution(rentalId, rental, refundAmount);
            },
            child: const Text("Execute Transfer"),
          )
        ],
      ),
    );
  }

  // --- AUTOMATED MONEY MOVEMENT & DB UPDATE ---
  Future<void> _processAdminResolution(String rentalId, Map<String, dynamic> rental, double refundAmount) async {
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));

    bool apiSuccess = true;
    String paymentId = rental['paymentId'] ?? '';

    // 💸 1. Trigger Razorpay API if there is an actual refund happening
    if (refundAmount > 0 && paymentId.isNotEmpty) {
      int amountInPaise = (refundAmount * 100).toInt();
      String basicAuth = 'Basic ${base64Encode(utf8.encode('$rzpKeyId:$rzpKeySecret'))}';

      try {
        var response = await http.post(
          Uri.parse('https://api.razorpay.com/v1/payments/$paymentId/refund'),
          headers: {'Authorization': basicAuth, 'Content-Type': 'application/json'},
          body: jsonEncode({"amount": amountInPaise}),
        );
        if (response.statusCode != 200) apiSuccess = false;
      } catch (e) {
        apiSuccess = false;
      }
    }

    if (!apiSuccess) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Razorpay API Failed!"), backgroundColor: Colors.red));
      }
      return;
    }

    // 🗄️ 2. Update Firestore
    try {
      await FirebaseFirestore.instance.collection('rentals').doc(rentalId).update({
        'status': 'Resolved',
        'securityDepositStatus': refundAmount == 0 ? 'Forfeited_to_Lender' : 'Partially_Refunded',
        'amountRefundedToRenter': refundAmount,
        'resolvedAt': FieldValue.serverTimestamp(),
      });

      // Make tool available again
      await FirebaseFirestore.instance.collection('tools').doc(rental['toolId']).update({'isAvailable': true});

    } catch (e) {
      debugPrint("DB Update Error: $e");
    }

    if (mounted) {
      Navigator.pop(context); // Close loading
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Dispute Resolved. ₹$refundAmount refunded."), backgroundColor: Colors.green));
    }
  }
}