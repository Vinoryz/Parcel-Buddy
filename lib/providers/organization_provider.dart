import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OrganizationProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _organizations = [];
  String? _selectedOrgId;

  List<Map<String, dynamic>> get organizations => _organizations;
  String? get selectedOrgId => _selectedOrgId;

  OrganizationProvider() {
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        _listenToOrganizations(user.uid);
      } else {
        _organizations = [];
        _selectedOrgId = null;
        notifyListeners();
      }
    });
  }

  void _listenToOrganizations(String userId) {
    FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .snapshots()
        .listen((userDoc) async {
      if (!userDoc.exists || userDoc.data() == null) return;

      List<dynamic> orgIds = (userDoc.data() as Map<String, dynamic>)['organizations'] ?? [];
      List<Map<String, dynamic>> loadedOrgs = [];

      for (String orgId in orgIds.cast<String>()) {
        DocumentSnapshot orgDoc = await FirebaseFirestore.instance
            .collection('organizations')
            .doc(orgId)
            .get();
        if (orgDoc.exists) {
          loadedOrgs.add({'id': orgDoc.id, 'name': orgDoc.get('name')});
        }
      }

      _organizations = loadedOrgs;

      if (_organizations.isNotEmpty &&
          !_organizations.any((o) => o['id'] == _selectedOrgId)) {
        _selectedOrgId = _organizations.first['id'];
      } else if (_organizations.isEmpty) {
        _selectedOrgId = null;
      }

      notifyListeners();
    });
  }

  void setSelectedOrg(String orgId) {
    _selectedOrgId = orgId;
    notifyListeners();
  }
}
