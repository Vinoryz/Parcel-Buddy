import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:midterm/app/account.dart';
import 'package:midterm/app/scan.dart';
import 'package:midterm/app/lobby.dart';
import 'package:midterm/app/history.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 1; // Start on Lobby

  static const List<Widget> _pages = [
    ScanPage(),
    LobbyPage(),
    HistoryPage(),
  ];

  static const List<String> _titles = [
    'Confirm Arrival',
    'Lobby',
    'My History',
  ];

  StreamSubscription<QuerySnapshot>? _notifSub;

  @override
  void initState() {
    super.initState();
    _listenForNotifications();
  }

  @override
  void dispose() {
    _notifSub?.cancel();
    super.dispose();
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
          final msg = (change.doc.data() as Map<String, dynamic>)['message'] as String?
              ?? 'Your package has arrived!';
          // Mark as read immediately
          change.doc.reference.update({'read': true});
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('📦 $msg'),
                backgroundColor: Colors.green.shade700,
                duration: const Duration(seconds: 5),
              ),
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
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        selectedItemColor: Colors.indigo,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.qr_code_scanner), label: 'Scan'),
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Lobby'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
        ],
      ),
    );
  }
}
