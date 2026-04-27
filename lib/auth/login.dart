import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';



class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _isLoadingGuest = false;
  String _errorCode = "";

  void navigateRegister() {
    if (!context.mounted) return;
    Navigator.pushReplacementNamed(context, 'register');
  }

  void navigateHome(){
    if (!context.mounted) return;
    Navigator.pushReplacementNamed(context, 'home');
  }

  void signIn() async {
    setState(() {
      _isLoading = true;
      _errorCode = "";
    });

    try {
      UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text, 
        password: _passwordController.text,
      );
      String userId = userCredential.user!.uid;

      await FirebaseFirestore.instance.collection('users').doc(userId).get();
      navigateHome();
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorCode = e.code;
        _isLoading = false;
      });
    }

    setState(() {
      _isLoading = false;
    });
  }

  void signInAsGuest() async {
    setState(() {
      _isLoadingGuest = true;
      _errorCode = "";
    });

    try {
      await FirebaseAuth.instance.signInAnonymously();
      navigateHome();
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorCode = e.code;
        _isLoadingGuest = false;
      });
    }
    
    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    double widthScreen = MediaQuery.of(context).size.width;
    double heightScreen = MediaQuery.of(context).size.height;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
        centerTitle: true,
      ),
      body: Padding(
        padding: EdgeInsets.fromLTRB(
          widthScreen * 0.1, 
          heightScreen * 0.1, 
          widthScreen * 0.1, 
          heightScreen * 0.1
        ),
        child: Center(
          child: ListView(
            children: [
              // const SizedBox(height: 48),
              Icon(Icons.lock_outline, size: 100, color: Colors.blue[200]),
              // const SizedBox(height: 48),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(label: Text('Email')),
              ),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(label: Text('Password')),
              ),
              const SizedBox(height: 24),
              _errorCode != ""
                ? Column(
                    children: [Text(_errorCode), const SizedBox(height: 24)]) 
                : const SizedBox(height: 0),
              OutlinedButton(
                onPressed: signIn, 
                child: _isLoading ? const CircularProgressIndicator() : const Text('Login'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: signInAsGuest, 
                child: _isLoadingGuest ? const CircularProgressIndicator() : const Text('Login as Guest'),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Don\'t have an account?'),
                  TextButton(
                    onPressed: navigateRegister, 
                    child: const Text('Register'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}