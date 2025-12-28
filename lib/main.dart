import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/vault_provider.dart';
import 'screens/home_page.dart';
import 'screens/add_voucher_page.dart';

void main() async{
  WidgetsFlutterBinding.ensureInitialized();

  if(kIsWeb){
     await Firebase.initializeApp(options:FirebaseOptions(apiKey: "AIzaSyACLZPCH_UV852tCd2Pr4u7TMJ9dyp_ayM",
  authDomain: "webfinal-8bb06.firebaseapp.com",
  projectId: "webfinal-8bb06",
  storageBucket: "webfinal-8bb06.firebasestorage.app",
  messagingSenderId: "291762753290",
  appId: "1:291762753290:web:cc9fc0f42c0953730134f3"));
  }else{
    await Firebase.initializeApp();
  }





  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => VaultProvider()),
      ],
      child: MaterialApp(
        title: 'Financial Vault',
        theme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal)),
        initialRoute: '/',
        routes: {
          '/': (_) => const HomePage(),
          '/add': (_) => const AddVoucherPage(),
        },
      ),
    );
  }
}
