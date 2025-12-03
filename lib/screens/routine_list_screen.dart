import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/routine.dart';
import '../services/api_service.dart';
import 'routine_detail_screen.dart';

class RoutineListScreen extends StatefulWidget {
  const RoutineListScreen({super.key, this.onRequestBack, this.onEnsureRoutineTab, this.userArgs, this.isProfissional = false});

  final VoidCallback? onRequestBack;
  final VoidCallback? onEnsureRoutineTab;
  final Map<String, dynamic>? userArgs;
  final bool isProfissional;

  @override
  State<RoutineListScreen> createState() => _RoutineListScreenState();
}

class _RoutineListScreenState extends State<RoutineListScreen> {
  bool _loading = true;
  String? _error;
  List<RoutineModel> _routines = [];
  List<Map<String, dynamic>> _shares = [];
  int? _selectedPatientId; // PARA PROFISSIONAIS

  bool get _isAdministrador {
    final perfil = widget.userArgs?['perfil'] as String?;
    return perfil != null && perfil.toLowerCase().contains('administrador');
  }

  @override
  void initState() {
    super.initState();
    // ADMINISTRADOR CARREGA ROTINAS DIRETAMENTE, SEM PRECISAR DE VÍNCULOS
    if (_isAdministrador) {
      _loadRoutines();
    } else if (widget.isProfissional) {
      _loadShares();
    } else {
      _loadRoutines();
    }
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // RECARREGAR ROTINAS QUANDO O PACIENTE SELECIONADO MUDAR (PARA PROFISSIONAIS)
    if (widget.isProfissional && !_isAdministrador && _shares.isNotEmpty) {
      _checkAndReloadRoutines();
    }
  }
  
  Future<void> _checkAndReloadRoutines() async {
    final prefs = await SharedPreferences.getInstance();
    final selectedPatientId = prefs.getInt('selected_patient_id');
    
    // SE O PACIENTE SELECIONADO MUDOU, RECARREGAR ROTINAS
    if (_selectedPatientId != selectedPatientId) {
      await _loadRoutines();
    }
  }

  Future<void> _loadShares() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await ApiService.listShares();
    if (!mounted) return;

    if (result['success'] == true && result['data'] is List) {
      final List data = result['data'] as List;
      setState(() {
        _shares = data.whereType<Map<String, dynamic>>().toList();
      });
      
      if (_shares.isEmpty) {
        setState(() {
          _loading = false;
          _error = null; // NÃO É ERRO, APENAS SEM VÍNCULO
        });
      } else {
        // VERIFICAR SE HÁ PACIENTE SELECIONADO ANTES DE CARREGAR ROTINAS
        final prefs = await SharedPreferences.getInstance();
        final selectedPatientId = prefs.getInt('selected_patient_id');
        
        if (selectedPatientId == null) {
          // SEM PACIENTE SELECIONADO, NÃO CARREGAR ROTINAS
          setState(() {
            _routines = [];
            _loading = false;
            _error = null;
          });
        } else {
          await _loadRoutines();
        }
      }
    } else {
      setState(() {
        _loading = false;
        _error = result['message']?.toString() ?? 'Não foi possível carregar os compartilhamentos.';
      });
    }
  }

  Future<void> _loadRoutines() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await ApiService.listRoutines();
    if (!mounted) return;

    if (result['success'] == true && result['data'] is List) {
      final List data = result['data'] as List;
      List<RoutineModel> allRoutines = data
          .whereType<Map<String, dynamic>>()
          .map(RoutineModel.fromJson)
          .toList();
      
      // ADMINISTRADOR VÊ TODAS AS ROTINAS SEM FILTRO
      if (widget.isProfissional && !_isAdministrador) {
        final prefs = await SharedPreferences.getInstance();
        final selectedPatientId = prefs.getInt('selected_patient_id');
        _selectedPatientId = selectedPatientId;
        
        // SE NÃO HOUVER PACIENTE SELECIONADO, NÃO MOSTRAR NENHUMA ROTINA
        if (selectedPatientId == null) {
          setState(() {
            _routines = [];
            _loading = false;
          });
          return;
        }
        
        // IDENTIFICAR O CUIDADOR VINCULADO (SE HOUVER)
        // BUSCAR INFORMAÇÕES DO PACIENTE SELECIONADO NOS SHARES
        String? selectedPatientPerfil;
        for (final share in _shares) {
          final ownerId = share['owner_id'] as int?;
          if (ownerId != null && ownerId == selectedPatientId) {
            selectedPatientPerfil = share['owner_perfil'] as String?;
            break;
          }
        }
        
        // IDENTIFICAR O CUIDADOR VINCULADO À PESSOA COM TEA SELECIONADA
        int? cuidadorId;
        if (selectedPatientPerfil != null &&
            selectedPatientPerfil.toLowerCase().contains('tea')) {
          // PROCURAR POR UM CUIDADOR NOS SHARES QUE NÃO SEJA O SELECTEDPATIENTID
          for (final share in _shares) {
            final ownerId = share['owner_id'] as int?;
            final ownerPerfil = share['owner_perfil'] as String?;
            if (ownerId != null &&
                ownerId != selectedPatientId &&
                ownerPerfil != null &&
                ownerPerfil.toLowerCase().contains('cuidador')) {
              // VERIFICAR SE ESTE CUIDADOR TEM ROTINAS QUE APARECEM NA LISTA
              // (INDICA QUE ELE ESTÁ VINCULADO À PESSOA COM TEA)
              final hasRoutines = allRoutines.any((r) => r.userId == ownerId);
              if (hasRoutines) {
                cuidadorId = ownerId;
                break;
              }
            }
          }
        }
        
        // FILTRAR ROTINAS: MOSTRAR APENAS AS DO PACIENTE SELECIONADO E DO CUIDADOR VINCULADO (SE HOUVER)
        allRoutines = allRoutines.where((routine) {
          final routineUserId = routine.userId;
          // INCLUIR ROTINAS DO PACIENTE SELECIONADO
          if (routineUserId == selectedPatientId) {
            return true;
          }
          // INCLUIR ROTINAS DO CUIDADOR VINCULADO (SE HOUVER)
          if (cuidadorId != null && routineUserId == cuidadorId) {
            return true;
          }
          return false;
        }).toList();
      }
      
      setState(() {
        _routines = allRoutines;
        _loading = false;
      });
    } else {
      setState(() {
        _loading = false;
        _error = result['message']?.toString() ?? 'Não foi possível carregar as rotinas.';
      });
    }
  }


  Future<void> _createRoutine() async {
    final controllers = _RoutineDialogControllers();
    
    final routineData = await showDialog<_RoutineDialogData>(
      context: context,
      builder: (context) => _RoutineDialog(controllers: controllers),
    );

    if (!mounted) return;

    if (routineData == null) {
      // SE CANCELOU, GARANTIR QUE CONTINUAMOS NA ABA DE ROTINAS
      if (widget.onEnsureRoutineTab != null) {
        widget.onEnsureRoutineTab!();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && widget.onEnsureRoutineTab != null) {
            widget.onEnsureRoutineTab!();
          }
        });
      }
      return;
    }

    // CRIAR ROTINA SEM ESPECIFICAR PESSOA_TEA_ID - SERÁ CRIADA PARA O USUÁRIO ATUAL
    // O BACKEND JÁ RETORNA TODAS AS ROTINAS VINCULADAS
    final response = await ApiService.createRoutine(
      titulo: routineData.titulo,
      lembrete: routineData.horario,
    );

    if (!mounted) return;

    // GARANTIR QUE CONTINUAMOS NA ABA DE ROTINAS APÓS CRIAR A ROTINA
    if (widget.onEnsureRoutineTab != null) {
      widget.onEnsureRoutineTab!();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.onEnsureRoutineTab != null) {
          widget.onEnsureRoutineTab!();
        }
      });
    }

    if (response['success'] == true) {
      await _loadRoutines();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rotina criada com sucesso.')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message']?.toString() ?? 'Erro ao criar rotina.'),
          ),
        );
      }
    }
  }

  Future<void> _openRoutineDetail(RoutineModel routine) async {
    // GARANTIR QUE ESTAMOS NA ABA DE ROTINAS ANTES DE ABRIR
    if (widget.onEnsureRoutineTab != null) {
      widget.onEnsureRoutineTab!();
    }
    
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RoutineDetailScreen(
          initialRoutine: routine,
          isProfissional: widget.isProfissional && !_isAdministrador, // ADMINISTRADOR PODE EDITAR
        ),
      ),
    );

    if (!mounted) return;

    // APÓS VOLTAR, GARANTIR QUE ESTAMOS NA ABA DE ROTINAS
    // CHAMAR IMEDIATAMENTE E TAMBÉM NO PRÓXIMO FRAME PARA GARANTIR
    if (widget.onEnsureRoutineTab != null) {
      widget.onEnsureRoutineTab!();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.onEnsureRoutineTab != null) {
          widget.onEnsureRoutineTab!();
        }
      });
    }

    if (result == true) {
      await _loadRoutines();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 12, right: 20, top: 8, bottom: 12),
              child: Row(
                children: [
                  Text(
                    widget.isProfissional ? 'Rotinas' : 'Suas rotinas',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).textTheme.titleLarge?.color ?? 
                             (Theme.of(context).brightness == Brightness.dark 
                              ? Colors.white 
                              : const Color(0xFF1E1E1E)),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadRoutines,
                  child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? _RoutineErrorView(message: _error!, onRetry: _isAdministrador ? _loadRoutines : (widget.isProfissional ? _loadShares : _loadRoutines))
                        : (widget.isProfissional && !_isAdministrador && _shares.isEmpty)
                            ? _RoutineNoLinkView()
                            : (widget.isProfissional && !_isAdministrador && _selectedPatientId == null)
                            ? _RoutineNoPatientSelectedView()
                        : _routines.isEmpty
                            ? const _RoutineEmptyView()
                            : ListView.separated(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                itemBuilder: (context, index) {
                                  final routine = _routines[index];
                                  return _RoutineCard(
                                    routine: routine,
                                    onTap: () => _openRoutineDetail(routine),
                                    isProfissional: widget.isProfissional,
                                  );
                                },
                                separatorBuilder: (_, __) => const SizedBox(height: 12),
                                itemCount: _routines.length,
                              ),
              ),
            ),
            // ADMINISTRADOR PODE CRIAR ROTINAS
            if (!widget.isProfissional || _isAdministrador)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: ElevatedButton.icon(
                  onPressed: _createRoutine,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: const Color(0xFF1EC7A5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text(
                    'Adicionar rotina',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RoutineCard extends StatelessWidget {
  const _RoutineCard({required this.routine, required this.onTap, this.isProfissional = false});

  final RoutineModel routine;
  final VoidCallback onTap;
  final bool isProfissional;

  @override
  Widget build(BuildContext context) {
    final totalPassos = routine.totalPassos;
    final horario = routine.lembrete?.isNotEmpty == true ? routine.lembrete : null;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            routine.titulo,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context).textTheme.titleLarge?.color ?? 
                                     (Theme.of(context).brightness == Brightness.dark 
                                      ? Colors.white 
                                      : const Color(0xFF1E1E1E)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  [
                    if (horario != null) 'Horário: $horario',
                    '$totalPassos ${totalPassos == 1 ? 'atividade' : 'atividades'}',
                  ].join(' • '),
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).textTheme.bodyMedium?.color ?? 
                           (Theme.of(context).brightness == Brightness.dark 
                            ? const Color(0xFFB0B4C1) 
                            : const Color(0xFF697082)),
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1EC7A5),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text(
              'Conferir',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoutineEmptyView extends StatelessWidget {
  const _RoutineEmptyView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      children: [
        Icon(
          Icons.event_note_outlined, 
          size: 64, 
          color: Theme.of(context).textTheme.bodyMedium?.color ?? 
                 (Theme.of(context).brightness == Brightness.dark 
                  ? const Color(0xFFB0B4C1) 
                  : const Color(0xFFB0B4C1)),
        ),
        SizedBox(height: 12),
        Text(
          'Nenhuma rotina cadastrada ainda.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16, 
            fontWeight: FontWeight.w500, 
            color: Theme.of(context).textTheme.titleLarge?.color ?? 
                   (Theme.of(context).brightness == Brightness.dark 
                    ? const Color(0xFFB0B4C1) 
                    : const Color(0xFF505767)),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Toque em "Adicionar rotina" para criar sua primeira rotina.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14, 
            color: Theme.of(context).textTheme.bodyMedium?.color ?? 
                   (Theme.of(context).brightness == Brightness.dark 
                    ? const Color(0xFFB0B4C1) 
                    : const Color(0xFF7A8091)),
          ),
        ),
      ],
    );
  }
}

class _RoutineNoPatientSelectedView extends StatelessWidget {
  const _RoutineNoPatientSelectedView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_outline,
              size: 64,
              color: Theme.of(context).textTheme.bodyMedium?.color ??
                  (Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFFB0B4C1)
                      : const Color(0xFF9CA3AF)),
            ),
            const SizedBox(height: 16),
            Text(
              'Nenhum paciente selecionado',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.titleLarge?.color ??
                     (Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : const Color(0xFF1E1E1E)),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Selecione um paciente na tela de perfil para visualizar as rotinas.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).textTheme.bodyMedium?.color ??
                       (Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFFB0B4C1)
                        : const Color(0xFF6B7280)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoutineNoLinkView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.link_off_outlined,
            size: 64,
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF9CA3AF)
                : const Color(0xFF9CA3AF),
          ),
          const SizedBox(height: 16),
          Text(
            'Nenhum vínculo encontrado',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).textTheme.titleLarge?.color ??
                     (Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : const Color(0xFF1E1E1E)),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Você precisa estar vinculado a uma conta de Pessoa com TEA ou Cuidador para visualizar rotinas.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).textTheme.bodyMedium?.color ??
                       (Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFFB0B4C1)
                        : const Color(0xFF6B7280)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoutineErrorView extends StatelessWidget {
  const _RoutineErrorView({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      children: [
        const Icon(Icons.error_outline, size: 60, color: Color(0xFFEF5350)),
        const SizedBox(height: 12),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15, 
            color: Theme.of(context).textTheme.bodyMedium?.color ?? 
                   (Theme.of(context).brightness == Brightness.dark 
                    ? const Color(0xFFB0B4C1) 
                    : const Color(0xFF6B7280)),
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: onRetry,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1EC7A5),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          icon: const Icon(Icons.refresh),
          label: const Text('Tentar novamente'),
        ),
      ],
    );
  }
}

class _RoutineDialogData {
  const _RoutineDialogData({required this.titulo, required this.horario});

  final String titulo;
  final String? horario;
}

class _RoutineDialogControllers {
  final TextEditingController titulo = TextEditingController();
  final TextEditingController horario = TextEditingController();

  void dispose() {
    titulo.dispose();
    horario.dispose();
  }
}

class _RoutineDialog extends StatefulWidget {
  const _RoutineDialog({required this.controllers});

  final _RoutineDialogControllers controllers;

  @override
  State<_RoutineDialog> createState() => _RoutineDialogState();
}

class _RoutineDialogState extends State<_RoutineDialog> {
  String? _tituloError;

  @override
  void dispose() {
    widget.controllers.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text('Nova rotina'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: widget.controllers.titulo,
            decoration: InputDecoration(
              labelText: 'Título da rotina',
              border: const OutlineInputBorder(),
              errorText: _tituloError,
            ),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: widget.controllers.horario,
            decoration: const InputDecoration(
              labelText: 'Horário (ex: 07:00)',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.datetime,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9:]')),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            final titulo = widget.controllers.titulo.text.trim();
            if (titulo.isEmpty) {
              setState(() {
                _tituloError = 'Informe um título para a rotina';
              });
              return;
            }

            Navigator.of(context).pop(
              _RoutineDialogData(
                titulo: titulo,
                horario: widget.controllers.horario.text.trim().isEmpty
                    ? null
                    : widget.controllers.horario.text.trim(),
              ),
            );
          },
          child: const Text('Criar'),
        ),
      ],
    );
  }
}
