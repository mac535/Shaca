import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'add_item_screen.dart'; // Make sure this matches your 'Add Tool' screen file name!

class MyListedToolsScreen extends StatelessWidget {
  const MyListedToolsScreen({super.key});

  Future<void> _deleteTool(BuildContext context, String toolId) async {
    bool? confirm = await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Delete Tool?"),
          content: const Text("Are you sure you want to permanently delete this listing? You cannot undo this."),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Delete", style: TextStyle(color: Colors.white)),
            ),
          ],
        )
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance.collection('tools').doc(toolId).delete();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Tool deleted successfully."), backgroundColor: Colors.redAccent),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
        }
      }
    }
  }

  Future<void> _toggleAvailability(BuildContext context, String toolId, bool currentStatus) async {
    try {
      await FirebaseFirestore.instance.collection('tools').doc(toolId).update({
        'isAvailable': !currentStatus,
      });
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error updating status: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Listed Tools')),
        body: const Center(child: Text("Please log in to manage your tools.")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Listed Tools', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.white,
      ),
      backgroundColor: Colors.grey[100],

      // Floating button so they can quickly add more tools!
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const AddItemScreen()));
        },
        backgroundColor: const Color(0xFFFF8C00),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Add Tool", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),

      body: StreamBuilder<QuerySnapshot>(
        // Fetch all tools owned by this user
        stream: FirebaseFirestore.instance
            .collection('tools')
            .where('ownerId', isEqualTo: user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFFF8C00)));
          }

          if (snapshot.hasError) {
            return const Center(child: Text('Error loading your tools.'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.handyman_outlined, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text(
                    "You haven't listed any tools yet.",
                    style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Earn money by renting out your idle equipment!",
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          // We sort locally in Dart to prevent Firebase Index errors!
          var tools = snapshot.data!.docs.toList();
          tools.sort((a, b) {
            Timestamp? timeA = (a.data() as Map<String, dynamic>)['createdAt'];
            Timestamp? timeB = (b.data() as Map<String, dynamic>)['createdAt'];
            if (timeA == null || timeB == null) return 0;
            return timeB.compareTo(timeA); // Newest first
          });

          return ListView.builder(
            padding: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 80), // Bottom padding for FAB
            itemCount: tools.length,
            itemBuilder: (context, index) {
              final tool = tools[index].data() as Map<String, dynamic>;
              final toolId = tools[index].id;

              bool isAvailable = tool['isAvailable'] ?? true;
              String imageUrl = tool['imageUrl'] ?? '';

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    Row(
                      children: [
                        // Tool Image
                        Container(
                          width: 100,
                          height: 100,
                          color: Colors.grey[200],
                          child: imageUrl.isNotEmpty
                              ? Image.network(imageUrl, fit: BoxFit.cover)
                              : const Icon(Icons.handyman, size: 40, color: Colors.grey),
                        ),

                        // Tool Info
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tool['name'] ?? 'Unknown Tool',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  tool['category'] ?? 'General',
                                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "₹${tool['pricePerDay']}/day",
                                  style: const TextStyle(color: Color(0xFFFF8C00), fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Delete Button
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () => _deleteTool(context, toolId),
                        ),
                      ],
                    ),

                    // Bottom Control Bar
                    Container(
                      color: isAvailable ? Colors.green.withOpacity(0.05) : Colors.grey[100],
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isAvailable ? Colors.green : Colors.grey,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isAvailable ? "Active in Community" : "Paused / Unavailable",
                                style: TextStyle(
                                  color: isAvailable ? Colors.green[700] : Colors.grey[600],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          // The Toggle Switch!
                          Switch(
                            value: isAvailable,
                            activeColor: Colors.green,
                            onChanged: (val) => _toggleAvailability(context, toolId, isAvailable),
                          ),
                        ],
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