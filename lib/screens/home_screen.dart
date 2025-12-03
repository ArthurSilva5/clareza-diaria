import 'package:flutter/material.dart';

import 'diary_screen.dart';
import 'routine_list_screen.dart';
import 'reports_screen.dart';
import 'calm_modal.dart';
import '../services/api_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String userName = 'Usuário';
  String userRole = 'Perfil não informado';
  Map<String, dynamic>? userArgs;
  int _selectedIndex = 0;
  bool _hasInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    userArgs = args;
    userName = args != null && args['nomeCompleto'] != null
        ? args['nomeCompleto'] as String
        : 'Usuário';
    userRole = args != null && args['perfil'] != null
        ? args['perfil'] as String
        : (args != null && args['role'] != null
            ? args['role'] as String
            : 'Perfil não informado');
    
    // VERIFICAR SE HÁ UM ÍNDICE SELECIONADO PASSADO COMO ARGUMENTO
    // MAS NÃO RESETAR SE JÁ ESTIVERMOS NA ABA DE ROTINAS (ÍNDICE 2) OU SE JÁ INICIALIZAMOS
    if (!_hasInitialized && args != null && args['selectedIndex'] != null) {
      final selectedIndex = args['selectedIndex'] as int?;
      if (selectedIndex != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _selectedIndex = selectedIndex;
              _hasInitialized = true;
            });
          }
        });
      } else {
        _hasInitialized = true;
      }
    } else if (!_hasInitialized) {
      _hasInitialized = true;
    }
    
    // SE FORÇAR RECARREGAMENTO, RESETAR A FLAG DE INICIALIZAÇÃO
    if (args != null && args['forceReload'] == true) {
      _hasInitialized = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // AJUSTAR ÍNDICES DAS PÁGINAS BASEADO NO PERFIL
    // ADMINISTRADOR TEM ACESSO A TODAS AS TELAS
    final pages = _isAdministrador
        ? [
            // ADMINISTRADOR: TODAS AS TELAS (INÍCIO, DIÁRIO, ROTINA, RELATÓRIO)
            _HomeTab(
              header: _buildHeader(),
              isResponsavel: true, // ADMINISTRADOR TEM ACESSO COMO CUIDADOR TAMBÉM
              isPessoaTea: true, // ADMINISTRADOR TEM ACESSO COMO PESSOA COM TEA TAMBÉM
              isProfissional: true, // ADMINISTRADOR TEM ACESSO COMO PROFISSIONAL TAMBÉM
              userArgs: userArgs,
              onSelectTab: (index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
            ),
            // DIÁRIO - ADMINISTRADOR TEM ACESSO
            DiaryScreen(perfil: userRole),
            // ROTINA - ADMINISTRADOR TEM ACESSO
            RoutineListScreen(
              key: ValueKey('routine_${userArgs?['id']}'),
              userArgs: userArgs,
              isProfissional: true, // ADMINISTRADOR TEM ACESSO COMO PROFISSIONAL
              onRequestBack: () {
                setState(() {
                  _selectedIndex = 0;
                });
              },
              onEnsureRoutineTab: () {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    setState(() {
                      _selectedIndex = 2;
                    });
                  }
                });
              },
            ),
            // RELATÓRIOS - ADMINISTRADOR TEM ACESSO
            ReportsScreen(
              key: ValueKey('reports_${userArgs?['id']}'),
              userArgs: userArgs,
              isProfissional: true, // ADMINISTRADOR TEM ACESSO COMO PROFISSIONAL
            ),
          ]
        : _isProfissional
            ? [
                // PROFISSIONAL: INÍCIO, ROTINA, RELATÓRIO (SEM DIÁRIO)
                _HomeTab(
                  header: _buildHeader(),
                  isResponsavel: _isResponsavel,
                  isPessoaTea: _isPessoaTea,
                  isProfissional: _isProfissional,
                  userArgs: userArgs,
                  onSelectTab: (index) {
                    setState(() {
                      _selectedIndex = index;
                    });
                  },
                ),
                // ROTINA - PARA PROFISSIONAL
                RoutineListScreen(
                  key: ValueKey('routine_${userArgs?['id']}'),
                  userArgs: userArgs,
                  isProfissional: _isProfissional,
                  onRequestBack: () {
                    setState(() {
                      _selectedIndex = 0;
                    });
                  },
                  onEnsureRoutineTab: () {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        setState(() {
                          _selectedIndex = 1;
                        });
                      }
                    });
                  },
                ),
                // RELATÓRIOS - PARA PROFISSIONAL
                ReportsScreen(
                  key: ValueKey('reports_${userArgs?['id']}'),
                  userArgs: userArgs,
                  isProfissional: _isProfissional,
                ),
              ]
            : [
                // PESSOA COM TEA / CUIDADOR: INÍCIO, DIÁRIO, ROTINA, RELATÓRIO
                _HomeTab(
                  header: _buildHeader(),
                  isResponsavel: _isResponsavel,
                  isPessoaTea: _isPessoaTea,
                  isProfissional: _isProfissional,
                  userArgs: userArgs,
                  onSelectTab: (index) {
                    setState(() {
                      _selectedIndex = index;
                    });
                  },
                ),
                // DIÁRIO - APENAS PARA PESSOA COM TEA E CUIDADOR
                (_isPessoaTea || _isResponsavel)
                    ? DiaryScreen(perfil: userRole)
                    : const _PlaceholderTab(
                        title: 'Diário',
                        description: 'Diário disponível apenas para Pessoa com TEA e Cuidadores.',
                      ),
                // ROTINA - PARA PESSOA COM TEA, CUIDADOR
                (_isPessoaTea || _isResponsavel)
                    ? RoutineListScreen(
                        key: ValueKey('routine_${userArgs?['id']}'),
                        userArgs: userArgs,
                        isProfissional: _isProfissional,
                        onRequestBack: () {
                          setState(() {
                            _selectedIndex = 0;
                          });
                        },
                        onEnsureRoutineTab: () {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) {
                              setState(() {
                                _selectedIndex = 2;
                              });
                            }
                          });
                        },
                      )
                    : const _PlaceholderTab(
                        title: 'Rotina',
                        description: 'Em breve você poderá configurar suas rotinas aqui.',
                      ),
                // RELATÓRIOS - PARA PESSOA COM TEA, CUIDADOR
                (_isPessoaTea || _isResponsavel)
                    ? ReportsScreen(
                        key: ValueKey('reports_${userArgs?['id']}'),
                        userArgs: userArgs,
                        isProfissional: _isProfissional,
                      )
                    : const _PlaceholderTab(
                        title: 'Relatórios',
                        description: 'Os relatórios ficarão disponíveis em breve.',
                      ),
              ];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: IndexedStack(
        index: _selectedIndex,
        children: pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: (_isAdministrador || !_isProfissional)
            ? (_selectedIndex > 3 ? 3 : _selectedIndex) 
            : (_selectedIndex > 2 ? 2 : _selectedIndex),
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        selectedItemColor: const Color(0xFF5C6EF8),
        unselectedItemColor: const Color(0xFFB0B4C1),
        showUnselectedLabels: true,
        items: (_isAdministrador || !_isProfissional)
            ? const [
                // ADMINISTRADOR E PESSOA COM TEA/CUIDADOR: TODAS AS TELAS
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
              ]
            : const [
                // PROFISSIONAL: SEM DIÁRIO
                BottomNavigationBarItem(
                  icon: Icon(Icons.home_outlined),
                  label: 'Início',
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

  bool get _isResponsavel {
    final normalized = userRole.toLowerCase();
    return normalized.contains('cuidador') || normalized.contains('respons');
  }

  bool get _isPessoaTea {
    final normalized = userRole.toLowerCase();
    return normalized.contains('tea');
  }

  bool get _isAdministrador {
    final normalized = userRole.toLowerCase();
    return normalized.contains('administrador');
  }

  bool get _isProfissional {
    final normalized = userRole.toLowerCase();
    // PROFISSIONAL (MAS NÃO ADMINISTRADOR)
    return normalized.contains('profissional') && !_isAdministrador;
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bem-vindo, $userName!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            userRole,
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).textTheme.bodyMedium?.color ?? 
                     (Theme.of(context).brightness == Brightness.dark 
                      ? const Color(0xFFB0B4C1) 
                      : const Color(0xFF9CA3AF)),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab({
    required this.header,
    required this.isResponsavel,
    required this.isPessoaTea,
    required this.isProfissional,
    required this.userArgs,
    required this.onSelectTab,
  });

  final Widget header;
  final bool isResponsavel;
  final bool isPessoaTea;
  final bool isProfissional;
  final Map<String, dynamic>? userArgs;
  final ValueChanged<int> onSelectTab;

  void _showRequestAccessDialog(BuildContext context, Map<String, dynamic>? userArgs) {
    final emailController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Solicitar Acesso'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Digite o email do cuidador ou pessoa com TEA para solicitar acesso aos relatórios e rotinas:',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor, insira o email';
                      }
                      if (!value.contains('@')) {
                        return 'Por favor, insira um email válido';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading
                  ? null
                  : () {
                      Navigator.of(dialogContext).pop();
                    },
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      final formState = formKey.currentState;
                      if (formState != null && formState.validate()) {
                        setDialogState(() {
                          isLoading = true;
                        });

                        final result = await ApiService.requestShareAccess(
                          ownerEmail: emailController.text.trim(),
                        );

                        if (context.mounted) {
                          if (result['success'] == true) {
                            final emailDigitado = emailController.text.trim();
                            Navigator.of(dialogContext).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Solicitação enviada com sucesso! Uma notificação foi enviada para $emailDigitado.',
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } else {
                            setDialogState(() {
                              isLoading = false;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  result['message'] ??
                                      'Erro ao solicitar acesso',
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Solicitar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            header,
            const SizedBox(height: 24),
            Text(
              'Acesso rápido',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.titleLarge?.color ?? 
                       (Theme.of(context).brightness == Brightness.dark 
                        ? Colors.white 
                        : const Color(0xFF2F2F2F)),
              ),
            ),
            const SizedBox(height: 16),
            _QuickAccessCard(
              title: 'Relatórios',
              subtitle: 'Verifique seus registros',
              icon: Icons.description_outlined,
              backgroundColor: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF2A2A2A)
                  : const Color(0xFFFFF1DB),
              iconColor: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFFFFB74D)
                  : const Color(0xFFFFB74D),
              onTap: () {
                if (isPessoaTea || isResponsavel || isProfissional) {
                  // AJUSTAR ÍNDICE: PROFISSIONAL NÃO TEM DIÁRIO, ENTÃO RELATÓRIOS ESTÁ NO ÍNDICE 2
                  // ADMINISTRADOR TEM ACESSO A TODAS AS TELAS, ENTÃO USA O ÍNDICE 3 (RELATÓRIO)
                  // PROFISSIONAL USA ÍNDICE 2 (RELATÓRIO SEM DIÁRIO)
                  onSelectTab((isProfissional && !isPessoaTea && !isResponsavel) ? 2 : 3);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Relatórios disponíveis apenas para o perfil Pessoa com TEA, Cuidador ou Profissional.'),
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 12),
            // ATALHO PARA PROFISSIONAL SOLICITAR ACESSO
            if (isProfissional)
              _QuickAccessCard(
                title: 'Solicitar Acesso',
                subtitle: 'Acesse relatórios e rotinas',
                icon: Icons.person_add_outlined,
                backgroundColor: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF2A2A2A)
                    : const Color(0xFFE8F5E9),
                iconColor: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF4CAF50)
                    : const Color(0xFF4CAF50),
                onTap: () {
                  _showRequestAccessDialog(context, userArgs);
                },
              ),
            if (isProfissional) const SizedBox(height: 12),
            // PARA PROFISSIONAL E ADMINISTRADOR, MOSTRAR ROTINA; PARA OUTROS, MOSTRAR VOZ
            if (isProfissional)
              _QuickAccessCard(
                title: 'Rotina',
                subtitle: 'Visualize suas rotinas',
                icon: Icons.access_time_outlined,
                backgroundColor: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF2A2A2A)
                    : const Color(0xFFE1F7F1),
                iconColor: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF26C6DA)
                    : const Color(0xFF26C6DA),
                onTap: () {
                  // ADMINISTRADOR TEM DIÁRIO (ÍNDICE 1), ENTÃO ROTINA ESTÁ NO ÍNDICE 2
                  // PROFISSIONAL NÃO TEM DIÁRIO, ENTÃO ROTINA ESTÁ NO ÍNDICE 1
                  // SE TEM ACESSO A DIÁRIO (isPessoaTea OU isResponsavel), ROTINA ESTÁ NO ÍNDICE 2
                  final rotinaIndex = (isPessoaTea || isResponsavel) ? 2 : 1;
                  onSelectTab(rotinaIndex);
                },
              )
            else
              _QuickAccessCard(
                title: 'Voz',
                subtitle: 'Cartões de Voz Interativos',
                icon: Icons.mic_none_outlined,
                backgroundColor: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF2A2A2A)
                    : const Color(0xFFE1F7F1),
                iconColor: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF26C6DA)
                    : const Color(0xFF26C6DA),
                onTap: () {
                  Navigator.of(context).pushNamed('/voice-cards');
                },
              ),
            const SizedBox(height: 12),
            _QuickAccessCard(
              title: 'Perfil',
              subtitle: 'Verifique suas Informações',
              icon: Icons.person_outline,
              backgroundColor: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF2A2A2A)
                  : const Color(0xFFE5E9FF),
              iconColor: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF5C6EF8)
                  : const Color(0xFF5C6EF8),
              onTap: () {
                Navigator.of(context).pushNamed(
                  '/profile',
                  arguments: userArgs,
                );
              },
            ),
            if (!isResponsavel && !isProfissional) ...[
              const SizedBox(height: 32),
              Text(
                'Botão da Calma Rápida',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.titleLarge?.color ?? 
                         (Theme.of(context).brightness == Brightness.dark 
                          ? Colors.white 
                          : const Color(0xFF2F2F2F)),
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () {
                  if (isPessoaTea && userArgs != null) {
                    final userId = userArgs!['id'] as int?;
                    final userName = userArgs!['nomeCompleto'] as String? ?? 'Usuário';
                    if (userId != null) {
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (context) => CalmModal(
                          userName: userName,
                          userId: userId,
                        ),
                      );
                    }
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF5A5F), Color(0xFFFF2D55)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.redAccent.withOpacity(0.25),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Preciso de calma agora! ',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Icon(Icons.spa, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _QuickAccessCard extends StatelessWidget {
  const _QuickAccessCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.backgroundColor,
    required this.iconColor,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF1A1A1A)
                    : Theme.of(context).colorScheme.surface,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.titleLarge?.color ?? 
                             (Theme.of(context).brightness == Brightness.dark 
                              ? Colors.white 
                              : const Color(0xFF2F2F2F)),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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
          ],
        ),
      ),
    );
  }
}

class _PlaceholderTab extends StatelessWidget {
  const _PlaceholderTab({
    required this.title,
    required this.description,
  });

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF5F7FB),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.construction,
                size: 48,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2F2F2F),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

