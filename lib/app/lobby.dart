import 'dart:async';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:midterm/app/account.dart';
import 'package:midterm/app/confirm_arrival.dart';
import 'package:midterm/app/post.dart';
import 'package:midterm/db/database_helper.dart';
import 'package:midterm/providers/organization_provider.dart';
import 'package:midterm/services/notification_service.dart';

class LobbyPage extends StatefulWidget {
  const LobbyPage({super.key});

  @override
  State<LobbyPage> createState() => _LobbyPageState();
}

class _LobbyPageState extends State<LobbyPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  StreamSubscription? _actionSub;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    _actionSub = NotificationService.actionStream.stream.listen(
      _handleNotificationTap,
    );

    // Check if app was launched from terminated state via notification
    AwesomeNotifications().getInitialNotificationAction().then((action) {
      if (action != null && action.payload != null) {
        // Small delay to ensure the widget tree is fully mounted before showing bottom sheet
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) _handleNotificationTap(action.payload!);
        });
      }
    });
  }

  void _handleNotificationTap(Map<String, String?> payload) {
    if (!mounted || payload['docId'] == null) return;

    // Switch to Arrived tab
    _tabController.animateTo(1);

    // Open bottom sheet
    _showArrivedBottomSheet(
      context,
      payload['docId']!,
      payload['resi'] ?? '',
      payload['ownerName'] ?? 'Unknown',
      payload['content'] ?? '',
      payload['ownerId'] ?? '',
      FirebaseAuth.instance.currentUser?.uid,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _actionSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orgProvider = Provider.of<OrganizationProvider>(context);
    final user = FirebaseAuth.instance.currentUser;

    if (orgProvider.organizations.isEmpty) {
      return _noOrgPlaceholder();
    }

    return Scaffold(
      body: Column(
        children: [
          // Org selector
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: DropdownButtonFormField<String>(
              initialValue: orgProvider.selectedOrgId,
              decoration: const InputDecoration(
                labelText: 'Organization',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.apartment),
                isDense: true,
              ),
              items: orgProvider.organizations
                  .map(
                    (org) => DropdownMenuItem<String>(
                      value: org['id'] as String,
                      child: Text(org['name'] as String),
                    ),
                  )
                  .toList(),
              onChanged: (val) {
                if (val != null) orgProvider.setSelectedOrg(val);
              },
            ),
          ),
          // Tabs
          TabBar(
            controller: _tabController,
            labelColor: Colors.indigo,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.indigo,
            tabs: const [
              Tab(icon: Icon(Icons.inbox), text: 'Incoming'),
              Tab(icon: Icon(Icons.inventory_2), text: 'Arrived'),
            ],
          ),
          Expanded(
            child: orgProvider.selectedOrgId == null
                ? const Center(child: Text('Select an organization'))
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _PackageList(
                        orgId: orgProvider.selectedOrgId!,
                        status: 'WAITING',
                        emptyMessage:
                            'No packages waiting.\nTap + to post your incoming package.',
                        currentUserId: user?.uid,
                      ),
                      _PackageList(
                        orgId: orgProvider.selectedOrgId!,
                        status: 'ARRIVED',
                        emptyMessage: 'No arrived packages yet.',
                        currentUserId: user?.uid,
                      ),
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PostPage()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Post Package'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _noOrgPlaceholder() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.apartment_outlined, size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              "You haven't joined any organization yet.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const Text(
              "Create a new one or join an existing one with an invite code.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AccountPage()),
              ),
              icon: const Icon(Icons.add_business),
              label: const Text('Create or Join Organization'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reusable package list for a given status
// ---------------------------------------------------------------------------

class _PackageList extends StatelessWidget {
  final String orgId;
  final String status;
  final String emptyMessage;
  final String? currentUserId;

  const _PackageList({
    required this.orgId,
    required this.status,
    required this.emptyMessage,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('lobby_parcels')
          .where('orgId', isEqualTo: orgId)
          .where('status', isEqualTo: status)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Error: ${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        }

        // Sort newest first client-side (avoids composite index requirement)
        final docs = (snapshot.data?.docs ?? [])
          ..sort((a, b) {
            final aTs = (a.data() as Map)['timestamp'] as Timestamp?;
            final bTs = (b.data() as Map)['timestamp'] as Timestamp?;
            if (aTs == null) return 1;
            if (bTs == null) return -1;
            return bTs.compareTo(aTs);
          });

        if (docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                emptyMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 15),
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            final docId = docs[i].id;
            final ownerName = data['owner_name'] as String? ?? 'Unknown';
            final content = data['content'] as String? ?? '';
            final resi = data['resi_number'] as String? ?? '';
            final ownerId = data['owner_id'] as String? ?? '';
            final ts = data['timestamp'] as Timestamp?;
            final timeStr = ts != null
                ? ts.toDate().toLocal().toString().substring(0, 16)
                : 'Just now';
            final isArrived = status == 'ARRIVED';
            final isOwner = currentUserId == ownerId;

            // Privacy: only show real content to the owner
            final displayContent = isOwner ? content : 'Hidden for privacy 🔒';

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              color: isArrived ? Colors.green.shade50 : null,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: isArrived
                    ? () => _showArrivedBottomSheet(
                        context,
                        docId,
                        resi,
                        ownerName,
                        content,
                        ownerId,
                        currentUserId,
                      )
                    : () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ConfirmArrivalPage(
                            packageId: docId,
                            expectedResi: resi,
                            ownerName: ownerName,
                          ),
                        ),
                      ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isArrived
                              ? Colors.green.shade100
                              : Colors.indigo.shade50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          isArrived
                              ? Icons.check_circle_outline
                              : Icons.inventory_2,
                          color: isArrived ? Colors.green : Colors.indigo,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'For: $ownerName',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Contents: $displayContent',
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              timeStr,
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 4),
                            if (isArrived && isOwner)
                              const Text(
                                'Tap to claim ›',
                                style: TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              )
                            else if (!isArrived)
                              const Text(
                                'Tap to confirm arrival ›',
                                style: TextStyle(
                                  color: Colors.indigo,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

void _showArrivedBottomSheet(
  BuildContext context,
  String docId,
  String resi,
  String ownerName,
  String content,
  String ownerId,
  String? currentUserId,
) {
  final isOwner = currentUserId == ownerId;
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.inventory_2, size: 48, color: Colors.green),
          const SizedBox(height: 8),
          Text(
            'Package Arrived!',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'For: $ownerName',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, color: Colors.black54),
          ),
          Text(
            'Contents: $content',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black45),
          ),
          const SizedBox(height: 24),
          if (isOwner) ...[
            ElevatedButton.icon(
              onPressed: () => _claimPackage(context, docId, resi),
              icon: const Icon(Icons.done_all),
              label: const Text('Claim My Package'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Only the package owner can claim this package.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    ),
  );
}

Future<void> _claimPackage(
  BuildContext context,
  String docId,
  String resi,
) async {
  Navigator.pop(context); // close bottom sheet
  try {
    await FirebaseFirestore.instance
        .collection('lobby_parcels')
        .doc(docId)
        .update({'status': 'CLAIMED'});
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final nowStr = DateTime.now().toIso8601String();

    final localId = await DatabaseHelper.instance.insertLog({
      DatabaseHelper.colUserId: user.uid,
      DatabaseHelper.colResi: resi,
      DatabaseHelper.colAction: 'CLAIMED',
      DatabaseHelper.colNotes: '',
      DatabaseHelper.colDate: nowStr,
    });

    await FirebaseFirestore.instance.collection('user_history').add({
      'userId': user.uid,
      'resi_number': resi,
      'action_type': 'CLAIMED',
      'user_notes': '',
      'recorded_at': nowStr,
      'local_id': localId,
    });
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 Package claimed! Check your History tab.'),
          backgroundColor: Colors.green,
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
}
