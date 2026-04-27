import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  File? _imageFile;
  final _resiController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  
  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _takePhoto() async {
    final pickedFile = await ImagePicker(). pickImage(source: ImageSource.camera);
    if (pickedFile != null){
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _chooseImageSource() async {
    showModalBottomSheet(
      context: context, 
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take photo'),
              onTap: () async {
                Navigator.of(context).pop();
                await _takePhoto();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose image from gallery'),
              onTap: () async {
                Navigator.of(context).pop();
                await _pickImage();
              }
            ),
          ],
        )
      ),
    );
  }

  Future<void> _uploadAndSave() async {
    if (_imageFile == null || _resiController.text.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      String fileName = 'parcels/${DateTime.now().millisecondsSinceEpoch}_${_imageFile!.path.split('/').last}';
      final ref = FirebaseStorage.instance.ref().child(fileName);
      await ref.putFile(_imageFile!);
      String imageUrl = await ref.getDownloadURL();

      final user = FirebaseAuth.instance.currentUser;
      await FirebaseFirestore.instance.collection('lobby_parcels').add({
        'resi_number': _resiController.text,
        'photo_url': imageUrl,
        'uploader_name': user?.email ?? user?.uid,
        'status': 'WAITING',
        'timestamp': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Package Uploaded.'))
      );

      setState(() {
        _imageFile = null;
        _resiController.clear();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e'))
      );

      setState(() {
        _isLoading = false;
      });
    }
  }

  void _submit() {
    if (_formKey.currentState!.validate() && _imageFile != null) {
      _uploadAndSave();
    } else if (_imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please take a photo or choose a photo.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    double widthScreen = MediaQuery.of(context).size.width;
    double heightScreen = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Padding(
        padding: EdgeInsetsGeometry.fromLTRB(
          widthScreen * 0.1, 
          heightScreen * 0.1, 
          widthScreen * 0.1, 
          heightScreen * 0.1,
        ),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              GestureDetector(
                onTap: _chooseImageSource,
                child: _imageFile != null
                  ? Image.file(_imageFile!, height: heightScreen * 0.3)
                  : Container(
                    height: heightScreen * 0.3,
                    color: Colors.grey[200],
                    child: Icon(Icons.camera_alt, size: 80),
                  ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _resiController,
                decoration: const InputDecoration(
                  labelText: 'Resi Number',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                  value == null || value.isEmpty ? 'Enter resi number' : null,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _submit, 
                child: _isLoading ? const CircularProgressIndicator() : const Text('Submit')
              ),
            ],
          ),
        ),
      ),
    );
  }
}