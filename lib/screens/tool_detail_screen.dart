import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'rental_request_screen.dart';
import 'rental_payment_screen.dart';
import 'package:intl/intl.dart';
import 'login_screen.dart';

class ToolDetailScreen extends StatefulWidget {
  final String toolId;
  final Map<String, dynamic> toolData;

  const ToolDetailScreen({super.key, required this.toolId, required this.toolData});

  @override
  State<ToolDetailScreen> createState() => _ToolDetailScreenState();
}

class _ToolDetailScreenState extends State<ToolDetailScreen> {
  bool _isSaved = false;

  @override
  void initState() {
    super.initState();
    _checkIfSaved();
  }

  Future<void> _checkIfSaved() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (userDoc.exists) {
      List<dynamic> savedTools = (userDoc.data() as Map<String, dynamic>)['savedTools'] ?? [];
      if (mounted) {
        setState(() {
          _isSaved = savedTools.contains(widget.toolId);
        });
      }
    }
  }

  Future<void> _toggleSavedItem() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Log in to save tools!")));
      return;
    }

    final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);

    setState(() => _isSaved = !_isSaved);

    try {
      if (_isSaved) {
        await userRef.update({'savedTools': FieldValue.arrayUnion([widget.toolId])});
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Added to Saved Items')));
      } else {
        await userRef.update({'savedTools': FieldValue.arrayRemove([widget.toolId])});
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Removed from Saved')));
      }
    } catch (e) {
      setState(() => _isSaved = !_isSaved);
      debugPrint("Error saving tool: $e");
    }
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Ad?"),
        content: const Text("This will permanently remove your tool from the community. This action cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => _deleteTool(context),
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteTool(BuildContext context) async {
    try {
      final activeRentals = await FirebaseFirestore.instance
          .collection('rentals')
          .where('toolId', isEqualTo: widget.toolId)
          .where('status', isEqualTo: 'Active')
          .get();

      if (activeRentals.docs.isNotEmpty) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Cannot delete! You have active rentals for this tool."),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      await FirebaseFirestore.instance.collection('tools').doc(widget.toolId).delete();

      if (!mounted) return;
      Navigator.pop(context);
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Ad deleted successfully.")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error deleting: $e"), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    double price = (widget.toolData['pricePerDay'] ?? 0.0).toDouble();
    bool isAvailable = widget.toolData['isAvailable'] ?? true;

    final currentUser = FirebaseAuth.instance.currentUser;
    final bool isOwner = currentUser != null && widget.toolData['ownerId'] == currentUser.uid;

    return Scaffold(
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: currentUser == null
                ? ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF8C00),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              },
              child: const Text('Log in to Rent', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            )
                : isOwner
                ? ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: null,
              child: const Text('This is your tool', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            )
                : !isAvailable
                ? ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[300],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: null,
              child: const Text('Temporarily Unavailable', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            )
                : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('rentals')
                  .where('toolId', isEqualTo: widget.toolId)
                  .where('borrowerId', isEqualTo: currentUser.uid)
                  .where('status', whereIn: ['pending_verification', 'pending_payment'])
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                  var rentalData = snapshot.data!.docs.first.data() as Map<String, dynamic>;
                  String status = rentalData['status'] ?? '';

                  if (status == 'pending_verification') {
                    return ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: null,
                      child: const Text('Waiting for Owner ⏳', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                    );
                  }

                  if (status == 'pending_payment') {
                    return ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RentalPaymentScreen(
                              rentalId: snapshot.data!.docs.first.id,
                              rentalData: rentalData,
                            ),
                          ),
                        );
                      },
                      child: const Text('Pay to Secure Tool 💳', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                    );
                  }
                }

                return ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF8C00),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RentalRequestScreen(
                          toolId: widget.toolId,
                          toolData: widget.toolData,
                        ),
                      ),
                    );
                  },
                  child: const Text('Request to Rent', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                );
              },
            ),
          ),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(widget.toolData['name'] ?? 'Tool', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              background: Hero(
                tag: widget.toolId,
                child: Image.network(
                  widget.toolData['imageUrl'] ?? '',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(color: Colors.grey, child: const Icon(Icons.image_not_supported, size: 50, color: Colors.white)),
                ),
              ),
            ),
            actions: [
              if (isOwner)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: CircleAvatar(
                    backgroundColor: Colors.white.withOpacity(0.9),
                    child: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _showDeleteConfirmation(context),
                    ),
                  ),
                ),

              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: CircleAvatar(
                  backgroundColor: Colors.white.withOpacity(0.9),
                  child: IconButton(
                    icon: Icon(
                      _isSaved ? Icons.favorite : Icons.favorite_border,
                      color: _isSaved ? Colors.red : Colors.grey[700],
                    ),
                    onPressed: _toggleSavedItem,
                  ),
                ),
              ),
            ],
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF8C00).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          widget.toolData['category'] ?? '',
                          style: const TextStyle(color: Color(0xFFFF8C00), fontWeight: FontWeight.bold),
                        ),
                      ),
                      Text(
                        '₹${price.toStringAsFixed(0)}/day',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),

                  if (!isAvailable)
                    Container(
                      margin: const EdgeInsets.only(top: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.block, color: Colors.red, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "The owner has temporarily paused rentals for this tool.",
                              style: TextStyle(color: Colors.red[800], fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 32),
                  const Text('Description', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text(
                    'Well-maintained tool available for rent within your society. '
                        'Easy pickup, flexible usage, and trusted neighbourhood sharing.',
                    style: TextStyle(color: Colors.grey, fontSize: 16, height: 1.5),
                  ),

                  const SizedBox(height: 32),
                  const Text('Owner Profile', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),

                  // ==========================================
                  // ⭐ OWNER'S TRUST SCORE UI
                  // ==========================================
                  FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance.collection('users').doc(widget.toolData['ownerId']).get(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      var ownerData = snapshot.data!.data() as Map<String, dynamic>?;
                      double trustScore = (ownerData != null && ownerData.containsKey('trustScore'))
                          ? (ownerData['trustScore'] as num).toDouble()
                          : 5.0; // Default to 5.0
                      int reviews = (ownerData != null && ownerData.containsKey('reviewCount'))
                          ? (ownerData['reviewCount'] as num).toInt()
                          : 0;

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 25,
                              backgroundColor: Colors.grey[300],
                              child: const Icon(Icons.person, color: Colors.white, size: 30),
                            ),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    ownerData?['name'] ?? "Community Member",
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.star, color: Colors.amber, size: 18),
                                    const SizedBox(width: 4),
                                    Text(
                                      "$trustScore ($reviews reviews)",
                                      style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  // ==========================================

                  if (currentUser != null && !isOwner) ...[
                    const SizedBox(height: 32),
                    const Text('Your Bookings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('rentals')
                          .where('toolId', isEqualTo: widget.toolId)
                          .where('borrowerId', isEqualTo: currentUser.uid)
                          .where('status', isEqualTo: 'Active')
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return Text(
                            "You haven't booked this tool yet.",
                            style: TextStyle(color: Colors.grey[400], fontSize: 14),
                          );
                        }

                        return Column(
                          children: snapshot.data!.docs.map((doc) {
                            var data = doc.data() as Map<String, dynamic>;
                            DateTime start = (data['startDate'] as Timestamp).toDate();
                            DateTime end = (data['endDate'] as Timestamp).toDate();

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.green.withOpacity(0.2)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.event_available, color: Colors.green, size: 22),
                                  const SizedBox(width: 12),
                                  Text(
                                    "${DateFormat('MMM dd').format(start)} - ${DateFormat('MMM dd, yyyy').format(end)}",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.green,
                                    ),
                                  ),
                                  const Spacer(),
                                  const Text("Paid", style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}