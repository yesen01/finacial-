import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'services/vault_firestore.dart';
import 'screens/home_page.dart';
import 'screens/add_voucher_page.dart';
import 'screens/login_page.dart'; 
import 'providers/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyACLZPCH_UV852tCd2Pr4u7TMJ9dyp_ayM",
      authDomain: "webfinal-8bb06.firebaseapp.com",
      projectId: "webfinal-8bb06",
      storageBucket: "webfinal-8bb06.firebasestorage.app",
      messagingSenderId: "291762753290",
      appId: "1:291762753290:web:cc9fc0f42c0953730134f3"
    )
  );
  
  // Requirement: Initialize Vault
  await VaultFirestore().ensureVaultExists();

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: themeProvider.themeMode,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.teal,
        brightness: Brightness.light,
        textTheme: GoogleFonts.latoTextTheme(),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.teal,
        brightness: Brightness.dark,
        textTheme: GoogleFonts.latoTextTheme(ThemeData.dark().textTheme),
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Scaffold(body: Center(child: CircularProgressIndicator()));
          return snapshot.hasData ? const HomePage() : const LoginPage();
        },
      ),
      routes: {
        '/add': (context) => const AddVoucherPage(),
      },
    );
  }
}