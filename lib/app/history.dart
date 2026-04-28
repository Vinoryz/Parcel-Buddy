import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:midterm/db/database_helper.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    setState(() => _isLoading = true);
    final data = await DatabaseHelper.instance.queryUserLogs(user.uid);
    if (mounted) {
      setState(() {
        _logs = data;
        _isLoading = false;
      });
    }
  }

  Future<void> _restoreFromCloud() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    setState(() => _isLoading = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('user_history')
          .where('userId', isEqualTo: user.uid)
          .get();

      for (var doc in snap.docs) {
        final data = doc.data();
        await DatabaseHelper.instance.insertLogIfNotExists({
          DatabaseHelper.colUserId: user.uid,
          DatabaseHelper.colResi: data['resi_number'],
          DatabaseHelper.colAction: data['action_type'],
          DatabaseHelper.colNotes: data['user_notes'],
          DatabaseHelper.colDate: data['recorded_at'],
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to restore from cloud: $e')));
      }
    } finally {
      _loadLogs();
    }
  }

  Future<void> _showEditDialog(int id, String currentNote) async {
    final controller = TextEditingController(text: currentNote);
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Note'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Add a personal note...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await DatabaseHelper.instance.updateNote(id, controller.text);
              if (ctx.mounted) Navigator.pop(ctx);
              
              // Sync to cloud in background
              FirebaseFirestore.instance.collection('user_history').where('local_id', isEqualTo: id).get().then((snap) {
                for (var doc in snap.docs) {
                  doc.reference.update({'user_notes': controller.text});
                }
              });
              
              _loadLogs();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteLog(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Record'),
        content: const Text(
          'Are you sure you want to delete this history entry?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await DatabaseHelper.instance.deleteLog(id);
      
      // Sync delete to cloud
      FirebaseFirestore.instance.collection('user_history').where('local_id', isEqualTo: id).get().then((snap) {
        for (var doc in snap.docs) {
          doc.reference.delete();
        }
      });
      
      _loadLogs();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_logs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.history_outlined, size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No claim history yet.',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              'Claimed packages will appear here.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _restoreFromCloud,
              icon: const Icon(Icons.cloud_download_outlined),
              label: const Text('Restore from Cloud'),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.indigo,
                backgroundColor: Colors.indigo.shade50,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _restoreFromCloud,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _logs.length,
        itemBuilder: (context, i) {
          final log = _logs[i];
          final id = log[DatabaseHelper.colId] as int;
          final resi = log[DatabaseHelper.colResi] as String;
          final action = log[DatabaseHelper.colAction] as String;
          final note = log[DatabaseHelper.colNotes] as String? ?? '';
          final date = log[DatabaseHelper.colDate] as String;
          final dateFormatted = date.length >= 16
              ? date.substring(0, 16).replaceFirst('T', ' ')
              : date;

          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              resi,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              '$action · $dateFormatted',
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.edit_outlined,
                          color: Colors.blue,
                        ),
                        onPressed: () => _showEditDialog(id, note),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                        onPressed: () => _deleteLog(id),
                      ),
                    ],
                  ),
                  if (note.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.notes, size: 16, color: Colors.grey),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              note,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
