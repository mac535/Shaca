import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';
import 'home_screen.dart';
import 'otp_screen.dart';
import 'root_screen.dart';
import 'admin_login_screen.dart'; // 🚀 IMPORT YOUR NEW ADMIN LOGIN SCREEN!

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AuthService _authService = AuthService();

  // Controllers
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  // ----------------------------------------------------------------
  // 📧 EMAIL LOGIN LOGIC
  // ----------------------------------------------------------------
  void _loginWithEmail() async {
    setState(() => _isLoading = true);
    try {
      await _authService.loginWithEmail(
          _emailController.text.trim(),
          _passwordController.text.trim()
      );

      if (!mounted) return;

      RootScreen.tabNotifier.value = 0;
      Navigator.popUntil(context, ModalRoute.withName('/'));

    } on FirebaseAuthException catch (e) {
      debugPrint("🔥 EMAIL LOGIN ERROR CODE: ${e.code}");
      debugPrint("🔥 EMAIL LOGIN ERROR MSG: ${e.message}");

      if (e.code == 'user-not-found') {
        _showRegisterDialog("We couldn't find an account with this email. Would you like to create one?");
      } else if (e.code == 'wrong-password') {
        _showCustomSnackBar(message: "Incorrect password. Please try again.", isError: true);
      } else if (e.code == 'invalid-email') {
        _showCustomSnackBar(message: "Please enter a valid email address.", isError: true);
      } else if (e.code == 'invalid-credential') {
        _showCustomSnackBar(message: "Incorrect email or password.", isError: true);
      } else if (e.code == 'network-request-failed') {
        _showCustomSnackBar(message: "No internet. Please check your Wi-Fi/Data.", isError: true);
      } else {
        _showCustomSnackBar(message: e.message ?? "An unknown error occurred.", isError: true);
      }
    } catch (e) {
      debugPrint("🔥 GENERAL EMAIL ERROR: $e");
      _showCustomSnackBar(message: "An unexpected error occurred.", isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ----------------------------------------------------------------
  // 📱 PHONE LOGIN LOGIC
  // ----------------------------------------------------------------
  void _loginWithPhone() async {
    String phone = _phoneController.text.trim();
    if (phone.length != 10) {
      _showCustomSnackBar(message: "Please enter a valid 10-digit number", isError: true);
      return;
    }

    setState(() => _isLoading = true);
    String fullPhoneNumber = "+91$phone";

    try {
      var userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('phone', isEqualTo: fullPhoneNumber)
          .get();

      if (userQuery.docs.isEmpty) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        _showRegisterDialog("We couldn't find a ShaCa account for this number. Would you like to join your community?");
        return;
      }

      _authService.sendOtp(
        phoneNumber: fullPhoneNumber,
        codeSent: (verificationId, resendToken) {
          if (!mounted) return;
          setState(() => _isLoading = false);

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OTPScreen(
                verificationId: verificationId,
                phoneNumber: fullPhoneNumber,
                isLoginFlow: true,
              ),
            ),
          );
        },
        verificationFailed: (FirebaseAuthException error) {
          if (!mounted) return;
          setState(() => _isLoading = false);

          debugPrint("🔥 OTP VERIFICATION FAILED: ${error.code} - ${error.message}");

          String errorMsg = "Verification failed. Please try again.";
          if (error.message != null && error.message!.contains('BILLING')) {
            errorMsg = "Server Config: Enable Blaze Plan in Firebase.";
          } else if (error.code == 'network-request-failed') {
            errorMsg = "No internet connection. Please check your network.";
          } else if (error.code == 'too-many-requests') {
            errorMsg = "Too many attempts. Please try again later.";
          }
          _showCustomSnackBar(message: errorMsg, isError: true);
        },
      );
    } on FirebaseException catch (e) {
      debugPrint("🔥 FIRESTORE QUERY ERROR: ${e.code} - ${e.message}");
      if (!mounted) return;
      setState(() => _isLoading = false);

      if (e.code == 'unavailable') {
        _showCustomSnackBar(message: "Database offline. Check your internet.", isError: true);
      } else {
        _showCustomSnackBar(message: "Database error: ${e.message}", isError: true);
      }
    } catch (e) {
      debugPrint("🔥 UNKNOWN PHONE LOGIN ERROR: $e");
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showCustomSnackBar(message: "Something went wrong. Please try again.", isError: true);
    }
  }

  // ----------------------------------------------------------------
  // 🛠️ HELPER WIDGETS
  // ----------------------------------------------------------------
  void _showCustomSnackBar({required String message, required bool isError}) {
    Color accentColor = isError ? Colors.redAccent : const Color(0xFFFF8C00);
    IconData icon = isError ? Icons.error_outline : Icons.info_outline;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              width: 4, height: 40,
              decoration: BoxDecoration(color: accentColor, borderRadius: BorderRadius.circular(4)),
            ),
            const SizedBox(width: 12),
            Icon(icon, color: Colors.white70),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message, style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.white)),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF2C3E50),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(20),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showRegisterDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("New User?"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF8C00)),
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const RegisterScreen())
              );
            },
            child: const Text("Create Account", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 40),
            const Icon(Icons.handyman_rounded, size: 60, color: Color(0xFFFF8C00)),
            Text("ShaCa Login", style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 30),

            TabBar(
              controller: _tabController,
              labelColor: const Color(0xFFFF8C00),
              unselectedLabelColor: Colors.grey,
              indicatorColor: const Color(0xFFFF8C00),
              tabs: const [
                Tab(text: "Email Login"),
                Tab(text: "Phone Login"),
              ],
            ),
            const SizedBox(height: 20),

            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // --- TAB 1: EMAIL ---
                  SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      children: [
                        TextField(
                          controller: _emailController,
                          decoration: const InputDecoration(labelText: "Email", prefixIcon: Icon(Icons.email_outlined)),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(labelText: "Password", prefixIcon: Icon(Icons.lock_outline)),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ForgotPasswordScreen())),
                            child: const Text("Forgot Password?"),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _loginWithEmail,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF8C00),
                              foregroundColor: Colors.white,
                            ),
                            child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("Login with Email"),
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextButton(
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const RegisterScreen())),
                          child: const Text("Don't have an account? Sign Up", style: TextStyle(color: Color(0xFF2C3E50))),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),

                  // --- TAB 2: PHONE ---
                  SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        const Text("We will send an OTP to verify your number."),
                        const SizedBox(height: 20),
                        TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: "Phone Number",
                            prefixText: "+91 ",
                            prefixIcon: Icon(Icons.phone),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _loginWithPhone,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF8C00),
                              foregroundColor: Colors.white,
                            ),
                            child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("Get OTP"),
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // =========================================================
            // 🛡️ THE SECRET ADMIN ACCESS BUTTON
            // =========================================================
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AdminLoginScreen()),
                );
              },
              child: const Text("Admin Access", style: TextStyle(color: Colors.grey, fontSize: 12)),
            ),
            const SizedBox(height: 10), // A little padding at the very bottom
          ],
        ),
      ),
    );
  }
}