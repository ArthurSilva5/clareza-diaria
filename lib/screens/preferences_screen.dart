import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PreferencesScreen extends StatefulWidget {
  final Function(bool)? onThemeChanged;
  
  const PreferencesScreen({super.key, this.onThemeChanged});

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  bool _darkMode = false;
  bool _notificationsEnabled = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final darkMode = prefs.getBool('dark_mode') ?? false;
      final notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      if (mounted) {
        setState(() {
          _darkMode = darkMode;
          _notificationsEnabled = notificationsEnabled;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _darkMode = false;
          _notificationsEnabled = true;
          _loading = false;
        });
      }
    }
  }

  Future<void> _saveDarkMode(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('dark_mode', value);
      
      if (!mounted) return;
      setState(() {
        _darkMode = value;
      });
      // Notificar mudança de tema
      if (widget.onThemeChanged != null) {
        widget.onThemeChanged!(value);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              value ? 'Modo escuro ativado' : 'Modo escuro desativado',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar preferência: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _saveNotificationsEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', value);
    if (!mounted) return;
    setState(() {
      _notificationsEnabled = value;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value ? 'Notificações ativadas' : 'Notificações desativadas',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back, 
            color: Theme.of(context).iconTheme.color ?? 
                   (Theme.of(context).brightness == Brightness.dark 
                    ? Colors.white 
                    : const Color(0xFF2F2F2F)),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Preferências',
          style: TextStyle(
            color: Theme.of(context).textTheme.titleLarge?.color ?? 
                   (Theme.of(context).brightness == Brightness.dark 
                    ? Colors.white 
                    : const Color(0xFF2F2F2F)),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Modo Escuro
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF9C27B0).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.dark_mode_outlined,
                            color: Color(0xFF9C27B0),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Modo Escuro',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).textTheme.titleLarge?.color ?? 
                                         (Theme.of(context).brightness == Brightness.dark 
                                          ? Colors.white 
                                          : const Color(0xFF2F2F2F)),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Ative o tema escuro do aplicativo',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Theme.of(context).textTheme.bodyMedium?.color ?? 
                                         (Theme.of(context).brightness == Brightness.dark 
                                          ? const Color(0xFFB0B4C1) 
                                          : const Color(0xFF6B7280)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _darkMode,
                          onChanged: _saveDarkMode,
                          activeThumbColor: const Color(0xFF5C6EF8),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Notificações
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4CAF50).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.notifications_outlined,
                            color: Color(0xFF4CAF50),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Notificações',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).textTheme.titleLarge?.color ?? 
                                         (Theme.of(context).brightness == Brightness.dark 
                                          ? Colors.white 
                                          : const Color(0xFF2F2F2F)),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Receba alertas e lembretes',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Theme.of(context).textTheme.bodyMedium?.color ?? 
                                         (Theme.of(context).brightness == Brightness.dark 
                                          ? const Color(0xFFB0B4C1) 
                                          : const Color(0xFF6B7280)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _notificationsEnabled,
                          onChanged: _saveNotificationsEnabled,
                          activeThumbColor: const Color(0xFF5C6EF8),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        onTap: (index) {
          // Navegar de volta para a home com o índice selecionado
          Navigator.of(context).pushReplacementNamed(
            '/home',
            arguments: {
              ...?args,
              'selectedIndex': index,
            },
          );
        },
        selectedItemColor: const Color(0xFF5C6EF8),
        unselectedItemColor: const Color(0xFFB0B4C1),
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            label: 'Início',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.book_outlined),
            label: 'Diário',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.access_time_outlined),
            label: 'Rotina',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_outlined),
            label: 'Relatório',
          ),
        ],
      ),
    );
  }
}

