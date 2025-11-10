import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/cadastro_step1_screen.dart';
import 'screens/cadastro_step2_screen.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Clareza Diária',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/cadastro-step1': (context) => const CadastroStep1Screen(),
        '/cadastro-step2': (context) => const CadastroStep2Screen(),
        '/home': (context) => const HomeScreen(),
      },
    );
  }
}
