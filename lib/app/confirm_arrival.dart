import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:image_picker/image_picker.dart';

/// Opened when a user taps an Incoming (WAITING) package in the Lobby.
/// Requires the user to scan or type the physical resi to prove they have the package.
/// On success → status becomes ARRIVED, owner is notified.
class ConfirmArrivalPage extends StatefulWidget {
  final String packageId;
  final String expectedResi;
  final String ownerName;

  const ConfirmArrivalPage({
    super.key,
    required this.packageId,
    required this.expectedResi,
    required this.ownerName,
  });

  @override
  State<ConfirmArrivalPage> createState() => _ConfirmArrivalPageState();
}

class _ConfirmArrivalPageState extends State<ConfirmArrivalPage> {
  final _resiCtrl = TextEditingController();
  bool _isLoading = false;
  bool _scanned = false;

  @override
  void dispose() {
    _resiCtrl.dispose();
    super.dispose();
  }

  Future<void> _scanLabel(ImageSource source) async {
    final picked = await ImagePicker().pickImage(source: source);
    if (picked == null) return;

    setState(() { _isLoading = true; _scanned = false; });
    final inputImage = InputImage.fromFilePath(picked.path);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final barcodeScanner = BarcodeScanner();
    try {
      final barcodes = await barcodeScanner.processImage(inputImage);
      bool barcodeFound = false;

      for (Barcode barcode in barcodes) {
        if (barcode.rawValue != null) {
          _resiCtrl.text = barcode.rawValue!;
          setState(() => _scanned = true);
          barcodeFound = true;
          break;
        }
      }

      if (!barcodeFound) {
        final recognized = await textRecognizer.processImage(inputImage);
        final match = RegExp(r'\b[A-Z0-9]{8,20}\b').firstMatch(recognized.text.toUpperCase());
        if (match != null) {
          _resiCtrl.text = match.group(0)!;
          setState(() => _scanned = true);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No barcode or resi found. Please type it manually.')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Scan error: $e')));
    } finally {
      textRecognizer.close();
      barcodeScanner.close();
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmArrival() async {
    final input = _resiCtrl.text.trim().toUpperCase();

    if (input.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please scan or enter the resi number.')),
      );
      return;
    }

    if (input != widget.expectedResi.toUpperCase()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Resi does not match. Make sure you have the right package.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Update package status
      final docRef = FirebaseFirestore.instance
          .collection('lobby_parcels')
          .doc(widget.packageId);

      final doc = await docRef.get();
      if (!doc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Package no longer exists in lobby.')),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      final data = doc.data()!;
      await docRef.update({'status': 'ARRIVED'});

      // Write in-app notification to owner
      final ownerId = data['owner_id'] as String?;
      final scanner = FirebaseAuth.instance.currentUser;
      if (ownerId != null) {
        await FirebaseFirestore.instance.collection('notifications').add({
          'toUserId': ownerId,
          'message':
              'Your package (${widget.expectedResi}) has arrived! Go to the Lobby → Arrived tab to claim it.',
          'packageId': widget.packageId,
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
          'fromUserId': scanner?.uid,
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Arrival confirmed! Owner has been notified.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Confirm Arrival'), centerTitle: true),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.qr_code_scanner, size: 72, color: Colors.indigo),
            const SizedBox(height: 16),
            Text(
              'Package for: ${widget.ownerName}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Scan or type the resi on the physical package to confirm it has arrived.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : () => _scanLabel(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const FittedBox(child: Text('Camera')),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : () => _scanLabel(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const FittedBox(child: Text('Gallery')),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _resiCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: 'Resi / Tracking Number',
                prefixIcon: const Icon(Icons.numbers),
                border: const OutlineInputBorder(),
                suffixIcon: _scanned
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : null,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _confirmArrival,
              icon: _isLoading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.done_all),
              label: const Text('Confirm Arrival'),
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
