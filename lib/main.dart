import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'screens/login_screen.dart';
import 'providers/app_theme_provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:safe_device/safe_device.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Setup ffi for Windows/Linux desktop apps for local DB if still needed
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Livello 2 e Livello 3: Protezioni RASP e Anti-Screenshot
  if (Platform.isAndroid || Platform.isIOS) {
    try {
      bool isJailBroken = await SafeDevice.isJailBroken;
      bool isRealDevice = await SafeDevice.isRealDevice;
      
      if (isJailBroken || !isRealDevice) {
        runApp(
          const MaterialApp(
            home: Scaffold(
              backgroundColor: Colors.redAccent, 
              body: Center(
                child: Text(
                  "ACCESSO NEGATO\nDispositivo Compromesso (Root/Emulatore)", 
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)
                )
              )
            )
          )
        );
        return; // Blocca l'avvio
      }
    } catch (e) {
      print("Errore RASP: $e");
    }
  }

  runApp(
    ChangeNotifierProvider(
      create: (_) => AppThemeProvider(),
      child: const ContabileApp(),
    ),
  );
}

class ContabileApp extends StatelessWidget {
  const ContabileApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<AppThemeProvider>();
    return MaterialApp(
      title: 'Contabilità App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: theme.primaryColor),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}
