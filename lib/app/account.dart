import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final _createOrgCtrl = TextEditingController();
  final _joinCodeCtrl = TextEditingController();
  bool _isCreating = false;
  bool _isJoining = false;

  @override
  void dispose() {
    _createOrgCtrl.dispose();
    _joinCodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    // Pop all pushed routes (AccountPage, HomeScreen) so AuthWrapper
    // rebuilds at the root and shows LoginScreen.
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _createOrganization() async {
    final name = _createOrgCtrl.text.trim();
    if (name.isEmpty) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isCreating = true);
    try {
      final orgRef = await FirebaseFirestore.instance.collection('organizations').add({
        'name': name,
        'address': '',
      });
      await FirebaseFirestore.instance.collection('memberships').add({
        'userId': user.uid,
        'orgId': orgRef.id,
        'role': 'admin',
        'joinedAt': FieldValue.serverTimestamp(),
      });
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        {'organizations': FieldValue.arrayUnion([orgRef.id])},
        SetOptions(merge: true),
      );
      _createOrgCtrl.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Organization "$name" created! 🎉')),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  Future<void> _generateInviteCode(String orgId, String orgName) async {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rnd = Random.secure();
    final code = List.generate(6, (_) => chars[rnd.nextInt(chars.length)]).join();

    await FirebaseFirestore.instance.collection('invites').doc(code).set({
      'orgId': orgId,
      'orgName': orgName,
      'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(hours: 24))),
    });

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Invite Code'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Share this code to invite people to "$orgName":', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: code));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Code copied!')),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  border: Border.all(color: Colors.indigo),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(code, style: const TextStyle(
                    fontSize: 32, fontWeight: FontWeight.bold,
                    letterSpacing: 6, color: Colors.indigo)),
              ),
            ),
            const SizedBox(height: 8),
            const Text('Tap the code to copy. Expires in 24 hours.',
                style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Done'))],
      ),
    );
  }

  Future<void> _joinOrganization() async {
    final code = _joinCodeCtrl.text.trim().toUpperCase();
    if (code.isEmpty) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isJoining = true);
    try {
      final inviteDoc = await FirebaseFirestore.instance.collection('invites').doc(code).get();
      if (!inviteDoc.exists) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid invite code.')));
        return;
      }
      final data = inviteDoc.data()!;
      if ((data['expiresAt'] as Timestamp).toDate().isBefore(DateTime.now())) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This code has expired.')));
        return;
      }
      final orgId = data['orgId'] as String;
      final orgName = data['orgName'] as String? ?? 'Organization';

      // Already a member?
      final existing = await FirebaseFirestore.instance
          .collection('memberships')
          .where('userId', isEqualTo: user.uid)
          .where('orgId', isEqualTo: orgId)
          .limit(1).get();

      if (existing.docs.isNotEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Already a member.')));
        return;
      }

      await FirebaseFirestore.instance.collection('memberships').add({
        'userId': user.uid,
        'orgId': orgId,
        'role': 'member',
        'joinedAt': FieldValue.serverTimestamp(),
      });
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        {'organizations': FieldValue.arrayUnion([orgId])},
        SetOptions(merge: true),
      );
      _joinCodeCtrl.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Joined "$orgName"! 🎉')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // User info
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const CircleAvatar(radius: 28, backgroundColor: Colors.indigo,
                        child: Icon(Icons.person, color: Colors.white, size: 30)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user?.email ?? 'Unknown',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          Text(user?.uid ?? '', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Create org
            const Text('Create Organization', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: TextField(
                controller: _createOrgCtrl,
                decoration: const InputDecoration(
                  labelText: 'Organization Name',
                  border: OutlineInputBorder(), isDense: true,
                ),
              )),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _isCreating ? null : _createOrganization,
                child: _isCreating
                    ? const SizedBox(height: 16, width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Create'),
              ),
            ]),
            const SizedBox(height: 24),

            // Join org
            const Text('Join Organization', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: TextField(
                controller: _joinCodeCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: '6-Digit Invite Code',
                  border: OutlineInputBorder(), isDense: true,
                ),
              )),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _isJoining ? null : _joinOrganization,
                child: _isJoining
                    ? const SizedBox(height: 16, width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Join'),
              ),
            ]),
            const SizedBox(height: 24),

            // Organizations list
            const Text('Your Organizations', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (user != null)
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
                builder: (context, snap) {
                  if (!snap.hasData) return const LinearProgressIndicator();
                  final orgIds = ((snap.data?.data() as Map<String, dynamic>?)?['organizations'] as List<dynamic>? ?? []).cast<String>();
                  if (orgIds.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text("No organizations yet.", style: TextStyle(color: Colors.grey)),
                    );
                  }
                  return Column(
                    children: orgIds.map((orgId) => FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance.collection('organizations').doc(orgId).get(),
                      builder: (context, orgSnap) {
                        if (!orgSnap.hasData || !orgSnap.data!.exists) return const SizedBox.shrink();
                        final orgName = orgSnap.data!.get('name') as String;
                        return Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          child: ListTile(
                            leading: const Icon(Icons.apartment, color: Colors.indigo),
                            title: Text(orgName),
                            trailing: TextButton.icon(
                              icon: const Icon(Icons.share, size: 16),
                              label: const Text('Invite'),
                              onPressed: () => _generateInviteCode(orgId, orgName),
                            ),
                          ),
                        );
                      },
                    )).toList(),
                  );
                },
              ),
            const SizedBox(height: 32),

            OutlinedButton.icon(
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text('Logout', style: TextStyle(color: Colors.red)),
              onPressed: _logout,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
