import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:midterm/app/account.dart';
import 'package:midterm/app/scan.dart';
import 'package:midterm/app/lobby.dart';
import 'package:midterm/app/history.dart';
import 'package:midterm/services/notification_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 1; // Start on Lobby

  static const List<Widget> _pages = [ScanPage(), LobbyPage(), HistoryPage()];

  static const List<String> _titles = [
    'Confirm Arrival',
    'Lobby',
    'My History',
  ];

  StreamSubscription<QuerySnapshot>? _notifSub;
  StreamSubscription? _actionSub;

  @override
  void initState() {
    super.initState();
    _requestNotificationPermission();
    _listenForNotifications();

    // Listen for notification taps to switch to Lobby tab
    _actionSub = NotificationService.actionStream.stream.listen((payload) {
      if (mounted && _selectedIndex != 1) {
        setState(() => _selectedIndex = 1);
      }
    });
  }

  @override
  void dispose() {
    _notifSub?.cancel();
    _actionSub?.cancel();
    super.dispose();
  }

  /// Request permission the first time the home screen loads.
  Future<void> _requestNotificationPermission() async {
    await NotificationService.requestPermission();
  }

  void _listenForNotifications() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _notifSub = FirebaseFirestore.instance
        .collection('notifications')
        .where('toUserId', isEqualTo: user.uid)
        .where('read', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
          for (final change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added) {
              final data = change.doc.data() as Map<String, dynamic>;
              final msg =
                  data['message'] as String? ?? 'Your package has arrived!';
              final packageId = data['packageId'] as String?;

              // Mark as read so we don't re-show it
              change.doc.reference.update({'read': true});

              if (packageId != null) {
                // Fetch package details for the payload
                FirebaseFirestore.instance
                    .collection('lobby_parcels')
                    .doc(packageId)
                    .get()
                    .then((docSnap) {
                      if (docSnap.exists) {
                        final pData = docSnap.data()!;
                        // Fire a real local push notification with payload
                        NotificationService.showPackageArrived(
                          title: '📦 Package Arrived!',
                          body: msg,
                          payload: {
                            'docId': packageId,
                            'resi': pData['resi_number']?.toString() ?? '',
                            'ownerName': pData['owner_name']?.toString() ?? '',
                            'content': pData['content']?.toString() ?? '',
                            'ownerId': pData['owner_id']?.toString() ?? '',
                          },
                        );
                      }
                    });
              } else {
                NotificationService.showPackageArrived(
                  title: '📦 Package Arrived!',
                  body: msg,
                  payload: {},
                );
              }
            }
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
        centerTitle: true,
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: 'Account',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AccountPage()),
            ),
          ),
        ],
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        selectedItemColor: Colors.indigo,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.qr_code_scanner),
            label: 'Scan',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Lobby'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
        ],
      ),
    );
  }
}
