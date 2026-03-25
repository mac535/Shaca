import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class DisputeScreen extends StatefulWidget {
  final String rentalId;

  const DisputeScreen({super.key, required this.rentalId});

  @override
  State<DisputeScreen> createState() => _DisputeScreenState();
}

class _DisputeScreenState extends State<DisputeScreen> {
  File? _damageImage;
  final _reasonController = TextEditingController();
  bool _isUploading = false;

  // 📸 Opens the camera to take a photo
  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 50);
    if (pickedFile != null) {
      setState(() => _damageImage = File(pickedFile.path));
    }
  }

  // 🚀 Uploads photo to Storage and Freezes the Database
  Future<void> _submitDispute() async {
    if (_damageImage == null || _reasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please provide a photo and a description.")),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      // 1. Upload Damage Photo to Firebase Storage
      String fileName = 'disputes/${widget.rentalId}_damage.jpg';
      UploadTask uploadTask = FirebaseStorage.instance.ref().child(fileName).putFile(_damageImage!);
      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();

      // 2. Freeze the Database (Change status to Disputed)
      await FirebaseFirestore.instance.collection('rentals').doc(widget.rentalId).update({
        'status': 'Disputed',
        'securityDepositStatus': 'Withheld',
        'damageImageUrl': downloadUrl,
        'damageDescription': _reasonController.text,
        'lenderReviewed': true, // Removes it from their "pending review" list
      });

      if (mounted) {
        Navigator.pop(context); // Go back to the dashboard
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Damage reported. Funds have been frozen."), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      setState(() => _isUploading = false);
      debugPrint("Dispute Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Upload failed.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Report Damage", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.red,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
                "Provide evidence of the damage to hold the security deposit. Admin will review this case.",
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
            ),
            const SizedBox(height: 20),

            // 📸 CAMERA UPLOAD BOX
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 250,
                width: double.infinity,
                decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.grey.shade400, width: 2)
                ),
                child: _damageImage == null
                    ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.camera_alt, size: 60, color: Colors.grey[600]),
                      const SizedBox(height: 10),
                      Text("Tap to take a photo", style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.bold))
                    ]
                )
                    : ClipRRect(
                    borderRadius: BorderRadius.circular(13),
                    child: Image.file(_damageImage!, fit: BoxFit.cover)
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 📝 DESCRIPTION TEXT BOX
            TextField(
              controller: _reasonController,
              maxLines: 4,
              decoration: const InputDecoration(
                  hintText: "Describe the damage (e.g., motor is burnt out, handle is snapped)...",
                  border: OutlineInputBorder()
              ),
            ),
            const SizedBox(height: 30),

            // 🚀 SUBMIT BUTTON
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                ),
                onPressed: _isUploading ? null : _submitDispute,
                child: _isUploading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("FREEZE DEPOSIT & FILE DISPUTE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            )
          ],
        ),
      ),
    );
  }
}