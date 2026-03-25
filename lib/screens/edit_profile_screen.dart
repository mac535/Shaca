import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController(); // For the OTP Dialog

  bool _isLoading = false;
  bool _isFetching = true;
  String _originalPhone = ""; // To check if they actually changed it

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        DocumentSnapshot doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          _nameController.text = data['name'] ?? '';
          _originalPhone = data['phone'] ?? '';
          _phoneController.text = _originalPhone;
        }
      } catch (e) {
        debugPrint("Error loading user data: $e");
      }
    }
    if (mounted) setState(() => _isFetching = false);
  }

  // 🚀 THE MASTER SAVE FUNCTION
  Future<void> _processProfileUpdate() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus(); // Hide keyboard

    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    String newName = _nameController.text.trim();
    String newPhone = _phoneController.text.trim();

    // 1. Did the phone number change?
    if (newPhone == _originalPhone) {
      // Just update the name in Firestore!
      await _updateFirestoreOnly(user.uid, newName, newPhone);
      return;
    }

    // 2. Format the phone number (Assuming India +91 for this MVP, adjust if needed)
    if (!newPhone.startsWith('+')) {
      newPhone = '+91$newPhone';
    }

    // 3. 🛑 SECURITY CHECK: Does this number exist in another account?
    try {
      final existingUsers = await FirebaseFirestore.instance
          .collection('users')
          .where('phone', isEqualTo: newPhone)
          .get();

      if (existingUsers.docs.isNotEmpty) {
        _showError("This phone number is already registered to another user.");
        setState(() => _isLoading = false);
        return;
      }

      // 4. Send OTP!
      _verifyNewPhoneNumber(user, newName, newPhone);

    } catch (e) {
      _showError("Error checking number: $e");
      setState(() => _isLoading = false);
    }
  }

  // 📱 FIREBASE PHONE AUTHENTICATION FLOW
  void _verifyNewPhoneNumber(User user, String newName, String newPhone) {
    FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: newPhone,
      verificationCompleted: (PhoneAuthCredential credential) async {
        // Auto-resolves on some Android devices
        await _linkCredentialAndUpdate(user, credential, newName, newPhone);
      },
      verificationFailed: (FirebaseAuthException e) {
        _showError(e.message ?? "Verification failed.");
        setState(() => _isLoading = false);
      },
      codeSent: (String verificationId, int? resendToken) {
        setState(() => _isLoading = false);
        _showOtpDialog(user, verificationId, newName, newPhone);
      },
      codeAutoRetrievalTimeout: (String verificationId) {},
    );
  }

  // 💬 THE OTP ENTRY DIALOG
  void _showOtpDialog(User user, String verificationId, String newName, String newPhone) {
    _otpController.clear();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Verify New Number"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("We sent an SMS code to $newPhone"),
            const SizedBox(height: 16),
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(
                hintText: "Enter 6-digit OTP",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF8C00)),
            onPressed: () async {
              String smsCode = _otpController.text.trim();
              if (smsCode.length == 6) {
                Navigator.pop(context); // Close dialog
                setState(() => _isLoading = true);

                // Create credential from the code they typed
                PhoneAuthCredential credential = PhoneAuthProvider.credential(
                  verificationId: verificationId,
                  smsCode: smsCode,
                );

                await _linkCredentialAndUpdate(user, credential, newName, newPhone);
              } else {
                _showError("Please enter a valid 6-digit code.");
              }
            },
            child: const Text("Verify", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // 🔗 LINK NEW NUMBER & UPDATE DATABASE
  Future<void> _linkCredentialAndUpdate(User user, PhoneAuthCredential credential, String newName, String newPhone) async {
    try {
      // 1. Update Firebase Auth (Requires recent login, you may need to catch 'requires-recent-login' in prod)
      await user.updatePhoneNumber(credential);

      // 2. Update Firestore database
      await _updateFirestoreOnly(user.uid, newName, newPhone);

    } catch (e) {
      _showError("Failed to update number. You may need to log out and log back in. Error: $e");
      setState(() => _isLoading = false);
    }
  }

  // 💾 FIRESTORE FINAL UPDATE
  Future<void> _updateFirestoreOnly(String uid, String newName, String newPhone) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'name': newName,
        'phone': newPhone,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile updated successfully!"), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      _showError("Database error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.white,
      ),
      backgroundColor: Colors.white,
      body: _isFetching
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF8C00)))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Personal Details",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
              ),
              const SizedBox(height: 8),
              const Text(
                "Update your name and contact information. Changing your number requires SMS verification.",
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 32),

              const Text("Full Name", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: "Enter your full name",
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFFF8C00), width: 2),
                  ),
                ),
                validator: (value) => value == null || value.trim().isEmpty ? "Name cannot be empty" : null,
              ),

              const SizedBox(height: 24),

              const Text("Phone Number", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  hintText: "Enter your phone number",
                  prefixIcon: const Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFFF8C00), width: 2),
                  ),
                ),
                validator: (value) => value == null || value.trim().isEmpty ? "Phone number cannot be empty" : null,
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
                  onPressed: _isLoading ? null : _processProfileUpdate, // 🚀 Trigger the master function
                  child: _isLoading
                      ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Save Changes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}