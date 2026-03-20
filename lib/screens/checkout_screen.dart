import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/cart_service.dart';
import 'payment_success_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  String _selectedUPI = 'Google Pay';
  final List<String> _upiApps = ['Google Pay', 'PhonePe', 'Paytm', 'Amazon Pay'];
  bool _isProcessing = false;

  Future<void> _processPayment(CartService cart) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showError("You must be logged in to checkout.");
      return;
    }

    setState(() => _isProcessing = true);

    try {
      await Future.delayed(const Duration(seconds: 2));
      final batch = FirebaseFirestore.instance.batch();

      for (var entry in cart.items.entries) {
        String toolId = entry.key;
        CartItem item = entry.value;

        DocumentSnapshot toolDoc = await FirebaseFirestore.instance.collection('tools').doc(toolId).get();
        if (!toolDoc.exists) continue;

        String lenderId = toolDoc['ownerId'] ?? 'Unknown';

        DocumentReference rentalRef = FirebaseFirestore.instance.collection('rentals').doc();
        batch.set(rentalRef, {
          'toolId': toolId,
          'toolName': item.name,
          'borrowerId': user.uid,
          'lenderId': lenderId,
          'totalCost': item.totalItemPrice,
          'days': item.days,
          'paymentMethod': _selectedUPI,
          'status': 'Active', 
          'createdAt': FieldValue.serverTimestamp(),
          'startDate': Timestamp.fromDate(DateTime.now()),
          'endDate': Timestamp.fromDate(DateTime.now().add(Duration(days: item.days - 1))),
        });

        DocumentReference toolUpdateRef = FirebaseFirestore.instance.collection('tools').doc(toolId);
        batch.update(toolUpdateRef, {'isAvailable': false});
      }

      await batch.commit();
      cart.clearCart();

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const PaymentSuccessScreen(
            toolName: "Multiple Tools",
            isCart: true,
          ),
        ),
      );

    } catch (e) {
      _showError("Payment Failed: $e");
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartService>(context);

    if (cart.items.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (Navigator.canPop(context)) Navigator.pop(context);
      });
      return const Scaffold();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Secure Checkout', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Order Summary", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[200]!)),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Items (${cart.itemCount})", style: const TextStyle(fontSize: 16, color: Colors.grey)),
                      Text("₹${cart.grandTotal.toStringAsFixed(0)}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const Divider(height: 24),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Platform Fee", style: TextStyle(fontSize: 16, color: Colors.grey)),
                      Text("₹0", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green)), 
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Total to Pay", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text("₹${cart.grandTotal.toStringAsFixed(0)}", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFFFF8C00))),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Text("Select Payment Method", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[200]!)),
              child: Column(
                children: _upiApps.map((upi) => RadioListTile<String>(
                  title: Text(upi, style: const TextStyle(fontWeight: FontWeight.bold)),
                  activeColor: const Color(0xFFFF8C00),
                  value: upi,
                  groupValue: _selectedUPI,
                  onChanged: (value) => setState(() => _selectedUPI = value!),
                )).toList(),
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2C3E50), 
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isProcessing ? null : () => _processPayment(cart),
                icon: _isProcessing
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.security, color: Colors.white),
                label: _isProcessing
                    ? const Text("Processing Securely...", style: TextStyle(color: Colors.white, fontSize: 16))
                    : Text("Pay ₹${cart.grandTotal.toStringAsFixed(0)} securely", style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 16),
            const Center(
              child: Text("🔒 100% Secure & Encrypted Transaction", style: TextStyle(color: Colors.grey, fontSize: 12)),
            )
          ],
        ),
      ),
    );
  }
}
