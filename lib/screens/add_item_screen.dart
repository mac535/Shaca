import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'login_screen.dart';
import 'join_node_screen.dart';

class AddItemScreen extends StatefulWidget {
  const AddItemScreen({super.key});

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();

  // 🚀 NEW CONTROLLERS
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _depositController = TextEditingController();

  String _selectedCategory = 'Drills';
  final List<String> _categories = ['Drills', 'Ladders', 'Gardening', 'Electrical'];

  // 🚀 NEW: Pricing Model
  String _selectedPricing = 'Per Day';
  final List<String> _pricingOptions = ['Per Day', 'Per Hour'];

  bool _isUploading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _depositController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  void _submitTool() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      _showLoginDialog();
      return;
    }

    final toolName = _nameController.text.trim();
    final toolPrice = _priceController.text.trim();
    final toolDesc = _descriptionController.text.trim();
    final toolDeposit = _depositController.text.trim();

    if (toolName.isEmpty || toolPrice.isEmpty || toolDesc.isEmpty || toolDeposit.isEmpty) {
      _showError('Please fill in all the details!');
      return;
    }

    if (_selectedImage == null) {
      _showError('Please pick an image for your tool!');
      return;
    }

    setState(() => _isUploading = true);

    try {
      // 🔒 Check Society Verification
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();

      bool isVerified = false;
      String societyCode = '';
      if (userDoc.exists && userDoc.data() != null) {
        final data = userDoc.data() as Map<String, dynamic>;
        isVerified = data['isVerified'] ?? false;
        societyCode = data['societyCode'] ?? '';
      }

      if (!isVerified || societyCode.isEmpty) {
        _showVerificationDialog();
        setState(() => _isUploading = false);
        return;
      }

      // ☁️ Upload Image
      String fileName = 'tools/${DateTime.now().millisecondsSinceEpoch}_${currentUser.uid}.jpg';
      Reference storageRef = FirebaseStorage.instance.ref().child(fileName);

      UploadTask uploadTask = storageRef.putFile(_selectedImage!);
      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();

      // 📝 Save Tool Data to Firestore
      await FirebaseFirestore.instance.collection('tools').add({
        'name': toolName,
        'description': toolDesc,                               // 🚀 Saved!
        'pricePerDay': double.parse(toolPrice),                // (Keeping 'pricePerDay' key so existing code doesn't break)
        'pricingType': _selectedPricing,                       // 🚀 Saved! (Per Day / Per Hour)
        'securityDeposit': double.parse(toolDeposit),          // 🚀 Saved!
        'category': _selectedCategory,
        'imageUrl': downloadUrl,
        'ownerId': currentUser.uid,
        'societyCode': societyCode,
        'isAvailable': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // ✅ Success!
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tool added successfully!'), backgroundColor: Colors.green));
        Navigator.pop(context);
      }

    } catch (e) {
      _showError('Failed to upload tool: $e');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));

  void _showLoginDialog() { /* ... unchanged ... */
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Login Required'),
        content: const Text('You must be logged in to add a new tool.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
            },
            child: const Text('Go to Login'),
          ),
        ],
      ),
    );
  }

  void _showVerificationDialog() { /* ... unchanged ... */
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Verification Required'),
        content: const Text('You must join and verify your local society before you can list tools for rent.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF8C00)),
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const JoinNodeScreen()));
            },
            child: const Text('Join a Society', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Tool')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_selectedImage != null) ...[
            ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(_selectedImage!, height: 180, width: double.infinity, fit: BoxFit.cover)),
            const SizedBox(height: 8),
            TextButton.icon(onPressed: _pickImage, icon: const Icon(Icons.refresh), label: const Text('Change Image')),
          ] else ...[
            Container(
              height: 150, width: double.infinity,
              decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[400]!)),
              child: Center(child: ElevatedButton.icon(onPressed: _pickImage, icon: const Icon(Icons.image), label: const Text('Pick Image'))),
            ),
          ],
          const SizedBox(height: 24),

          TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Tool Name', border: OutlineInputBorder())
          ),
          const SizedBox(height: 16),

          // 🚀 NEW: Description Field
          TextField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description (Condition, what is included, rules)',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              )
          ),
          const SizedBox(height: 16),

          // 🚀 NEW: Split Row for Price and Pricing Type
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                    controller: _priceController,
                    decoration: const InputDecoration(labelText: 'Price (₹)', border: OutlineInputBorder()),
                    keyboardType: TextInputType.number
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  value: _selectedPricing,
                  decoration: const InputDecoration(labelText: 'Rate', border: OutlineInputBorder()),
                  items: _pricingOptions.map((String option) {
                    return DropdownMenuItem(value: option, child: Text(option));
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) setState(() => _selectedPricing = newValue);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 🚀 NEW: Security Deposit
          TextField(
              controller: _depositController,
              decoration: const InputDecoration(
                  labelText: 'Refundable Security Deposit (₹)',
                  border: OutlineInputBorder(),
                  helperText: 'You can deduct from this if the tool is damaged.'
              ),
              keyboardType: TextInputType.number
          ),
          const SizedBox(height: 16),

          DropdownButtonFormField<String>(
            value: _selectedCategory,
            decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
            items: _categories.map((String category) {
              return DropdownMenuItem(value: category, child: Text(category));
            }).toList(),
            onChanged: (String? newValue) {
              if (newValue != null) setState(() => _selectedCategory = newValue);
            },
          ),

          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF8C00)),
              onPressed: _isUploading ? null : _submitTool,
              child: _isUploading
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Add Tool', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}