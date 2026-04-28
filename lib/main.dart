import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:midterm/app/home.dart';
import 'package:midterm/auth/login.dart';
import 'package:midterm/auth/register.dart';
import 'package:midterm/firebase_options.dart';
import 'package:midterm/providers/organization_provider.dart';
import 'package:midterm/services/notification_service.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await NotificationService.initialize();
  runApp(const ParcelBuddy());
}

class ParcelBuddy extends StatelessWidget {
  const ParcelBuddy({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => OrganizationProvider())],
      child: MaterialApp(
        title: 'ParcelBuddy',
        debugShowCheckedModeBanner: false,
        routes: {'register': (_) => const RegisterScreen()},
        home: const _AuthWrapper(),
      ),
    );
  }
}

/// Watches FirebaseAuth state — skips login screen if already authenticated.
class _AuthWrapper extends StatelessWidget {
  const _AuthWrapper();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return snapshot.hasData ? const HomeScreen() : const LoginScreen();
      },
    );
  }
}