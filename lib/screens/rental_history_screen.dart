import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'root_screen.dart';
import 'handshake_screen.dart';

class RentalHistoryScreen extends StatelessWidget {
  const RentalHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Rental History')),
        body: const Center(child: Text("Please log in to view your history.")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Rentals', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      backgroundColor: Colors.grey[100],
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('rentals')
            .where('borrowerId', isEqualTo: currentUser.uid)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFFF8C00)));
          }

          if (snapshot.hasError) {
            debugPrint("History Error: ${snapshot.error}");
            return const Center(child: Text('Something went wrong. Please try again later.'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_toggle_off, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text(
                    "You haven't rented any tools yet!",
                    style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF8C00),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    onPressed: () {
                      RootScreen.tabNotifier.value = 0;
                      Navigator.popUntil(context, ModalRoute.withName('/'));
                    },
                    icon: const Icon(Icons.search, color: Colors.white),
                    label: const Text(
                      "Browse Tools to Rent",
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            );
          }

          final rentals = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: rentals.length,
            itemBuilder: (context, index) {
              final rentalId = rentals[index].id;
              final rental = rentals[index].data() as Map<String, dynamic>;

              final status = rental['status'] ?? '';
              final isActive = status == 'Active';
              final isPendingPickup = status == 'paid_pending_pickup';

              // 📅 Date Logic
              String dateStr = 'Unknown Date';
              if (rental['createdAt'] != null) {
                DateTime dt = (rental['createdAt'] as Timestamp).toDate();
                dateStr = "${dt.day}/${dt.month}/${dt.year}";
              }

              // 🚨 Due Date Logic for Alert Banner
              bool isDueSoon = false;
              String dueMessage = '';
              if (isActive && rental['endDate'] != null) {
                DateTime endDate = (rental['endDate'] as Timestamp).toDate();
                DateTime now = DateTime.now();

                DateTime todayDate = DateTime(now.year, now.month, now.day);
                DateTime returnDate = DateTime(endDate.year, endDate.month, endDate.day);

                int daysDifference = returnDate.difference(todayDate).inDays;

                if (daysDifference < 0) {
                  isDueSoon = true;
                  dueMessage = "⚠️ RETURN OVERDUE";
                } else if (daysDifference == 0) {
                  isDueSoon = true;
                  dueMessage = "🚨 RETURN DUE TODAY";
                } else if (daysDifference == 1) {
                  isDueSoon = true;
                  dueMessage = "⏳ RETURN DUE TOMORROW";
                }
              }

              // ==========================================
              // 🛡️ SECURITY DEPOSIT BADGE LOGIC
              // ==========================================
              String depositStatus = rental['securityDepositStatus'] ?? 'Pending';
              Color badgeColor;
              IconData badgeIcon;
              String displayMessage;

              if (depositStatus == 'Refunded' || depositStatus == 'Partially_Refunded') {
                badgeColor = Colors.green;
                badgeIcon = Icons.check_circle;
                displayMessage = depositStatus == 'Refunded' ? "Deposit Refunded" : "Deposit Partially Refunded";
              } else if (depositStatus == 'Withheld' || depositStatus == 'Disputed' || depositStatus == 'Forfeited_to_Owner') {
                badgeColor = Colors.red;
                badgeIcon = Icons.gavel;
                displayMessage = "Deposit Disputed / Held";
              } else {
                badgeColor = Colors.orange;
                badgeIcon = Icons.shield;
                displayMessage = "Deposit Held Safely";
              }

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 16),
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey[200]!),
                ),
                child: Column(
                  children: [
                    if (isDueSoon)
                      Container(
                        width: double.infinity,
                        color: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          dueMessage,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                        ),
                      ),

                    ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: (isActive || isPendingPickup)
                              ? const Color(0xFFFF8C00).withOpacity(0.1)
                              : Colors.grey[200],
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.handyman,
                          color: (isActive || isPendingPickup) ? const Color(0xFFFF8C00) : Colors.grey[600],
                        ),
                      ),
                      title: Text(
                        rental['toolName'] ?? 'Unknown Tool',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Expanded(child: Text(dateStr, style: TextStyle(color: Colors.grey[700]), overflow: TextOverflow.ellipsis)),
                            const SizedBox(width: 8),
                            Icon(Icons.payments_outlined, size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Expanded(child: Text('₹${rental['totalPaid'] ?? rental['totalCost'] ?? 0}', style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                          ],
                        ),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isActive ? Colors.green.withOpacity(0.1) :
                          isPendingPickup ? Colors.orange.withOpacity(0.1) : Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          status.replaceAll('_', ' ').toUpperCase(),
                          style: TextStyle(
                            color: isActive ? Colors.green[700] :
                            isPendingPickup ? Colors.orange[800] : Colors.grey[600],
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),

                    // ==========================================
                    // 🛡️ THE BADGE UI RENDERED HERE
                    // ==========================================
                    Padding(
                      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: badgeColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: badgeColor.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(badgeIcon, color: badgeColor, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              displayMessage,
                              style: TextStyle(
                                color: badgeColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // 🚀 ACTION BUTTONS FOR THE HANDSHAKE
                    if (isPendingPickup || isActive)
                      Padding(
                        padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                        child: SizedBox(
                          width: double.infinity,
                          height: 45,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isPendingPickup ? Colors.blue : const Color(0xFFFF8C00),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => HandshakeScreen(
                                    rentalId: rentalId,
                                    rentalData: rental,
                                    isLender: false,
                                    actionType: isPendingPickup ? 'pickup' : 'return',
                                  ),
                                ),
                              );
                            },
                            icon: Icon(isPendingPickup ? Icons.handshake : Icons.assignment_return, color: Colors.white),
                            label: Text(
                              isPendingPickup ? "Meet Owner to Pick Up" : "Return Tool to Owner",
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      )
                    // ⭐ THE NEW REVIEW BUTTON
                    else if (status.toLowerCase().contains('return') && rental['borrowerReviewed'] != true)
                      Padding(
                        padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                        child: SizedBox(
                          width: double.infinity,
                          height: 45,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber, // Gold for stars!
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () {
                              showReviewDialog(context, rental, rentalId, false); // false = they are the Borrower
                            },
                            icon: const Icon(Icons.star, color: Colors.black87),
                            label: const Flexible(
                              child: Text(
                                "Leave a Review",
                                style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ============================================================================
// ⭐ REVIEW DIALOG & TRUST SCORE MATH
// ============================================================================

void showReviewDialog(BuildContext context, Map<String, dynamic> rental, String rentalId, bool isLender) {
  int selectedRating = 5;

  showDialog(
    context: context,
    barrierDismissible: false, // Prevents tapping outside to close
    builder: (context) {
      return PopScope(
        canPop: false,
        child: StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text("Leave a Review ⭐", textAlign: TextAlign.center),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isLender ? "How was the Borrower?" : "Rate the Tool & Owner:",
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),

                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 0,
                    children: List.generate(5, (index) {
                      return IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: Icon(
                          index < selectedRating ? Icons.star : Icons.star_border,
                          color: const Color(0xFFFF8C00),
                          size: 36,
                        ),
                        onPressed: () => setState(() => selectedRating = index + 1),
                      );
                    }),
                  ),
                ],
              ),
              actionsAlignment: MainAxisAlignment.center,
              actions: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF8C00),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () async {
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) => const Center(child: CircularProgressIndicator()),
                      );

                      await _submitReviewToDatabase(rental, rentalId, isLender, selectedRating);

                      if (context.mounted) {
                        Navigator.pop(context); // Pop loading circle
                        Navigator.pop(context); // Pop review dialog
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Review submitted! Trust Score updated."), backgroundColor: Colors.green),
                        );
                      }
                    },
                    child: const Text("Submit Review", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ],
            );
          },
        ),
      );
    },
  );
}

Future<void> _submitReviewToDatabase(Map<String, dynamic> rental, String rentalId, bool isLender, int rating) async {
  final db = FirebaseFirestore.instance;

  String targetUserId = isLender ? rental['borrowerId'] : rental['lenderId'];
  String toolId = rental['toolId'];

  try {
    await db.runTransaction((transaction) async {
      DocumentReference rentalRef = db.collection('rentals').doc(rentalId);
      transaction.update(rentalRef, {
        isLender ? 'lenderReviewed' : 'borrowerReviewed': true,
      });

      DocumentReference userRef = db.collection('users').doc(targetUserId);
      DocumentSnapshot userDoc = await transaction.get(userRef);

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>?;
        double currentScore = (userData != null && userData.containsKey('trustScore')) ? (userData['trustScore'] as num).toDouble() : 5.0;
        int reviewCount = (userData != null && userData.containsKey('reviewCount')) ? (userData['reviewCount'] as num).toInt() : 0;

        double newScore = ((currentScore * reviewCount) + rating) / (reviewCount + 1);

        transaction.update(userRef, {
          'trustScore': double.parse(newScore.toStringAsFixed(1)),
          'reviewCount': reviewCount + 1,
        });
      }

      if (!isLender) {
        DocumentReference toolRef = db.collection('tools').doc(toolId);
        DocumentSnapshot toolDoc = await transaction.get(toolRef);

        if (toolDoc.exists) {
          final toolData = toolDoc.data() as Map<String, dynamic>?;
          double currentToolScore = (toolData != null && toolData.containsKey('rating')) ? (toolData['rating'] as num).toDouble() : 5.0;
          int toolReviewCount = (toolData != null && toolData.containsKey('reviewCount')) ? (toolData['reviewCount'] as num).toInt() : 0;

          double newToolScore = ((currentToolScore * toolReviewCount) + rating) / (toolReviewCount + 1);

          transaction.update(toolRef, {
            'rating': double.parse(newToolScore.toStringAsFixed(1)),
            'reviewCount': toolReviewCount + 1,
          });
        }
      }
    });
  } catch (e) {
    debugPrint("Failed to submit review: $e");
  }
}