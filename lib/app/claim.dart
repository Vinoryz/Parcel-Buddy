import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:midterm/db/database_helper.dart';

class ClaimPage extends StatefulWidget {
  final String packageId;
  final String expectedResi;

  const ClaimPage({
    super.key,
    required this.packageId,
    required this.expectedResi,
  });

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

  Future<void> _scanResi(ImageSource source) async {
    final picked = await ImagePicker().pickImage(source: source);
    if (picked == null) return;

    setState(() => _isLoading = true);

    final inputImage = InputImage.fromFilePath(picked.path);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final barcodeScanner = BarcodeScanner();

    try {
      // 1. Try Barcode Scanner first
      final barcodes = await barcodeScanner.processImage(inputImage);
      bool barcodeFound = false;

      for (Barcode barcode in barcodes) {
        if (barcode.rawValue != null) {
          _resiController.text = barcode.rawValue!;
          setState(() => _scanSuccess = true);
          barcodeFound = true;
          break; // Use the first barcode found
        }
      }

      // 2. Fall back to Text Recognizer if no barcode found
      if (!barcodeFound) {
        final recognized = await textRecognizer.processImage(inputImage);
        final match = RegExp(
          r'\b[A-Z0-9]{8,20}\b',
        ).firstMatch(recognized.text.toUpperCase());
        if (match != null) {
          _resiController.text = match.group(0)!;
          setState(() => _scanSuccess = true);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Could not find barcode or resi text in scan. Type it manually.',
                ),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Scan error: $e')));
      }
    } finally {
      textRecognizer.close();
      barcodeScanner.close();
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _verify() async {
    final input = _resiController.text.trim().toUpperCase();
    if (input.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the resi number.')),
      );
      return;
    }

    if (input != widget.expectedResi.toUpperCase()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '❌ Resi number does not match! Make sure you have the right package.',
          ),
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
      final nowStr = DateTime.now().toIso8601String();
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final localId = await DatabaseHelper.instance.insertLog({
        DatabaseHelper.colUserId: user.uid,
        DatabaseHelper.colResi: widget.expectedResi,
        DatabaseHelper.colAction: 'CLAIMED',
        DatabaseHelper.colNotes: '',
        DatabaseHelper.colDate: nowStr,
      });

      // 3. Backup to Firestore
      await FirebaseFirestore.instance.collection('user_history').add({
        'userId': user.uid,
        'resi_number': widget.expectedResi,
        'action_type': 'CLAIMED',
        'user_notes': '',
        'recorded_at': nowStr,
        'local_id': localId,
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Claim failed: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Claim Your Package')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            const Icon(Icons.qr_code_scanner, size: 80, color: Colors.indigo),
            const SizedBox(height: 16),
            const Text(
              'To claim this package, scan its barcode/label or type the tracking (resi) number.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : () => _scanResi(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const FittedBox(child: Text('Camera')),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : () => _scanResi(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const FittedBox(child: Text('Gallery')),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _resiController,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: 'Resi / Tracking Number',
                prefixIcon: const Icon(Icons.numbers),
                border: const OutlineInputBorder(),
                suffixIcon: _scanSuccess
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : null,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _verify,
              icon: _isLoading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
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
    ),
  );
}
}
