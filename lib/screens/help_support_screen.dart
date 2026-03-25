import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & Support', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.white,
      ),
      backgroundColor: Colors.grey[50],
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // 🛑 1. CONTACT SECTION
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFFF8C00).withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFF8C00).withOpacity(0.3)),
            ),
            child: Column(
              children: [
                const Icon(Icons.support_agent, size: 50, color: Color(0xFFFF8C00)),
                const SizedBox(height: 12),
                const Text(
                  "Need Immediate Help?",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
                ),
                const SizedBox(height: 8),
                const Text(
                  "If a tool is damaged or a user is unresponsive, contact the ShaCa admin team directly.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, height: 1.4),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF8C00),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () async {
                      // 🚀 THE REAL EMAIL LAUNCHER
                      final Uri emailLaunchUri = Uri(
                        scheme: 'mailto',
                        path: 'support@shaca.com', // Put your actual admin email here!
                        query: 'subject=ShaCa App Support Request', // Pre-fills the subject line
                      );

                      try {
                        if (await canLaunchUrl(emailLaunchUri)) {
                          await launchUrl(emailLaunchUri);
                        } else {
                          // Fallback if they don't have an email app installed
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("No email app found. Please email support@shaca.com directly."))
                            );
                          }
                        }
                      } catch (e) {
                        debugPrint("Error launching email: $e");
                      }
                    },
                    icon: const Icon(Icons.email, color: Colors.white),
                    label: const Text("Email Support Team", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              'Frequently Asked Questions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
            ),
          ),

          // 🛑 2. FAQ SECTION
          _buildFaqTile(
              "How does the QR Handshake work?",
              "When picking up or returning a tool, the borrower generates a QR code on their screen, and the owner scans it to instantly verify the exchange and update the database safely."
          ),
          _buildFaqTile(
              "What if a tool breaks while I'm using it?",
              "Safety first! Stop using the tool immediately. Do NOT attempt to fix it yourself. Use the Contact Support button above to notify the admins, and message the owner."
          ),
          _buildFaqTile(
              "Why is my account restricted?",
              "Accounts may be restricted if you have an overdue tool or if you moved to a new society location while still having active rentals. Return the tools to unlock your account."
          ),
          _buildFaqTile(
              "How do I get my deposit back?",
              "Once the owner scans your Return QR Code and marks the tool as safely returned, any held deposits are automatically released back to your original payment method."
          ),
        ],
      ),
    );
  }

  Widget _buildFaqTile(String question, String answer) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: Theme(
        data: ThemeData().copyWith(dividerColor: Colors.transparent), // Removes the ugly default lines
        child: ExpansionTile(
          iconColor: const Color(0xFFFF8C00),
          title: Text(question, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2C3E50), fontSize: 14)),
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
              child: Text(answer, style: const TextStyle(color: Colors.grey, height: 1.5)),
            ),
          ],
        ),
      ),
    );
  }
}