import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:midterm/db/database_helper.dart';

class ClaimPage extends StatefulWidget {
  final String packageId;
  final String expectedResi;

  const ClaimPage({super.key, required this.packageId, required this.expectedResi});

  @override
  State<ClaimPage> createState() => _ClaimPageState();
}

class _ClaimPageState extends State<ClaimPage> {
  final _resiController = TextEditingController();
  bool _isLoading = false;
  bool _scanSuccess = false;

  @override
  void dispose() {
    _resiController.dispose();
    super.dispose();
  }

  Future<void> _scanResi() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.camera);
    if (picked == null) return;

    setState(() => _isLoading = true);

    final inputImage = InputImage.fromFilePath(picked.path);
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);

    try {
      final recognized = await recognizer.processImage(inputImage);
      final match = RegExp(r'\b[A-Z0-9]{8,20}\b').firstMatch(recognized.text.toUpperCase());
      if (match != null) {
        _resiController.text = match.group(0)!;
        setState(() => _scanSuccess = true);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Could not find resi in scan. Type it manually.')));
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Scan error: $e')));
    } finally {
      recognizer.close();
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _verify() async {
    final input = _resiController.text.trim().toUpperCase();
    if (input.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter the resi number.')));
      return;
    }

    if (input != widget.expectedResi.toUpperCase()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Resi number does not match! Make sure you have the right package.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Mark as CLAIMED in Firestore
      await FirebaseFirestore.instance
          .collection('lobby_parcels')
          .doc(widget.packageId)
          .update({'status': 'CLAIMED'});

      // 2. Save to local SQLite history
      await DatabaseHelper.instance.insertLog({
        DatabaseHelper.colResi: widget.expectedResi,
        DatabaseHelper.colAction: 'CLAIMED',
        DatabaseHelper.colNotes: '',
        DatabaseHelper.colDate: DateTime.now().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Package claimed successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Claim failed: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Claim Your Package')),
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.qr_code_scanner, size: 80, color: Colors.indigo),
            const SizedBox(height: 16),
            const Text(
              'To claim this package, scan the label or type the tracking (resi) number.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: _isLoading ? null : _scanResi,
              icon: const Icon(Icons.camera_alt),
              label: const Text('Scan Label'),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _resiController,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: 'Resi / Tracking Number',
                prefixIcon: const Icon(Icons.numbers),
                border: const OutlineInputBorder(),
                suffixIcon: _scanSuccess ? const Icon(Icons.check_circle, color: Colors.green) : null,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _verify,
              icon: _isLoading
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.verified_outlined),
              label: const Text('Verify & Claim'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
