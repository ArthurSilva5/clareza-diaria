import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  final Function(bool)? onThemeChanged;
  
  const ProfileScreen({super.key, this.onThemeChanged});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  List<Map<String, dynamic>> _careLinks = [];
  bool _careLinksLoaded = false;
  bool _isLoadingCareLinks = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_careLinksLoaded) {
      _careLinksLoaded = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadCareLinks();
      });
    }
  }

  Future<void> _loadCareLinks() async {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final userRole = args?['perfil'] as String? ?? '';
    
    if (userRole.toLowerCase().contains('cuidador')) {
      setState(() {
        _isLoadingCareLinks = true;
      });
      
      final result = await ApiService.listCareLinks();
      if (!mounted) return;
      
      setState(() {
        _isLoadingCareLinks = false;
        if (result['success'] == true && result['data'] is List) {
          _careLinks = List<Map<String, dynamic>>.from(
            (result['data'] as List).whereType<Map<String, dynamic>>(),
          ).toList();
        }
      });
    }
  }

  Map<String, dynamic>? get _acceptedLink {
    try {
      return _careLinks.firstWhere((link) => link['status'] == 'accepted');
    } catch (e) {
      return null;
    }
  }

  Map<String, dynamic>? get _pendingLink {
    try {
      return _careLinks.firstWhere((link) => link['status'] == 'pending');
    } catch (e) {
      return null;
    }
  }

  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final darkMode = prefs.getBool('dark_mode') ?? false;
    if (widget.onThemeChanged != null) {
      widget.onThemeChanged!(darkMode);
    }
  }

  void _showRemoveCareLinkDialog(BuildContext context, Map<String, dynamic> link) {
    final pessoaTeaNome = link['pessoa_tea_nome'] as String? ?? 'Pessoa com TEA';
    final careLinkIdRaw = link['id'];
    final careLinkId = careLinkIdRaw is int 
        ? careLinkIdRaw 
        : (careLinkIdRaw is num ? careLinkIdRaw.toInt() : null);
    
    if (careLinkId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erro: ID do vínculo inválido.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remover Vínculo'),
        content: Text(
          'Tem certeza que deseja remover o vínculo com $pessoaTeaNome? Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              
              final result = await ApiService.deleteCareLink(careLinkId: careLinkId);
              
              if (context.mounted) {
                if (result['success'] == true) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Vínculo removido com sucesso.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  // RECARREGAR VÍNCULOS
                  await _loadCareLinks();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(result['message']?.toString() ?? 'Erro ao remover vínculo.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE74C3C),
              foregroundColor: Colors.white,
            ),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
  }

  void _showCareLinkDialog(BuildContext context, Map<String, dynamic>? args) {
    final emailController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Vínculo de Cuidado'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Digite o email cadastrado da Pessoa com TEA que você deseja vincular:',
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

                        final result = await ApiService.requestCareLink(
                          pessoaTeaEmail: emailController.text.trim(),
                        );

                        if (context.mounted) {
                          if (result['success'] == true) {
                            final emailDigitado = emailController.text.trim();
                            Navigator.of(dialogContext).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Solicitação enviada com sucesso! A pessoa com o email $emailDigitado receberá uma notificação no aplicativo.',
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                            // RECARREGAR VÍNCULOS APÓS ENVIAR SOLICITAÇÃO
                            await _loadCareLinks();
                          } else {
                            setDialogState(() {
                              isLoading = false;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  result['message'] ?? 'Erro ao enviar solicitação',
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
                  : const Text('Enviar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showListPatientsDialog(BuildContext context, Map<String, dynamic>? args) async {
    // CARREGAR SHARES (PACIENTES VINCULADOS)
    final result = await ApiService.listShares();
    if (!mounted) return;

    List<Map<String, dynamic>> patients = [];
    if (result['success'] == true && result['data'] is List) {
      patients = List<Map<String, dynamic>>.from(
        (result['data'] as List).whereType<Map<String, dynamic>>(),
      );
    }

    // CARREGAR PACIENTE SELECIONADO ATUAL
    final prefs = await SharedPreferences.getInstance();
    final selectedPatientId = prefs.getInt('selected_patient_id');

    // CRIAR UMA CÓPIA PARA EDIÇÃO
    int? tempSelectedId = selectedPatientId;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Selecionar Paciente'),
          content: SizedBox(
            width: double.maxFinite,
            child: patients.isEmpty
                ? const Text('Nenhum paciente vinculado ainda.')
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: patients.length,
                    itemBuilder: (context, index) {
                      final patient = patients[index];
                      final patientId = patient['owner_id'] as int?;
                      final patientName = patient['owner_nome'] as String? ?? 'Sem nome';
                      final isSelected = tempSelectedId == patientId;

                      return CheckboxListTile(
                        title: Text(patientName),
                        value: isSelected,
                        tileColor: Colors.white,
                        selectedTileColor: Colors.white,
                        activeColor: Theme.of(context).colorScheme.primary,
                        onChanged: (bool? value) {
                          setDialogState(() {
                            // SE DESMARCAR, LIMPAR SELEÇÃO
                            if (value == false) {
                              tempSelectedId = null;
                            } else {
                              // SE MARCAR, DESMARCAR OS OUTROS E MARCAR ESTE
                              tempSelectedId = patientId;
                            }
                          });
                        },
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                // SALVAR SELEÇÃO
                final prefs = await SharedPreferences.getInstance();
                if (tempSelectedId != null) {
                  await prefs.setInt('selected_patient_id', tempSelectedId!);
                } else {
                  await prefs.remove('selected_patient_id');
                }
                
                if (mounted) {
                  Navigator.of(dialogContext).pop();
                  
                  // BUSCAR NOME DO PACIENTE SELECIONADO PARA A NOTIFICAÇÃO
                  String? pacienteNome = 'Paciente';
                  if (tempSelectedId != null) {
                    for (final patient in patients) {
                      final patientId = patient['owner_id'] as int?;
                      if (patientId == tempSelectedId) {
                        pacienteNome = patient['owner_nome'] as String? ?? 'Paciente';
                        break;
                      }
                    }
                  }
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        tempSelectedId != null
                            ? '$pacienteNome foi selecionado(a) com sucesso!'
                            : 'Nenhum paciente selecionado.',
                      ),
                      backgroundColor: Colors.green,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                  
                  // NÃO NAVEGAR - APENAS FECHAR A MODAL E PERMANECER NA TELA DE PERFIL
                  // AS ROTINAS E RELATÓRIOS SERÃO RECARREGADAS AUTOMATICAMENTE QUANDO ACESSADAS
                }
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }

  void _showChangePasswordDialog() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;
    bool obscureCurrentPassword = true;
    bool obscureNewPassword = true;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Alterar Senha'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: currentPasswordController,
                    obscureText: obscureCurrentPassword,
                    decoration: InputDecoration(
                      labelText: 'Senha Atual',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureCurrentPassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () {
                          setDialogState(() {
                            obscureCurrentPassword = !obscureCurrentPassword;
                          });
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor, insira sua senha atual';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: newPasswordController,
                    obscureText: obscureNewPassword,
                    decoration: InputDecoration(
                      labelText: 'Nova Senha',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureNewPassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () {
                          setDialogState(() {
                            obscureNewPassword = !obscureNewPassword;
                          });
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor, insira a nova senha';
                      }
                      if (value.length < 6) {
                        return 'A senha deve ter pelo menos 6 caracteres';
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

                        final result = await ApiService.changePassword(
                          currentPassword: currentPasswordController.text,
                          newPassword: newPasswordController.text,
                        );

                        if (context.mounted) {
                          if (result['success'] == true) {
                            // LIMPAR TOKENS
                            ApiService.clearTokens();
                            // FECHAR MODAL
                            Navigator.of(dialogContext).pop();
                            // NAVEGAR PARA LOGIN
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(
                                builder: (context) => const LoginScreen(),
                              ),
                              (route) => false,
                            );
                            // MOSTRAR MENSAGEM DE SUCESSO
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Senha alterada com sucesso! Faça login novamente.',
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
                                  result['message'] ?? 'Erro ao alterar senha',
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
                  : const Text('Alterar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final userName = args != null && args['nomeCompleto'] != null
        ? args['nomeCompleto'] as String
        : 'Usuário';
    final userRole = args != null && args['perfil'] != null
        ? args['perfil'] as String
        : (args != null && args['role'] != null
            ? args['role'] as String
            : 'Perfil não informado');

    // OBTER PRIMEIRA LETRA DO NOME PARA O AVATAR
    final initial = userName.isNotEmpty ? userName[0].toUpperCase() : 'U';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // HEADER
              Text(
                'Perfil',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Gerencie sua conta e preferências',
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).textTheme.bodyMedium?.color ?? 
                         (Theme.of(context).brightness == Brightness.dark 
                          ? const Color(0xFFB0B4C1) 
                          : const Color(0xFF6B7280)),
                ),
              ),
              const SizedBox(height: 24),

              // User Info Card
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
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: const Color(0xFF5C6EF8),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          initial,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userName,
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
                            'Perfil: $userRole',
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
              const SizedBox(height: 32),

              // CONFIGURAÇÕES SECTION
              Text(
                'Configurações',
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

              _SettingsCard(
                icon: Icons.settings_outlined,
                iconColor: const Color(0xFF9C27B0),
                title: 'Preferências',
                subtitle: 'Notificações e sensibilidades',
                onTap: () {
                  final args =
                      ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
                  Navigator.of(context).pushNamed(
                    '/preferences',
                    arguments: args,
                  ).then((_) {
                    // RECARREGAR TEMA QUANDO VOLTAR DAS PREFERÊNCIAS
                    if (widget.onThemeChanged != null) {
                      _loadThemePreference();
                    }
                  });
                },
              ),
              const SizedBox(height: 12),
              _SettingsCard(
                icon: Icons.notifications_outlined,
                iconColor: const Color(0xFF4CAF50),
                title: 'Notificações',
                subtitle: 'Gerenciar alertas e lembretes',
                onTap: () {
                  final args =
                      ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
                  Navigator.of(context).pushNamed(
                    '/notifications',
                    arguments: args,
                  );
                },
              ),
              const SizedBox(height: 12),
              _SettingsCard(
                icon: Icons.lock_outline,
                iconColor: const Color(0xFFFF9800),
                title: 'Alterar Senha',
                subtitle: 'Atualize sua senha',
                onTap: _showChangePasswordDialog,
              ),
              // MOSTRAR "LISTAR PACIENTES" APENAS PARA PROFISSIONAL
              if (userRole.toLowerCase().contains('profissional')) ...[
                const SizedBox(height: 12),
                _SettingsCard(
                  icon: Icons.people_outline,
                  iconColor: const Color(0xFF2196F3),
                  title: 'Listar Pacientes',
                  subtitle: 'Selecione qual paciente visualizar',
                  onTap: () => _showListPatientsDialog(context, args),
                ),
              ],
              // MOSTRAR "VÍNCULO DE CUIDADO", "SOLICITAÇÃO PENDENTE" OU "REMOVER VÍNCULO" APENAS PARA CUIDADOR
              if (userRole.toLowerCase().contains('cuidador')) ...[
                const SizedBox(height: 12),
                if (_isLoadingCareLinks)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_acceptedLink != null)
                  _SettingsCard(
                    icon: Icons.person_remove_outlined,
                    iconColor: const Color(0xFFE74C3C),
                    title: 'Remover Vínculo',
                    subtitle: 'Remover vínculo com ${_acceptedLink!['pessoa_tea_nome'] ?? 'Pessoa com TEA'}',
                    onTap: () => _showRemoveCareLinkDialog(context, _acceptedLink!),
                  )
                else if (_pendingLink != null)
                  _SettingsCard(
                    icon: Icons.pending_outlined,
                    iconColor: const Color(0xFFFF9800),
                    title: 'Solicitação de Vínculo Pendente',
                    subtitle: 'Aguardando resposta de ${_pendingLink!['pessoa_tea_nome'] ?? 'Pessoa com TEA'}',
                    onTap: null, // Não clicável quando pendente
                  )
                else
                  _SettingsCard(
                    icon: Icons.person_add_outlined,
                    iconColor: const Color(0xFF2196F3),
                    title: 'Vínculo de Cuidado',
                    subtitle: 'Vincule uma pessoa sob sua responsabilidade',
                    onTap: () => _showCareLinkDialog(context, args),
                  ),
              ],
              const SizedBox(height: 32),

              // SOBRE SECTION
              Text(
                'Sobre',
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Clareza Diária - Versão 1.0',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).textTheme.titleLarge?.color ?? 
                               (Theme.of(context).brightness == Brightness.dark 
                                ? Colors.white 
                                : const Color(0xFF2F2F2F)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Um aplicativo de apoio ao autocontrole e rotina para pessoas autistas.',
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
              const SizedBox(height: 32),

              // LOGOUT BUTTON
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    // LIMPAR TOKENS
                    ApiService.clearTokens();
                    // NAVEGAR PARA LOGIN
                    if (context.mounted) {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (context) => const LoginScreen()),
                        (route) => false,
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE74C3C),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.exit_to_app, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Sair',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(context, args),
    );
  }

  Widget _buildBottomNavigationBar(BuildContext context, Map<String, dynamic>? args) {
    final userRole = args?['perfil'] as String? ?? '';
    // ADMINISTRADOR TEM ACESSO A TODAS AS FUNCIONALIDADES DE PROFISSIONAL
    final isProfissional = userRole.toLowerCase().contains('profissional') || 
                          userRole.toLowerCase().contains('administrador');

    return BottomNavigationBar(
      currentIndex: 0, // PERFIL NÃO ESTÁ NA NAVEGAÇÃO, MAS MANTÉM O ÍNDICE 0
      onTap: (index) {
        // PARA PROFISSIONAL, OS ÍNDICES SÃO: 0=INÍCIO, 1=ROTINA, 2=RELATÓRIO
        // PARA NÃO-PROFISSIONAL, OS ÍNDICES SÃO: 0=INÍCIO, 1=DIÁRIO, 2=ROTINA, 3=RELATÓRIO
        int adjustedIndex = index;
        if (isProfissional) {
          // PROFISSIONAL: 0=INÍCIO, 1=ROTINA, 2=RELATÓRIO
          adjustedIndex = index; // JÁ ESTÁ CORRETO
        } else {
          // NÃO-PROFISSIONAL: 0=INÍCIO, 1=DIÁRIO, 2=ROTINA, 3=RELATÓRIO
          adjustedIndex = index; // JÁ ESTÁ CORRETO
        }
        
        // NAVEGAR DE VOLTA PARA A HOME COM O ÍNDICE SELECIONADO
        Navigator.of(context).pushReplacementNamed(
          '/home',
          arguments: {
            ...?args,
            'selectedIndex': adjustedIndex,
          },
        );
      },
      selectedItemColor: const Color(0xFF5C6EF8),
      unselectedItemColor: const Color(0xFFB0B4C1),
      showUnselectedLabels: true,
      items: isProfissional
          ? const [
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
            ]
          : const [
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
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    Widget cardContent = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
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
                  subtitle,
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
          if (onTap != null)
            Icon(
              Icons.chevron_right,
              color: Theme.of(context).brightness == Brightness.dark 
                  ? const Color(0xFF9CA3AF) 
                  : const Color(0xFF9CA3AF),
            ),
        ],
      ),
    );
    
    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: cardContent,
      );
    } else {
      return cardContent;
    }
  }
}

