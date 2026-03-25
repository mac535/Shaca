import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'join_node_screen.dart';
import 'tool_detail_screen.dart';
import 'login_screen.dart';
import 'owner_dashboard_screen.dart';

class KHomeScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  const KHomeScreen({super.key, required this.onToggleTheme});

  @override
  State<KHomeScreen> createState() => _KHomeScreenState();
}

class _KHomeScreenState extends State<KHomeScreen> {
  String _selectedCategory = 'All';
  final List<String> _categories = ['All', 'Drills', 'Ladders', 'Gardening', 'Electrical'];

  Future<Position>? _locationFuture;
  bool _isSettingHome = false;

  @override
  void initState() {
    super.initState();
    // 🚀 Safe location fetch prevents black screen crashes on boot
    _locationFuture = _getSafeLocation();
    _refreshLocation();
  }

  // 🛡️ THE SHIELD: Gracefully handles missing permissions
  Future<Position> _getSafeLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return Future.error('Location services are disabled.');

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error('Location permissions are permanently denied.');
    }

    return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }

  Future<void> _refreshLocation() async {
    try {
      Position currentPos = await _getSafeLocation();
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Location updated! Showing tools near you."), backgroundColor: Colors.blue)
          );
        }
        return;
      }

      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

      if (userDoc.exists && userDoc.data() != null) {
        var data = userDoc.data() as Map<String, dynamic>;

        if (data.containsKey('homeLat') && data.containsKey('homeLng')) {
          double dbLat = data['homeLat'];
          double dbLng = data['homeLng'];

          double distanceInMeters = Geolocator.distanceBetween(
              currentPos.latitude, currentPos.longitude, dbLat, dbLng
          );

          if (!mounted) return;

          if (distanceInMeters <= 500) {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Home verified! You are within 500m."), backgroundColor: Colors.green)
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("You are away from home. Remote booking enabled!"), backgroundColor: Colors.orange)
            );
          }
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Please set your Home Location first!"), backgroundColor: Colors.orange)
          );
        }
      }
    } catch (e) {
      debugPrint("Location verification skipped: $e");
    }
  }

  Future<void> _setHomeToCurrentLocation() async {
    setState(() => _isSettingHome = true);
    try {
      Position position = await _getSafeLocation();
      final user = FirebaseAuth.instance.currentUser!;

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'homeLat': position.latitude,
        'homeLng': position.longitude,
      }, SetOptions(merge: true));

      _showToast("Home base locked in successfully!");
    } catch (e) {
      _showToast("Failed to lock location. Please enable GPS and allow permissions.");
    } finally {
      if (mounted) setState(() => _isSettingHome = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, authSnapshot) {
          final user = authSnapshot.data;

          return Scaffold(
            appBar: AppBar(
              titleSpacing: 16,
              title: user == null
                  ? const Text('ShaCa Community', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))
                  : StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
                builder: (context, snapshot) {
                  String displayTitle = "ShaCa Community";

                  if (snapshot.hasData && snapshot.data!.exists) {
                    final userData = snapshot.data!.data() as Map<String, dynamic>;
                    final communityName = userData['communityName'] ?? userData['societyName'] ?? '';
                    final societyCode = userData['societyCode'] ?? '';

                    if (communityName.toString().isNotEmpty) {
                      displayTitle = communityName;
                    } else if (societyCode.toString().isNotEmpty) {
                      displayTitle = "Society: $societyCode";
                    }
                  }

                  return Row(
                    mainAxisSize: MainAxisSize.min, // 🛡️ Fixes RenderFlex overflow
                    children: [
                      const Icon(Icons.location_on, color: Color(0xFFFF8C00), size: 20),
                      const SizedBox(width: 8),
                      Flexible( // 🛡️ Fixes RenderFlex overflow
                        child: Text(
                          displayTitle,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  );
                },
              ),
              actions: [
                if (user != null)
                  StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('rentals')
                          .where('lenderId', isEqualTo: user.uid)
                          .where('status', isEqualTo: 'pending_verification')
                          .snapshots(),
                      builder: (context, snapshot) {
                        bool hasPendingRequests = snapshot.hasData && snapshot.data!.docs.isNotEmpty;

                        return IconButton(
                            icon: Badge(
                              isLabelVisible: hasPendingRequests,
                              backgroundColor: Colors.red,
                              smallSize: 10,
                              child: const Icon(Icons.inbox),
                            ),
                            tooltip: 'Incoming Requests',
                            onPressed: () {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const OwnerDashboardScreen())
                              );
                            }
                        );
                      }
                  ),
                if (user != null)
                  IconButton(icon: const Icon(Icons.my_location), tooltip: 'Refresh GPS', onPressed: _refreshLocation),
                IconButton(icon: const Icon(Icons.brightness_6), onPressed: widget.onToggleTheme),
              ],
            ),
            body: Column(
              children: [
                SizedBox(
                  height: 60,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final category = _categories[index];
                      final isSelected = category == _selectedCategory;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: Text(category),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) setState(() => _selectedCategory = category);
                          },
                          selectedColor: const Color(0xFFFF8C00),
                          labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87),
                        ),
                      );
                    },
                  ),
                ),
                Expanded(child: _buildMainContent(user)),
              ],
            ),
          );
        }
    );
  }

  Widget _buildMainContent(User? user) {
    if (user == null) {
      return Column(
        children: [
          _buildInfoBanner("Browsing as Guest. Log in to rent tools nearby.", Icons.lock_open, "Log In", () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
          }), // 🚀 THIS IS THE COMMA THAT FIXED IT!
          Expanded(child: _fetchAndBuildToolGrid(null)),
        ],
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFFF8C00)));
        }

        final userData = userSnapshot.data?.data() as Map<String, dynamic>?;
        final homeLat = userData?['homeLat'];
        final homeLng = userData?['homeLng'];
        final societyCode = userData?['societyCode'] ?? '';

        if (homeLat == null || homeLng == null) {
          return Column(
            children: [
              _isSettingHome
                  ? const LinearProgressIndicator(color: Color(0xFFFF8C00))
                  : _buildInfoBanner("You must be at home to lock your location.", Icons.add_location_alt, "Lock Location", _setHomeToCurrentLocation),
              Expanded(child: _fetchAndBuildToolGrid(null)),
            ],
          );
        }

        if (societyCode.isEmpty) {
          return Column(
            children: [
              _buildInfoBanner(
                  "Join the community to unlock renting and lending nearby.",
                  Icons.people_outline,
                  "Join Community",
                      () => Navigator.push(context, MaterialPageRoute(builder: (_) => const JoinNodeScreen()))
              ),
              Expanded(child: _fetchAndBuildToolGrid(null)),
            ],
          );
        }

        return FutureBuilder<Position>(
          future: _locationFuture,
          builder: (context, locSnapshot) {
            if (locSnapshot.connectionState == ConnectionState.waiting) {
              return Column(
                children: [
                  const LinearProgressIndicator(color: Color(0xFFFF8C00)),
                  Expanded(child: _fetchAndBuildToolGrid(societyCode)),
                ],
              );
            }

            if (locSnapshot.hasError) {
              return Column(
                children: [
                  _buildInfoBanner("GPS Permission Needed.", Icons.gps_off, "Allow", _refreshLocation),
                  Expanded(child: _fetchAndBuildToolGrid(societyCode)),
                ],
              );
            }

            final currentPos = locSnapshot.data!;
            double distanceInMeters = Geolocator.distanceBetween(
                currentPos.latitude, currentPos.longitude, homeLat, homeLng
            );

            if (distanceInMeters > 500) {
              return Column(
                children: [
                  _buildInfoBanner("You are away from home. Handovers must happen at the society.", Icons.directions_car, "Refresh GPS", _refreshLocation),
                  Expanded(child: _fetchAndBuildToolGrid(societyCode)),
                ],
              );
            }

            return _fetchAndBuildToolGrid(societyCode);
          },
        );
      },
    );
  }

  Widget _fetchAndBuildToolGrid(String? societyFilter) {
    Query query = FirebaseFirestore.instance.collection('tools');

    if (societyFilter != null && societyFilter.isNotEmpty) {
      query = query.where('societyCode', isEqualTo: societyFilter);
    }

    if (_selectedCategory != 'All') {
      query = query.where('category', isEqualTo: _selectedCategory);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, toolSnapshot) {
        if (toolSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!toolSnapshot.hasData || toolSnapshot.data!.docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 60, color: Colors.grey),
                SizedBox(height: 16),
                Text("No tools found", style: TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.bold)),
              ],
            ),
          );
        }

        final tools = toolSnapshot.data!.docs;

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, childAspectRatio: 0.75, crossAxisSpacing: 16, mainAxisSpacing: 16,
          ),
          itemCount: tools.length,
          itemBuilder: (context, index) {
            final toolDoc = tools[index];
            final toolData = toolDoc.data() as Map<String, dynamic>;
            return _buildToolCard(toolDoc.id, toolData);
          },
        );
      },
    );
  }

  Widget _buildToolCard(String toolId, Map<String, dynamic> tool) {
    final currentUser = FirebaseAuth.instance.currentUser;
    bool isOwner = currentUser != null && tool['ownerId'] == currentUser.uid;
    bool isAvailable = tool['isAvailable'] ?? true;

    return GestureDetector(
      onTap: () {
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
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SizedBox(
                    width: double.infinity,
                    child: Image.network(
                      tool['imageUrl'] ?? '',
                      fit: BoxFit.cover,
                      color: isAvailable ? null : Colors.white.withOpacity(0.4),
                      colorBlendMode: isAvailable ? null : BlendMode.lighten,
                      errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey[200],
                          child: const Icon(Icons.image_not_supported, color: Colors.grey)),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tool['name'] ?? 'Unknown',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isAvailable ? Colors.black : Colors.grey,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text(tool['category'] ?? '',
                          style: TextStyle(
                              color: isAvailable ? const Color(0xFFFF8C00) : Colors.grey,
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('₹${tool['pricePerDay']}/day',
                          style: TextStyle(fontSize: 14, color: isAvailable ? Colors.black87 : Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),

            if (!isAvailable)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    "UNAVAILABLE",
                    style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

            if (isOwner && isAvailable)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    "OWNED",
                    style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

            if (isAvailable)
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('rentals')
                    .where('toolId', isEqualTo: toolId)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) return const SizedBox.shrink();
                  if (snapshot.connectionState == ConnectionState.waiting) return const SizedBox.shrink();

                  bool isRented = false;
                  bool isBorrower = false;

                  if (snapshot.hasData) {
                    for (var doc in snapshot.data!.docs) {
                      String status = doc['status'] ?? '';
                      if (status == 'Active' || status == 'paid_pending_pickup') {
                        isRented = true;
                        if (currentUser != null && doc['borrowerId'] == currentUser.uid) {
                          isBorrower = true;
                        }
                        break;
                      }
                    }
                  }

                  if (isRented) {
                    return Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isBorrower ? Colors.blue.withOpacity(0.9) : Colors.red.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isBorrower ? "BORROWED" : "RENTED",
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    );
                  }

                  return const SizedBox.shrink();
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBanner(String text, IconData icon, String buttonText, VoidCallback onPressed) {
    return Container(
      color: const Color(0xFFFF8C00).withOpacity(0.1),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFFF8C00)),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13, color: Color(0xFF2C3E50), fontWeight: FontWeight.w600))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF8C00),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: onPressed,
            child: Text(buttonText, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}