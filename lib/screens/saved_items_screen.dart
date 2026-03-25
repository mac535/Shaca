import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'tool_detail_screen.dart'; // Make sure this matches your Tool Detail screen!

class SavedItemsScreen extends StatelessWidget {
  const SavedItemsScreen({super.key});

  Future<void> _removeSavedItem(BuildContext context, String toolId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // 🗑️ Remove the toolId from the user's savedTools array
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'savedTools': FieldValue.arrayRemove([toolId])
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Removed from saved items"), duration: Duration(seconds: 2)),
        );
      }
    } catch (e) {
      debugPrint("Error removing saved item: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Saved Items')),
        body: const Center(child: Text("Please log in to see your saved items.")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Items', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.white,
      ),
      backgroundColor: Colors.grey[100],
      // 🎧 1. Listen to the User's Profile to get their saved tool IDs
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFFF8C00)));
          }

          if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
            return const Center(child: Text("Profile not found."));
          }

          final userData = userSnapshot.data!.data() as Map<String, dynamic>;
          final List<dynamic> savedTools = userData['savedTools'] ?? [];

          if (savedTools.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.favorite_border, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text(
                    "You haven't saved any tools yet!",
                    style: TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Tap the heart icon on a tool to save it for later.",
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: savedTools.length,
            itemBuilder: (context, index) {
              String toolId = savedTools[index];

              // 🛠️ 2. Fetch the actual tool data for each saved ID
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('tools').doc(toolId).get(),
                builder: (context, toolSnapshot) {
                  if (toolSnapshot.connectionState == ConnectionState.waiting) {
                    return const Card(
                      margin: EdgeInsets.only(bottom: 16),
                      child: SizedBox(height: 100, child: Center(child: CircularProgressIndicator())),
                    );
                  }

                  // If the owner deleted the tool, it won't exist anymore!
                  if (!toolSnapshot.hasData || !toolSnapshot.data!.exists) {
                    return Card(
                      color: Colors.grey[200],
                      margin: const EdgeInsets.only(bottom: 16),
                      child: ListTile(
                        leading: const Icon(Icons.error_outline, color: Colors.red),
                        title: const Text("This tool is no longer available", style: TextStyle(color: Colors.grey)),
                        trailing: IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => _removeSavedItem(context, toolId),
                        ),
                      ),
                    );
                  }

                  final tool = toolSnapshot.data!.data() as Map<String, dynamic>;
                  String imageUrl = tool['imageUrl'] ?? '';

                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () {
                        // Go to tool details when tapped!
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ToolDetailScreen(
                              toolId: toolId,
                              toolData: tool,
                            ),
                          ),
                        );
                      },
                      child: Row(
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            color: Colors.grey[200],
                            child: imageUrl.isNotEmpty
                                ? Image.network(imageUrl, fit: BoxFit.cover)
                                : const Icon(Icons.handyman, size: 40, color: Colors.grey),
                          ),
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
                                  Text("₹${tool['pricePerDay']}/day", style: const TextStyle(color: Color(0xFFFF8C00), fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.favorite, color: Colors.redAccent),
                            onPressed: () => _removeSavedItem(context, toolId),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}