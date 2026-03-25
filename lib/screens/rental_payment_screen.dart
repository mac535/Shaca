import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'payment_success_screen.dart';

class RentalPaymentScreen extends StatefulWidget {
  final String rentalId;
  final Map<String, dynamic> rentalData;

  const RentalPaymentScreen({super.key, required this.rentalId, required this.rentalData});

  @override
  State<RentalPaymentScreen> createState() => _RentalPaymentScreenState();
}

class _RentalPaymentScreenState extends State<RentalPaymentScreen> {
  bool _isProcessing = false;
  bool _agreedToTerms = false; // 🛑 New: Checkbox state for Security Deposit
  late Razorpay _razorpay;

  // Financial Breakdown Variables
  late double rentalFee;
  late double securityDeposit;
  late double totalAmount;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    // 🎧 Listeners for Razorpay events
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);

    // 💰 Calculate the breakdown
    rentalFee = (widget.rentalData['totalAmount'] ?? 100).toDouble();
    // Assuming a default 500 deposit if owner didn't set one for now
    securityDeposit = (widget.rentalData['securityDeposit'] ?? 500).toDouble();
    totalAmount = rentalFee + securityDeposit;
  }

  @override
  void dispose() {
    _razorpay.clear(); // 🧹 Clean up memory
    super.dispose();
  }

  // 💳 1. OPEN RAZORPAY CHECKOUT
  void _openCheckout() {
    setState(() => _isProcessing = true);

    var options = {
      'key': 'rzp_test_SUEgr0VtN9Exrh', // 🔑 Your preserved RZP TEST KEY
      'amount': (totalAmount * 100).toInt(), // Charge the FULL amount (Fee + Deposit)
      'name': 'ShaCa Community',
      'description': 'Rent + Deposit for ${widget.rentalData['toolName'] ?? 'Tool'}',
      'prefill': {
        'contact': '9876543210',
        'email': 'user@example.com'
      },
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      debugPrint('Error launching Razorpay: $e');
      setState(() => _isProcessing = false);
    }
  }

  // ✅ 2. PAYMENT SUCCESSFUL -> RUN DATABASE UPDATE
  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    debugPrint("Payment ID: ${response.paymentId}");
    await _secureToolInDatabase(response.paymentId!);
  }

  // ❌ 3. PAYMENT FAILED
  void _handlePaymentError(PaymentFailureResponse response) {
    setState(() => _isProcessing = false);
    _showErrorDialog("Payment Failed", response.message ?? "Something went wrong.");
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    debugPrint("External Wallet Selected: ${response.walletName}");
  }

  // 🛡️ 4. THE SECURE TRANSACTION LOGIC
  Future<void> _secureToolInDatabase(String paymentId) async {
    final String toolId = widget.rentalData['toolId'];
    final DocumentReference toolRef = FirebaseFirestore.instance.collection('tools').doc(toolId);
    final DocumentReference rentalRef = FirebaseFirestore.instance.collection('rentals').doc(widget.rentalId);

    try {
      // 🔒 The Transaction: All or Nothing
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentSnapshot toolSnap = await transaction.get(toolRef);

        if (!toolSnap.exists) {
          throw Exception("Tool no longer exists.");
        }

        transaction.update(rentalRef, {
          'status': 'paid_pending_pickup',
          'paymentId': paymentId,
          'paidAt': FieldValue.serverTimestamp(),
          'rentalFeePaid': rentalFee,
          'securityDeposit': securityDeposit, // ✅ Matches the Owner Dashboard perfectly!
          'totalPaid': totalAmount,
        });
      });

      // ✅ Success! Navigate to confirmation
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => PaymentSuccessScreen(
            toolName: widget.rentalData['toolName'] ?? 'Tool',
          ),
        ),
      );

    } catch (e) {
      if (!mounted) return;
      _showErrorDialog("Booking Error", e.toString().replaceAll("Exception:", ""));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showErrorDialog(String title, String msg) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Verify & Pay")),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Lender's Live Condition Photo:", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  // 📸 Showing the photo the owner JUST took
                  ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: widget.rentalData['liveImageUrl'] != null && widget.rentalData['liveImageUrl'] != ''
                        ? Image.network(
                      widget.rentalData['liveImageUrl'],
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 200,
                        color: Colors.grey[300],
                        child: const Icon(Icons.broken_image, size: 50),
                      ),
                    )
                        : Container(
                      height: 200,
                      color: Colors.grey[300],
                      child: const Center(child: Text("No image available")),
                    ),
                  ),

                  const SizedBox(height: 30),
                  const Text("Payment Breakdown", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),

                  // 🧾 THE RECEIPT UI
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [const Text("Rental Fee"), Text("₹${rentalFee.toStringAsFixed(0)}")],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [const Text("Refundable Security Deposit"), Text("₹${securityDeposit.toStringAsFixed(0)}")],
                        ),
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Total to Pay", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            Text("₹${totalAmount.toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green))
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 🛑 THE MANDATORY CHECKBOX
                  CheckboxListTile(
                    activeColor: const Color(0xFFFF8C00),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text(
                      "I agree to pay the security deposit. I understand that if the tool is returned damaged, the owner may deduct repair costs from this deposit.",
                      style: TextStyle(fontSize: 13, color: Colors.black87),
                    ),
                    value: _agreedToTerms,
                    onChanged: (bool? value) {
                      setState(() => _agreedToTerms = value ?? false);
                    },
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _agreedToTerms ? Colors.green : Colors.grey, // Grey if not checked
                ),
                onPressed: (!_agreedToTerms || _isProcessing) ? null : _openCheckout,
                child: _isProcessing
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text("PAY ₹${totalAmount.toStringAsFixed(0)}", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
          )
        ],
      ),
    );
  }
}