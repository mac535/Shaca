import 'package:flutter/material.dart';
import 'root_screen.dart';

class PaymentSuccessScreen extends StatelessWidget {
  final String toolName;
  final bool isCart;

  const PaymentSuccessScreen({super.key, required this.toolName, this.isCart = false});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_rounded, size: 100, color: Colors.green),
            const SizedBox(height: 24),
            Text(
              isCart ? "Orders Secured!" : "Tool Secured!",
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
            ),
            const SizedBox(height: 12),
            Text(
              isCart 
                ? "Your rentals have been confirmed. You can find them in your Rental History."
                : "You have successfully rented $toolName. Please coordinate with the owner for pickup.",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF8C00),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  RootScreen.tabNotifier.value = 0;
                  Navigator.popUntil(context, (route) => route.isFirst);
                },
                child: const Text("Go to Home", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
