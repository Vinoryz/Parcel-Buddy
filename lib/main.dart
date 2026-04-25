import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:midterm/firebase_options.dart';
import 'package:midterm/auth/login.dart';
import 'package:midterm/auth/register.dart';
import 'package:midterm/app/home.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const ParcelBuddy());
}

class ParcelBuddy extends StatelessWidget {
  const ParcelBuddy({super.key});

  @override
  Widget build(BuildContext context) {  
    return MaterialApp(initialRoute: 'login', routes: {
      'home': (context) => const HomeScreen(),
      'login': (context) => const LoginScreen(),
      'register': (context) => const RegisterScreen(),
    }
    );
  }
}