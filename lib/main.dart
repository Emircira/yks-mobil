import 'package:flutter/material.dart';
import 'screens/login_screen.dart';

void main() {
  runApp(const YksAsistanApp());
}

class YksAsistanApp extends StatelessWidget {
  const YksAsistanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'YKS Asistan',
      theme: ThemeData(primarySwatch: Colors.deepPurple, useMaterial3: true),
      home: const LoginScreen(),
    );
  }
}
