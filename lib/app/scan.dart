import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:midterm/providers/organization_provider.dart';

/// Scan Tab — Confirm physical package arrival.
/// Scans the physical label (camera) or manual resi entry.
/// Finds the matching WAITING package in the lobby and marks it ARRIVED.
/// Writes a notification doc for the owner.
class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  final _resiCtrl = TextEditingController();
  bool _isLoading = false;
  bool _scanned = false;

  @override
  void dispose() {
    _resiCtrl.dispose();
    super.dispose();
  }

  Future<void> _scanWithCamera() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.camera);
    if (picked == null) return;

    setState(() { _isLoading = true; _scanned = false; });
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final recognized = await recognizer.processImage(InputImage.fromFilePath(picked.path));
      final match = RegExp(r'\b[A-Z0-9]{8,20}\b').firstMatch(recognized.text.toUpperCase());
      if (match != null) {
        _resiCtrl.text = match.group(0)!;
        setState(() => _scanned = true);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No resi detected. Type it manually.')),
          );
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Scan error: $e')));
    } finally {
      recognizer.close();
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmArrival() async {
    final resi = _resiCtrl.text.trim().toUpperCase();
    if (resi.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please scan or enter a resi number.')),
      );
      return;
    }

    final orgId = Provider.of<OrganizationProvider>(context, listen: false).selectedOrgId;
    if (orgId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select an organization in the Account tab first.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('lobby_parcels')
          .where('orgId', isEqualTo: orgId)
          .where('resi_number', isEqualTo: resi)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Package not found in lobby. Ask the owner to post it first.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      final doc = snapshot.docs.first;
      final data = doc.data();
      final status = data['status'] as String? ?? '';

      if (status == 'ARRIVED') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Package already confirmed as arrived. Check the "Arrived" tab.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      if (status == 'CLAIMED') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('This package has already been claimed. 🎉'),
              backgroundColor: Colors.green,
            ),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      // Mark ARRIVED
      await doc.reference.update({'status': 'ARRIVED'});

      // Notify the owner (Firestore-based notification)
      final ownerId = data['owner_id'] as String?;
      final scannerUser = FirebaseAuth.instance.currentUser;
      if (ownerId != null) {
        await FirebaseFirestore.instance.collection('notifications').add({
          'toUserId': ownerId,
          'message': 'Your package (${data['resi_number']}) has arrived! Go claim it from the lobby.',
          'packageId': doc.id,
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
          'fromUserId': scannerUser?.uid,
        });
      }

      if (mounted) {
        _resiCtrl.clear();
        setState(() => _scanned = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Arrival confirmed! Owner has been notified.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.qr_code_scanner, size: 80, color: Colors.indigo),
          const SizedBox(height: 16),
          const Text(
            'Confirm Package Arrival',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Scan the physical package label with the camera, or type the resi manually, '
            'then tap Confirm. The owner will be notified to pick it up.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 32),
          OutlinedButton.icon(
            onPressed: _isLoading ? null : _scanWithCamera,
            icon: const Icon(Icons.camera_alt),
            label: const Text('Scan Label with Camera'),
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _resiCtrl,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: 'Resi / Tracking Number',
              prefixIcon: const Icon(Icons.numbers),
              border: const OutlineInputBorder(),
              suffixIcon: _scanned ? const Icon(Icons.check_circle, color: Colors.green) : null,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _confirmArrival,
            icon: _isLoading
                ? const SizedBox(height: 18, width: 18,
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
    );
  }
}