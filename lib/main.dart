import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'screens/login_screen.dart';
import 'screens/cadastro_step1_screen.dart';
import 'screens/cadastro_step2_screen.dart';
import 'screens/home_screen.dart';
import 'screens/voice_cards_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/preferences_screen.dart';
import 'screens/notifications_screen.dart';
import 'services/local_storage_service.dart';
import 'services/sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // INICIALIZAR HIVE PARA ARMAZENAMENTO OFFLINE
  await LocalStorageService.init();
  
  // CONFIGURAR LISTENER DE CONECTIVIDADE PARA SINCRONIZAÇÃO AUTOMÁTICA
  Connectivity().onConnectivityChanged.listen((result) {
    if (result != ConnectivityResult.none) {
      // QUANDO VOLTAR ONLINE, SINCRONIZAR PENDÊNCIAS
      SyncService.syncPendingEntries();
    }
  });
  
  // TENTAR SINCRONIZAR AO INICIAR O APP
  SyncService.syncPendingEntries();
  
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _darkMode = false;

  @override
  void initState() {
    super.initState();
    _loadThemePreference();
  }

  Future<void> _loadThemePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final darkMode = prefs.getBool('dark_mode') ?? false;
      debugPrint('Carregando preferência de tema: $darkMode');
      if (mounted) {
        setState(() {
          _darkMode = darkMode;
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar preferência de tema: $e');
      // IGNORAR ERRO E USAR VALOR PADRÃO
      if (mounted) {
        setState(() {
          _darkMode = false;
        });
      }
    }
  }

  void _updateTheme(bool darkMode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final success = await prefs.setBool('dark_mode', darkMode);
      debugPrint('Salvando preferência de tema: $darkMode, sucesso: $success');
      
      // VERIFICAR SE FOI SALVO CORRETAMENTE
      final saved = prefs.getBool('dark_mode');
      debugPrint('Verificação após salvar: $saved');
      
      if (mounted && _darkMode != darkMode) {
        setState(() {
          _darkMode = darkMode;
        });
      }
    } catch (e) {
      debugPrint('Erro ao salvar preferência de tema: $e');
      // SE HOUVER ERRO AO SALVAR, AINDA ATUALIZA O ESTADO
      if (mounted && _darkMode != darkMode) {
        setState(() {
          _darkMode = darkMode;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lightTheme = ThemeData(
      primarySwatch: Colors.blue,
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF5F7FB),
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF5C6EF8),
        surface: Colors.white,
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(color: Color(0xFF2F2F2F)),
        bodyMedium: TextStyle(color: Color(0xFF6B7280)),
      ),
      iconTheme: const IconThemeData(color: Color(0xFF2F2F2F)),
    );
    
    final darkTheme = ThemeData(
      primarySwatch: Colors.blue,
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF121212),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF5C6EF8),
        surface: Color(0xFF1E1E1E),
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(color: Colors.white),
        bodyMedium: TextStyle(color: Color(0xFFB0B4C1)),
      ),
      iconTheme: const IconThemeData(color: Colors.white),
    );

    return MaterialApp(
      title: 'Clareza Diária',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: _darkMode ? ThemeMode.dark : ThemeMode.light,
      initialRoute: '/login',
      routes: {
        '/login': (context) => Theme(
          data: lightTheme, // FORÇAR TEMA CLARO NA TELA DE LOGIN
          child: const LoginScreen(),
        ),
        '/cadastro-step1': (context) => const CadastroStep1Screen(),
        '/cadastro-step2': (context) => const CadastroStep2Screen(),
        '/home': (context) => const HomeScreen(),
        '/voice-cards': (context) => const VoiceCardsScreen(),
        '/profile': (context) => ProfileScreen(onThemeChanged: _updateTheme),
        '/preferences': (context) => PreferencesScreen(onThemeChanged: _updateTheme),
        '/notifications': (context) => const NotificationsScreen(),
      },
    );
  }
}
