import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:midterm/providers/organization_provider.dart';

/// Page opened from the Lobby FAB.
/// Purpose: Post an expected incoming package (WAITING status).
/// The current logged-in user is automatically the owner.
class PostPage extends StatefulWidget {
  const PostPage({super.key});

  @override
  State<PostPage> createState() => _PostPageState();
}

class _PostPageState extends State<PostPage> {
  final _formKey = GlobalKey<FormState>();
  final _resiCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _resiCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _scanLabel(ImageSource source) async {
    final picked = await ImagePicker().pickImage(source: source);
    if (picked == null) return;

    setState(() => _isLoading = true);
    final inputImage = InputImage.fromFilePath(picked.path);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final barcodeScanner = BarcodeScanner();

    try {
      final barcodes = await barcodeScanner.processImage(inputImage);
      bool barcodeFound = false;

      for (Barcode barcode in barcodes) {
        if (barcode.rawValue != null) {
          _resiCtrl.text = barcode.rawValue!;
          barcodeFound = true;
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('✓ Resi extracted from barcode!'), backgroundColor: Colors.green),
            );
          }
          break;
        }
      }

      if (!barcodeFound) {
        final recognized = await textRecognizer.processImage(inputImage);
        final match = RegExp(r'\b[A-Z0-9]{8,20}\b').firstMatch(recognized.text.toUpperCase());
        if (match != null) {
          _resiCtrl.text = match.group(0)!;
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('✓ Resi extracted!'), backgroundColor: Colors.green),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No barcode or resi found in image. Type it manually.')),
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final orgId = Provider.of<OrganizationProvider>(context, listen: false).selectedOrgId;
    if (orgId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select an organization in the Account tab first.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Fetch owner's display name
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final ownerName = (userDoc.data()?['name'] as String?) ?? user.email ?? 'Unknown';
      final resi = _resiCtrl.text.trim().toUpperCase();

      // Duplicate check
      final dup = await FirebaseFirestore.instance
          .collection('lobby_parcels')
          .where('orgId', isEqualTo: orgId)
          .where('resi_number', isEqualTo: resi)
          .limit(1)
          .get();

      if (dup.docs.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('This resi is already in the lobby.'), backgroundColor: Colors.orange),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      await FirebaseFirestore.instance.collection('lobby_parcels').add({
        'resi_number': resi,
        'content': _contentCtrl.text.trim(),
        'orgId': orgId,
        'owner_id': user.uid,
        'owner_name': ownerName,
        'status': 'WAITING',
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Posted to lobby! ✅'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Post Incoming Package'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  border: Border.all(color: Colors.indigo.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.indigo),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Post a package you are expecting. '
                        'Others will scan it when it arrives and you will be notified.',
                        style: TextStyle(color: Colors.indigo),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
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
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Row(children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('or type manually', style: TextStyle(color: Colors.grey)),
                  ),
                  Expanded(child: Divider()),
                ]),
              ),
              TextFormField(
                controller: _resiCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Resi / Tracking Number *',
                  prefixIcon: Icon(Icons.numbers),
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _contentCtrl,
                decoration: const InputDecoration(
                  labelText: 'Package Contents *',
                  hintText: 'e.g. Shopee box, headphones',
                  prefixIcon: Icon(Icons.inventory_2_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _submit,
                icon: _isLoading
                    ? const SizedBox(height: 18, width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.upload),
                label: const Text('Post to Lobby'),
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
