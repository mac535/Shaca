import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'rental_history_screen.dart';
import 'join_node_screen.dart'; // 🚀 ADDED: Import the join node screen!
import 'package:flutter/services.dart'; // 🚀 ADD THIS FOR CLIPBOARD!
import 'my_listed_tools_screen.dart'; // 🚀 IMPORT THE NEW SCREEN
import 'saved_items_screen.dart'; // 🚀 IMPORT THE SAVED ITEMS SCREEN
import 'help_support_screen.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _showDevelopingToast(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("This feature is coming soon!"), behavior: SnackBarBehavior.floating),
    );
  }

  // ----------------------------------------------------------------
  // 🗺️ THE LOCATION SWITCH LOGIC & SAFETY CHECK
  // ----------------------------------------------------------------
  Future<void> _leaveCurrentSociety(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // ⏳ Show a loading indicator while we check the database
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: Color(0xFFFF8C00))),
    );

    try {
      // 🛑 THE SAFETY CHECK: Look for ANY active or pending rentals
      var borrowedCheck = await FirebaseFirestore.instance
          .collection('rentals')
          .where('borrowerId', isEqualTo: user.uid)
          .where('status', whereIn: ['Active', 'paid_pending_pickup'])
          .get();

      var lentCheck = await FirebaseFirestore.instance
          .collection('rentals')
          .where('lenderId', isEqualTo: user.uid)
          .where('status', whereIn: ['Active', 'paid_pending_pickup'])
          .get();

      // If they have open transactions, BLOCK THE MOVE!
      if (borrowedCheck.docs.isNotEmpty || lentCheck.docs.isNotEmpty) {
        if (context.mounted) Navigator.pop(context); // Close loading indicator

        if (context.mounted) {
          showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text("Action Required", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                content: const Text(
                    "You cannot change your location right now because you have active rentals in progress.\n\n"
                        "Please return any tools you are borrowing, and collect any tools you lent out before moving to a new society."
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text("Got it")
                  ),
                ],
              )
          );
        }
        return; // 🛑 Stop the function here!
      }

      // ✅ IF SAFE TO MOVE: Close loading indicator
      if (context.mounted) Navigator.pop(context);

      // Show confirmation dialog
      bool? confirm = await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Move to a New Location?"),
            content: const Text(
                "This will remove you from your current society. "
                    "All your tools will be temporarily hidden from the community until you join a new one."
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text("Cancel")
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text("Yes, Move", style: TextStyle(color: Colors.white)),
              ),
            ],
          )
      );

      if (confirm != true) return;

      // ⏳ Show loader for the actual database write
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(child: CircularProgressIndicator(color: Color(0xFFFF8C00))),
        );
      }

      // 🚀 THE BATCH WRITE: Safely wipe location and hide tools
      WriteBatch batch = FirebaseFirestore.instance.batch();

      DocumentReference userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      batch.update(userRef, {
        'societyCode': '',
        'homeLat': FieldValue.delete(),
        'homeLng': FieldValue.delete(),
      });

      QuerySnapshot userTools = await FirebaseFirestore.instance
          .collection('tools')
          .where('ownerId', isEqualTo: user.uid)
          .get();

      for (var doc in userTools.docs) {
        batch.update(doc.reference, {'societyCode': ''});
      }

      await batch.commit();

      if (context.mounted) Navigator.pop(context); // Close loader

      // 🗺️ SEND THEM TO JOIN A NEW NODE
      if (context.mounted) {
        Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const JoinNodeScreen())
        );
      }

    } catch (e) {
      if (context.mounted) Navigator.pop(context); // Close loader
      debugPrint("Error moving location: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
      ),
      body: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFFF8C00)));
          }

          final user = snapshot.data;

          if (user == null) {
            return _buildGuestUI(context);
          }

          return _buildUserDashboard(context, user);
        },
      ),
    );
  }

  // ----------------------------------------------------------------
  // 👤 GUEST UI (Not Logged In)
  // ----------------------------------------------------------------
  Widget _buildGuestUI(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFFF8C00).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_outline, size: 80, color: Color(0xFFFF8C00)),
            ),
            const SizedBox(height: 32),
            const Text(
              'Join the ShaCa Community',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Log in to rent tools, list your own machinery, and connect with your neighborhood.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF8C00),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                },
                child: const Text('Log In / Register', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------------------
  // 📱 AUTHENTICATED UI (Logged In Dashboard)
  // ----------------------------------------------------------------
  // ----------------------------------------------------------------
  // 📱 AUTHENTICATED UI (Logged In Dashboard)
  // ----------------------------------------------------------------
  Widget _buildUserDashboard(BuildContext context, User user) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        String displayName = 'ShaCa Member';
        String contactInfo = user.email ?? user.phoneNumber ?? 'No contact info provided';
        String societyCode = ''; // 🚀 ADDED: To hold the society code

        if (snapshot.hasData && snapshot.data!.exists) {
          final userData = snapshot.data!.data() as Map<String, dynamic>;
          displayName = userData['name'] ?? displayName;
          contactInfo = userData['email'] ?? userData['phone'] ?? contactInfo;
          societyCode = userData['societyCode'] ?? ''; // 🚀 Extract the code
        }

        return ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // --- HEADER SECTION ---
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[200]!),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: const Color(0xFFFF8C00),
                    child: Text(
                      displayName.isNotEmpty ? displayName[0].toUpperCase() : 'S',
                      style: const TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          contactInfo,
                          style: const TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 🚀 NEW: THE SHAREABLE SOCIETY CODE CARD
            if (societyCode.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 16),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF8C00).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFF8C00).withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("My Society Code", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(
                          societyCode,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFFFF8C00), letterSpacing: 2),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, color: Color(0xFFFF8C00)),
                      tooltip: "Copy Code",
                      onPressed: () {
                        // Copies the code to the phone's clipboard!
                        Clipboard.setData(ClipboardData(text: societyCode));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Society Code copied! Share it with your neighbors. 🏡"),
                            backgroundColor: Colors.green,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 32),

            // --- MENU OPTIONS ---
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 12),
              child: Text(
                'My Activity',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
              ),
            ),

            _buildMenuTile(Icons.handyman_outlined, 'My Listed Tools', 'Manage items you are renting out', () {
              // 🚀 NEW: Route to the actual screen instead of showing the Toast!
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MyListedToolsScreen()),
              );
            }),
            _buildMenuTile(Icons.history_outlined, 'Rental History', 'View tools you have rented', () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const RentalHistoryScreen()),
              );
            }),
            _buildMenuTile(Icons.favorite_border, 'Saved Items', 'Tools you are watching', () {
              // 🚀 NEW: Route to the actual screen!
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SavedItemsScreen()),
              );
            }),
            const SizedBox(height: 24),

            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 12),
              child: Text(
                'Account Settings',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
              ),
            ),

            _buildMenuTile(Icons.person_outline, 'Edit Profile', 'Update your name and phone', () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen()));
            }),

            // 🚀 NEW LOCATION SWITCH BUTTON
            _buildMenuTile(Icons.location_on_outlined, 'Change Location / Society', 'Move to a new neighborhood', () {
              _leaveCurrentSociety(context);
            }),

            // Make sure there is NO "const" keyword at the start of this line!
            _buildMenuTile(Icons.support_agent_outlined, 'Help & Support', 'Get help with a rental', () {
              Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => HelpSupportScreen()) // Removed the 'const' here!
              );
            }),

            const SizedBox(height: 40),

            // --- LOGOUT BUTTON ---
            // ... (Rest of your logout button code remains the same)
            SizedBox(
              width: double.infinity,
              height: 54,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.logout),
                label: const Text('Log Out', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                onPressed: () async {
                  bool confirm = await showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Log Out'),
                      content: const Text('Are you sure you want to log out?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Log Out', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ) ?? false;

                  if (confirm) {
                    await FirebaseAuth.instance.signOut();
                  }
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }

  // 🛠️ Helper widget
  Widget _buildMenuTile(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F7FA),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFF2C3E50)),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2C3E50))),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 13, color: Colors.grey)),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }
}