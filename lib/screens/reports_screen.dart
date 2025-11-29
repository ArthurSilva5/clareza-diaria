import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import '../services/local_storage_service.dart';

// IMPORT CONDICIONAL PARA WEB
import '../utils/web_download.dart'
    if (dart.library.io) '../utils/web_download_stub.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key, this.userArgs, this.isProfissional = false});

  final Map<String, dynamic>? userArgs;
  final bool isProfissional;

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  bool _monthly = false; // FALSE = WEEK, TRUE = MONTH
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _careLinks = [];
  List<Map<String, dynamic>> _shares = [];
  Map<String, dynamic>? _currentUser;
  int? _selectedPessoaTeaId; // NULL = PRÓPRIO RELATÓRIO
  Map<int, Map<String, dynamic>> _userInfoCache =
      {}; // CACHE DE INFORMAÇÕES DOS USUÁRIOS

  List<Map<String, dynamic>> _entries = [];
  int? _selectedPatientId; // PARA PROFISSIONAIS
  int?
  _selectedReportUserId; // PARA PROFISSIONAIS ESCOLHEREM QUAL RELATÓRIO VER (PESSOA COM TEA OU CUIDADOR)
  int?
  _linkedCuidadorId; // ID DO CUIDADOR VINCULADO AO PACIENTE SELECIONADO (PARA PROFISSIONAIS)

  // MAPS LABEL -> EMOJI (DEVE COINCIDIR COM DIARYSCREEN OPTIONS)
  static const Map<String, String> moodEmoji = {
    'Muito feliz': '😀',
    'Feliz': '😊',
    'Neutro': '😐',
    'Triste': '😔',
    'Muito triste': '😭',
    // TAGS DO CUIDADOR
    'Calmo': '😌',
    'Irritado': '😠',
  };
  static const Map<String, String> sleepEmoji = {
    'Excelente': '😴',
    'Bom': '🙂',
    'Regular': '😌',
    'Ruim': '😟',
    'Péssimo': '😫',
    // TAGS DO CUIDADOR
    'Dormiu bem': '😴',
    'Agitado': '😟',
    'Pouco': '😌',
  };

  @override
  void initState() {
    super.initState();
    _currentUser =
        widget.userArgs ??
        (ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?);
    // ADMINISTRADOR CARREGA RELATÓRIOS DIRETAMENTE, SEM PRECISAR DE VÍNCULOS
    if (_isAdministrador) {
      _load();
    } else if (widget.isProfissional) {
      _loadShares();
    } else {
      // PARA CUIDADOR, AGUARDAR CARREGAR VÍNCULOS ANTES DE CARREGAR RELATÓRIOS
      _loadCareLinks().then((_) => _load());
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
        // VERIFICAR SE HÁ PACIENTE SELECIONADO ANTES DE CARREGAR RELATÓRIOS
        final prefs = await SharedPreferences.getInstance();
        final selectedPatientId = prefs.getInt('selected_patient_id');

        if (selectedPatientId == null) {
          // SEM PACIENTE SELECIONADO, NÃO CARREGAR DADOS
          setState(() {
            _entries = [];
            _loading = false;
            _error = null;
          });
        } else {
          await _load();
        }
      }
    } else {
      setState(() {
        _loading = false;
        _error =
            result['message']?.toString() ??
            'Não foi possível carregar os compartilhamentos.';
      });
    }
  }

  @override
  void didUpdateWidget(ReportsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // RECARREGAR APENAS SE OS USERARGS MUDARAM
    if (oldWidget.userArgs != widget.userArgs) {
      _currentUser =
          widget.userArgs ??
          (ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?);
      _loadCareLinks();
      _load();
    }
  }

  bool get _isCuidador {
    final perfil = _currentUser?['perfil'] as String?;
    return perfil != null && perfil.toLowerCase().contains('cuidador');
  }

  bool get _isPessoaTea {
    final perfil = _currentUser?['perfil'] as String?;
    return perfil != null && perfil.toLowerCase().contains('tea');
  }

  bool get _isAdministrador {
    final perfil = _currentUser?['perfil'] as String?;
    return perfil != null && perfil.toLowerCase().contains('administrador');
  }

  String _getOwnerNames() {
    // ADMINISTRADOR SEMPRE VÊ "ANÁLISE DE REGISTROS"
    if (_isAdministrador || !widget.isProfissional || _shares.isEmpty) {
      return 'Análise de Registros';
    }

    final names = <String>[];
    for (final share in _shares) {
      final ownerName = share['owner_nome'] as String?;
      if (ownerName != null && ownerName.isNotEmpty) {
        names.add(ownerName);
      }
    }

    if (names.isEmpty) {
      return 'Análise de Registros';
    }

    // REMOVER DUPLICATAS
    final uniqueNames = names.toSet().toList();

    if (uniqueNames.length == 1) {
      return 'Relatórios de ${uniqueNames[0]}';
    } else if (uniqueNames.length == 2) {
      return 'Relatórios de ${uniqueNames[0]} e ${uniqueNames[1]}';
    } else {
      return 'Relatórios de ${uniqueNames.take(2).join(', ')} e mais ${uniqueNames.length - 2}';
    }
  }

  void _showInviteProfessionalDialog(BuildContext context) {
    final emailController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Convidar Profissional'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Digite o email cadastrado do profissional que você deseja convidar:',
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

                        final result = await ApiService.createShare(
                          viewerEmail: emailController.text.trim(),
                        );

                        if (context.mounted) {
                          if (result['success'] == true) {
                            final emailDigitado = emailController.text.trim();
                            Navigator.of(dialogContext).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Profissional convidado com sucesso! O profissional com o email $emailDigitado terá acesso aos seus relatórios e rotinas.',
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
                                      'Erro ao convidar profissional',
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
                  : const Text('Convidar'),
            ),
          ],
        ),
      ),
    );
  }

  /// MESCLAR ENTRIES LOCAIS COM ENTRIES DA API, EVITANDO DUPLICATAS
  List<Map<String, dynamic>> _mergeEntries(
    List<Map<String, dynamic>> localEntries,
    List<Map<String, dynamic>> apiEntries,
  ) {
    // CRIAR UM MAPA DE ENTRIES DA API POR ID PARA VERIFICAÇÃO RÁPIDA
    final apiEntriesMap = <String, Map<String, dynamic>>{};
    for (final entry in apiEntries) {
      final id = entry['id']?.toString();
      if (id != null) {
        apiEntriesMap[id] = entry;
      }
    }

    // ADICIONAR ENTRIES LOCAIS QUE NÃO ESTÃO NA API (AINDA NÃO SINCRONIZADOS)
    final merged = List<Map<String, dynamic>>.from(apiEntries);
    for (final localEntry in localEntries) {
      final localId = localEntry['id']?.toString();
      // SE O ENTRY LOCAL NÃO ESTÁ NA API, ADICIONAR
      if (localId != null && !apiEntriesMap.containsKey(localId)) {
        merged.add(localEntry);
      }
    }

    return merged;
  }

  Future<void> _loadCareLinks() async {
    if (!_isCuidador) return;

    final result = await ApiService.listCareLinks();
    if (!mounted) return;

    if (result['success'] == true && result['data'] is List) {
      setState(() {
        _careLinks = List<Map<String, dynamic>>.from(
          (result['data'] as List).whereType<Map<String, dynamic>>(),
        ).where((link) => link['status'] == 'accepted').toList();
      });
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final now = DateTime.now();
    final from = _monthly
        ? now.subtract(const Duration(days: 30))
        : now.subtract(const Duration(days: 6));

    // OBTER ID DO USUÁRIO ATUAL
    final currentUserId = _currentUser?['id'] as int?;
    if (currentUserId == null) {
      setState(() {
        _loading = false;
        _error = 'Usuário não identificado.';
      });
      return;
    }

    // 1. BUSCAR ENTRIES LOCAIS PRIMEIRO (RÁPIDO)
    // FILTRAR APENAS ENTRIES DO USUÁRIO ATUAL PARA EVITAR MISTURAR DADOS DE OUTRAS CONTAS
    final localEntries = LocalStorageService.getLocalEntries();
    final localEntriesMap = localEntries
        .where((e) => 
            e.userId == currentUserId && // APENAS ENTRIES DO USUÁRIO ATUAL
            e.timestamp.isAfter(from) && 
            e.timestamp.isBefore(now.add(const Duration(days: 1))))
        .map((e) => {
              'id': e.id,
              'tipo': e.tipo,
              'texto': e.texto,
              'tags': e.tags,
              'timestamp': e.timestamp.toIso8601String(),
              'user_id': e.userId,
              'is_local': true, // MARCA COMO LOCAL
            })
        .toList();

    // SE FOR CUIDADOR E SELECIONOU UMA PESSOA COM TEA, BUSCAR ENTRIES DA PESSOA COM TEA
    if (_isCuidador && _selectedPessoaTeaId != null) {
      // BUSCAR ENTRIES DA PESSOA COM TEA VINCULADA
      final entriesResult = await ApiService.listEntries(
        tipo: 'diario',
        from: from,
        to: now,
        pessoaTeaId: _selectedPessoaTeaId,
      );

      if (!mounted) return;

      if (entriesResult['success'] == true && entriesResult['data'] is List) {
        final apiEntries = List<Map<String, dynamic>>.from(
          (entriesResult['data'] as List).whereType<Map<String, dynamic>>(),
        );
        final merged = _mergeEntries(localEntriesMap, apiEntries);
        setState(() {
          _entries = merged;
          _loading = false;
        });
      } else {
        setState(() {
          _loading = false;
          _error =
              entriesResult['message']?.toString() ??
              'Não foi possível carregar os registros.';
        });
      }
    } else if (widget.isProfissional) {
      // PROFISSIONAL - PRECISA TER PACIENTE SELECIONADO
      final prefs = await SharedPreferences.getInstance();
      final selectedPatientId = prefs.getInt('selected_patient_id');

      // SE O PACIENTE SELECIONADO MUDOU, RESETAR O CUIDADOR VINCULADO E O RELATÓRIO SELECIONADO
      if (_selectedPatientId != selectedPatientId) {
        _linkedCuidadorId = null;
        _selectedReportUserId = selectedPatientId;
      }

      _selectedPatientId = selectedPatientId;

      // SE NÃO HOUVER SELEÇÃO DE RELATÓRIO ESPECÍFICO, USAR O PACIENTE SELECIONADO COMO PADRÃO
      // MAS SÓ RESETAR SE O _SELECTEDREPORTUSERID NÃO FOR UM ID VÁLIDO (NÃO É O PACIENTE NEM O CUIDADOR)
      if (_selectedReportUserId == null) {
        _selectedReportUserId = selectedPatientId;
      } else if (_selectedReportUserId != selectedPatientId &&
          _selectedReportUserId != _linkedCuidadorId) {
        // SE O RELATÓRIO SELECIONADO NÃO É MAIS VÁLIDO (NÃO É O PACIENTE NEM O CUIDADOR), RESETAR
        _selectedReportUserId = selectedPatientId;
      }

      // SE NÃO HOUVER PACIENTE SELECIONADO, NÃO MOSTRAR NENHUM DADO
      if (selectedPatientId == null) {
        setState(() {
          _entries = [];
          _loading = false;
          _error = null;
          _linkedCuidadorId = null;
        });
        return;
      }

      // BUSCAR INFORMAÇÕES DO PACIENTE SELECIONADO NOS SHARES
      String? selectedPatientPerfil;
      String? selectedPatientNome;
      for (final share in _shares) {
        final ownerId = share['owner_id'] as int?;
        if (ownerId != null && ownerId == selectedPatientId) {
          selectedPatientNome = share['owner_nome'] as String?;
          selectedPatientPerfil = share['owner_perfil'] as String?;
          _userInfoCache[ownerId] = {
            'nome': selectedPatientNome ?? 'Paciente',
            'perfil': selectedPatientPerfil ?? 'Paciente',
          };
          break;
        }
      }

      // O BACKEND JÁ RETORNA ENTRIES DO PACIENTE SELECIONADO E DO CUIDADOR VINCULADO (SE HOUVER)
      // VAMOS BUSCAR OS ENTRIES E IDENTIFICAR TODOS OS USER_IDS QUE APARECEM

      final result = await ApiService.listEntries(
        tipo: 'diario',
        from: from,
        to: now,
      );

      if (!mounted) return;

      if (result['success'] == true && result['data'] is List) {
        List<Map<String, dynamic>> entriesList =
            List<Map<String, dynamic>>.from(
              (result['data'] as List).whereType<Map<String, dynamic>>(),
            );

        // O BACKEND RETORNA ENTRIES DE TODOS OS PACIENTES COMPARTILHADOS
        // PRECISAMOS FILTRAR APENAS DO PACIENTE SELECIONADO E IDENTIFICAR O CUIDADOR VINCULADO

        // COLETAR TODOS OS ENTRIES RETORNADOS ORIGINALMENTE
        final allEntries = List<Map<String, dynamic>>.from(
          (result['data'] as List).whereType<Map<String, dynamic>>(),
        );

        // COLETAR TODOS OS USER_IDS ÚNICOS DOS ENTRIES RETORNADOS
        final allUserIds = <int>{};
        for (final entry in allEntries) {
          final entryUserId = entry['user_id'] as int?;
          if (entryUserId != null) {
            allUserIds.add(entryUserId);
          }
        }

        // IDENTIFICAR O CUIDADOR VINCULADO À PESSOA COM TEA SELECIONADA
        // O BACKEND RETORNA ENTRIES DO CUIDADOR VINCULADO QUANDO O PROFISSIONAL ESTÁ VINCULADO A UMA PESSOA COM TEA
        // PRECISAMOS IDENTIFICAR QUAL USER_ID É O CUIDADOR VINCULADO
        int? cuidadorId;
        if (selectedPatientPerfil != null &&
            selectedPatientPerfil.toLowerCase().contains('tea')) {
          // ESTRATÉGIA: PROCURAR POR UM USER_ID QUE:
          // 1. NÃO É O SELECTEDPATIENTID
          // 2. ESTÁ NOS ENTRIES RETORNADOS (O BACKEND JÁ INCLUIU O CUIDADOR VINCULADO)
          // 3. NÃO ESTÁ NOS SHARES COMO OWNER DIRETO (POIS O CUIDADOR NÃO ESTÁ COMPARTILHADO DIRETAMENTE, APENAS VINCULADO)

          // PRIMEIRO, VERIFICAR SE HÁ ALGUM CUIDADOR NOS SHARES QUE NÃO SEJA O SELECTEDPATIENTID
          // SE HOUVER, PODE SER QUE O CUIDADOR TAMBÉM ESTEJA COMPARTILHADO DIRETAMENTE
          for (final share in _shares) {
            final ownerId = share['owner_id'] as int?;
            final ownerPerfil = share['owner_perfil'] as String?;
            if (ownerId != null &&
                ownerId != selectedPatientId &&
                ownerPerfil != null &&
                ownerPerfil.toLowerCase().contains('cuidador') &&
                allUserIds.contains(ownerId)) {
              // ESTE É UM CUIDADOR COMPARTILHADO DIRETAMENTE QUE TAMBÉM APARECE NOS ENTRIES
              // PODE SER O CUIDADOR VINCULADO À PESSOA COM TEA
              cuidadorId = ownerId;
              _userInfoCache[ownerId] = {
                'nome': share['owner_nome'] as String? ?? 'Cuidador',
                'perfil': 'Cuidador',
              };
              break;
            }
          }

          // SE NÃO ENCONTROU NOS SHARES, PROCURAR POR USER_IDS QUE NÃO ESTÃO NOS SHARES
          // MAS APARECEM NOS ENTRIES (SÃO OS CUIDADORES VINCULADOS)
          if (cuidadorId == null) {
            final shareOwnerIds = _shares
                .map((s) => s['owner_id'] as int?)
                .whereType<int>()
                .toSet();

            for (final userId in allUserIds) {
              if (userId != selectedPatientId &&
                  !shareOwnerIds.contains(userId)) {
                // ESTE USER_ID NÃO ESTÁ NOS SHARES, MAS APARECE NOS ENTRIES
                // É PROVAVELMENTE O CUIDADOR VINCULADO À PESSOA COM TEA
                cuidadorId = userId;
                // BUSCAR NOME DO ENTRY
                for (final entry in allEntries) {
                  if (entry['user_id'] == userId) {
                    final userName = entry['user_name'] as String?;
                    _userInfoCache[userId] = {
                      'nome': userName ?? 'Cuidador',
                      'perfil': 'Cuidador',
                    };
                    break;
                  }
                }
                break;
              }
            }
          }
        }

        // SE HOUVER CUIDADOR VINCULADO, ARMAZENAR PARA O SELETOR
        if (cuidadorId != null) {
          // ARMAZENAR INFORMAÇÕES DO CUIDADOR NO CACHE
          if (!_userInfoCache.containsKey(cuidadorId)) {
            for (final entry in allEntries) {
              if (entry['user_id'] == cuidadorId) {
                final userName = entry['user_name'] as String?;
                _userInfoCache[cuidadorId] = {
                  'nome': userName ?? 'Cuidador',
                  'perfil': 'Cuidador',
                };
                break;
              }
            }
          }
        }

        // FILTRAR ENTRIES BASEADO NO RELATÓRIO SELECIONADO
        // SE _SELECTEDREPORTUSERID FOR NULL OU IGUAL AO SELECTEDPATIENTID, MOSTRAR RELATÓRIO DA PESSOA COM TEA
        // SE FOR IGUAL AO CUIDADORID, MOSTRAR RELATÓRIO DO CUIDADOR
        final userIdToShow = _selectedReportUserId ?? selectedPatientId;

        entriesList = allEntries.where((entry) {
          final entryUserId = entry['user_id'] as int?;
          return entryUserId == userIdToShow;
        }).toList();

        // ORDENAR POR TIMESTAMP (MAIS RECENTE PRIMEIRO)
        entriesList.sort((a, b) {
          final timestampA = a['timestamp'] as String?;
          final timestampB = b['timestamp'] as String?;
          if (timestampA == null || timestampB == null) return 0;
          try {
            final dateA = DateTime.parse(timestampA);
            final dateB = DateTime.parse(timestampB);
            return dateB.compareTo(dateA);
          } catch (e) {
            return 0;
          }
        });

        // ADICIONAR IDENTIFICAÇÃO DE QUEM É CADA ENTRY
        for (final entry in entriesList) {
          final entryUserId = entry['user_id'] as int?;
          if (entryUserId != null && _userInfoCache.containsKey(entryUserId)) {
            final userInfo = _userInfoCache[entryUserId]!;
            final perfil = userInfo['perfil'] as String? ?? '';
            final nome = userInfo['nome'] as String? ?? '';
            entry['display_name'] = '$nome - $perfil';
          } else if (entryUserId != null) {
            // SE NÃO ESTIVER NO CACHE, USAR USER_NAME DO ENTRY
            final userName = entry['user_name'] as String?;
            final perfil = entryUserId == selectedPatientId
                ? (_userInfoCache[selectedPatientId]?['perfil'] as String? ??
                      'Paciente')
                : 'Cuidador';
            entry['display_name'] = userName != null
                ? '$userName - $perfil'
                : 'Usuário - $perfil';
          }
        }

        // MESCLAR COM ENTRIES LOCAIS
        final merged = _mergeEntries(localEntriesMap, entriesList);
        
        setState(() {
          _entries = merged;
          _loading = false;
          // GARANTIR QUE _LINKEDCUIDADORID ESTÁ NO ESTADO
          if (cuidadorId != null) {
            _linkedCuidadorId = cuidadorId;
          } else {
            _linkedCuidadorId = null;
          }
        });
      } else {
        setState(() {
          _loading = false;
          _error =
              result['message']?.toString() ??
              'Não foi possível carregar os registros.';
          _linkedCuidadorId = null;
        });
      }
    } else {
      // USUÁRIO NORMAL OU CUIDADOR VENDO PRÓPRIO RELATÓRIO
      // SE FOR CUIDADOR SEM VÍNCULOS, SÓ MOSTRAR SEUS PRÓPRIOS ENTRIES
      if (_isCuidador && _careLinks.isEmpty && _selectedPessoaTeaId == null) {
        // CUIDADOR SEM VÍNCULOS: APENAS SEUS PRÓPRIOS ENTRIES
        final result = await ApiService.listEntries(
          tipo: 'diario',
          from: from,
          to: now,
        );

        if (!mounted) return;

        if (result['success'] == true && result['data'] is List) {
          final apiEntries = List<Map<String, dynamic>>.from(
            (result['data'] as List).whereType<Map<String, dynamic>>(),
          );
          // FILTRAR APENAS ENTRIES DO USUÁRIO ATUAL (GARANTIR SEGURANÇA)
          final filteredApiEntries = apiEntries.where((entry) {
            final entryUserId = entry['user_id'] as int?;
            return entryUserId == currentUserId;
          }).toList();
          
          final merged = _mergeEntries(localEntriesMap, filteredApiEntries);
          setState(() {
            _entries = merged;
            _loading = false;
          });
        } else {
          setState(() {
            _loading = false;
            _error =
                result['message']?.toString() ??
                'Não foi possível carregar os registros.';
          });
        }
      } else {
        // PESSOA COM TEA OU CUIDADOR COM VÍNCULO: COMPORTAMENTO NORMAL
        final result = await ApiService.listEntries(
          tipo: 'diario',
          from: from,
          to: now,
        );

        if (!mounted) return;

        if (result['success'] == true && result['data'] is List) {
          final apiEntries = List<Map<String, dynamic>>.from(
            (result['data'] as List).whereType<Map<String, dynamic>>(),
          );
          final merged = _mergeEntries(localEntriesMap, apiEntries);
          setState(() {
            _entries = merged;
            _loading = false;
          });
        } else {
          setState(() {
            _loading = false;
            _error =
                result['message']?.toString() ??
                'Não foi possível carregar os registros.';
          });
        }
      }
    }
  }

  Map<String, double> _computePercentages(Map<String, String> labelToEmoji) {
    final counts = <String, int>{};
    int total = 0;
    for (final e in _entries) {
      final tags = e['tags'];
      if (tags is List) {
        // PROCURAR POR QUALQUER TAG QUE CORRESPONDA A UMA CHAVE DO MAP
        for (final label in labelToEmoji.keys) {
          if (tags.contains(label)) {
            counts[label] = (counts[label] ?? 0) + 1;
            total += 1;
            break; // UM LABEL POR SEÇÃO POR ENTRY
          }
        }
      }
    }
    if (total == 0) return {};
    return counts.map((k, v) => MapEntry(k, v * 100.0 / total));
  }

  List<String> _extractTexts(String prefix) {
    final List<String> items = [];
    final prefixLower = prefix.toLowerCase().replaceAll(':', '').trim();

    for (final e in _entries) {
      final displayName = e['display_name'] as String?;
      final texto = (e['texto']?.toString() ?? '');
      final lines = texto.split('\n');

      // OBTER IDENTIFICAÇÃO DO AUTOR SE DISPONÍVEL
      final prefixWithAuthor = displayName != null ? '[$displayName] ' : '';

      for (int i = 0; i < lines.length; i++) {
        final line = lines[i].trim();

        // VERIFICAR SE É A LINHA PRINCIPAL (EX: "ALIMENTAÇÃO: POUCO")
        if (line.toLowerCase().startsWith(prefix.toLowerCase())) {
          final value = line.substring(prefix.length).trim();
          if (value.isNotEmpty) {
            // VERIFICAR SE A PRÓXIMA LINHA É UMA OBSERVAÇÃO
            String? observation;
            if (i + 1 < lines.length) {
              final nextLine = lines[i + 1].trim().toLowerCase();
              if (nextLine.contains('observação') &&
                  nextLine.contains(prefixLower)) {
                final obsMatch = RegExp(
                  r':\s*(.+)',
                  caseSensitive: false,
                ).firstMatch(lines[i + 1]);
                if (obsMatch != null) {
                  observation = obsMatch.group(1)?.trim();
                }
              }
            }

            // ADICIONAR ITEM COM OU SEM OBSERVAÇÃO E COM IDENTIFICAÇÃO DO AUTOR
            final itemValue = observation != null && observation.isNotEmpty
                ? '$value (Obs: $observation)'
                : value;

            // ADICIONAR IDENTIFICAÇÃO APENAS SE FOR PROFISSIONAL E HOUVER DISPLAY_NAME
            if (widget.isProfissional && displayName != null) {
              items.add('$prefixWithAuthor$itemValue');
            } else {
              items.add(itemValue);
            }
          }
        }
      }
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final moodPerc = _computePercentages(moodEmoji);
    final sleepPerc = _computePercentages(sleepEmoji);
    final alimentacao = _extractTexts('Alimentação:');
    final crises = _extractTexts('Crise:');

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  const SizedBox(width: 6),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Relatórios',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color:
                              Theme.of(context).textTheme.titleLarge?.color ??
                              (Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white
                                  : const Color(0xFF2F2F2F)),
                        ),
                      ),
                      if (widget.isProfissional &&
                          _shares.isNotEmpty &&
                          _selectedPatientId != null)
                        Text(
                          _getOwnerNames(),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color:
                                Theme.of(context).textTheme.bodyMedium?.color ??
                                (Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFFB0B4C1)
                                    : const Color(0xFF6B7280)),
                          ),
                        )
                      else if (!widget.isProfissional)
                        Text(
                          'Análise de Registros',
                          style: TextStyle(
                            color:
                                Theme.of(context).textTheme.bodyMedium?.color ??
                                (Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFFB0B4C1)
                                    : const Color(0xFF6B7280)),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  // BOTÃO CONVIDAR PROFISSIONAL (PARA CUIDADOR E PESSOA COM TEA)
                  if ((_isCuidador || _isPessoaTea) &&
                      !widget.isProfissional) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: ElevatedButton.icon(
                        onPressed: () => _showInviteProfessionalDialog(context),
                        icon: const Icon(Icons.person_add_outlined),
                        label: const Text('Convidar Profissional'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4CAF50),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                  // SELETOR DE RELATÓRIO PARA PROFISSIONAL QUANDO HÁ CUIDADOR VINCULADO
                  if (widget.isProfissional &&
                      _selectedPatientId != null &&
                      _linkedCuidadorId != null) ...[
                    Builder(
                      builder: (context) {
                        // BUSCAR NOMES
                        String? pessoaTeaNome;
                        String? cuidadorNome;
                        for (final share in _shares) {
                          final ownerId = share['owner_id'] as int?;
                          if (ownerId == _selectedPatientId) {
                            pessoaTeaNome = share['owner_nome'] as String?;
                          } else if (ownerId == _linkedCuidadorId) {
                            cuidadorNome = share['owner_nome'] as String?;
                          }
                        }

                        if (pessoaTeaNome == null) {
                          pessoaTeaNome =
                              _userInfoCache[_selectedPatientId]?['nome']
                                  as String? ??
                              'Pessoa com TEA';
                        }
                        if (cuidadorNome == null) {
                          cuidadorNome =
                              _userInfoCache[_linkedCuidadorId]?['nome']
                                  as String? ??
                              'Cuidador';
                        }

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Theme.of(context).dividerColor,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.person_outline, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: DropdownButton<int>(
                                  value:
                                      _selectedReportUserId ??
                                      _selectedPatientId,
                                  isExpanded: true,
                                  underline: Container(),
                                  icon: const Icon(Icons.arrow_drop_down),
                                  items: [
                                    DropdownMenuItem<int>(
                                      value: _selectedPatientId,
                                      child: Text(
                                        '$pessoaTeaNome - Pessoa com TEA',
                                      ),
                                    ),
                                    DropdownMenuItem<int>(
                                      value: _linkedCuidadorId,
                                      child: Text('$cuidadorNome - Cuidador'),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    if (value != null &&
                                        value != _selectedReportUserId) {
                                      setState(() {
                                        _selectedReportUserId = value;
                                      });
                                      _load();
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                  // SELETOR DE RELATÓRIO PARA CUIDADOR
                  if (_isCuidador && _careLinks.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(context).dividerColor,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.person_outline, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButton<int>(
                              value: _selectedPessoaTeaId,
                              isExpanded: true,
                              hint: const Text('Meu relatório'),
                              underline: Container(),
                              icon: const Icon(Icons.arrow_drop_down),
                              items: [
                                const DropdownMenuItem<int>(
                                  value: null,
                                  child: Text('Meu relatório'),
                                ),
                                ..._careLinks.map((link) {
                                  final pessoaTeaId =
                                      link['pessoa_tea_id'] as int;
                                  final pessoaTeaNome =
                                      link['pessoa_tea_nome'] as String? ??
                                      'Pessoa com TEA';
                                  return DropdownMenuItem<int>(
                                    value: pessoaTeaId,
                                    child: Text(pessoaTeaNome),
                                  );
                                }),
                              ],
                              onChanged: (value) {
                                if (value != _selectedPessoaTeaId) {
                                  setState(() {
                                    _selectedPessoaTeaId = value;
                                  });
                                  _load();
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  // NÃO MOSTRAR BOTÕES DE PERÍODO SE PROFISSIONAL NÃO TIVER VÍNCULO OU NÃO TIVER PACIENTE SELECIONADO
                  // ADMINISTRADOR SEMPRE TEM ACESSO
                  if (_isAdministrador || (!(widget.isProfissional && _shares.isEmpty) &&
                      !(widget.isProfissional && _selectedPatientId == null)))
                    Row(
                      children: [
                        _PeriodButton(
                          selected: !_monthly,
                          label: 'Semana',
                          onTap: () async {
                            setState(() => _monthly = false);
                            await _load();
                          },
                        ),
                        const SizedBox(width: 12),
                        _PeriodButton(
                          selected: _monthly,
                          label: 'Mês',
                          onTap: () async {
                            setState(() => _monthly = true);
                            await _load();
                          },
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Text(_error!, textAlign: TextAlign.center),
                      ),
                    )
                  : (widget.isProfissional && !_isAdministrador && _shares.isEmpty)
                  ? _ReportsNoLinkView()
                  : (widget.isProfissional && !_isAdministrador && _selectedPatientId == null)
                  ? _ReportsNoPatientSelectedView()
                  : SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _MetricCard(
                                  title: 'Humor',
                                  iconColor: const Color(0xFFFFC107),
                                  items: _toEmojiRows(moodPerc, moodEmoji),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _MetricCard(
                                  title: 'Sono',
                                  iconColor: const Color(0xFF42A5F5),
                                  items: _toEmojiRows(sleepPerc, sleepEmoji),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _ListCard(
                                  title: 'Alimentação',
                                  iconColor: const Color(0xFF2ECC71),
                                  items: alimentacao,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _ListCard(
                                  title: 'Crises',
                                  iconColor: const Color(0xFFE74C3C),
                                  items: crises,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 0),
                            child: ElevatedButton.icon(
                              onPressed: _loading || _error != null
                                  ? null
                                  : _generatePdf,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF5C6EF8),
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(44),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              icon: const Icon(Icons.picture_as_pdf, size: 20),
                              label: const Text(
                                'PDF',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  List<_EmojiRow> _toEmojiRows(
    Map<String, double> perc,
    Map<String, String> map,
  ) {
    final rows = <_EmojiRow>[];
    perc.forEach((label, value) {
      // BUSCAR EMOJI NO MAPA, TENTANDO DIFERENTES VARIAÇÕES DO LABEL
      String? emoji = map[label];
      if (emoji == null || emoji.isEmpty) {
        // TENTAR BUSCAR SEM CASE SENSITIVITY
        for (final entry in map.entries) {
          if (entry.key.toLowerCase() == label.toLowerCase()) {
            emoji = entry.value;
            break;
          }
        }
      }
      // SE AINDA NÃO ENCONTROU, USAR FALLBACK
      emoji = emoji ?? '😊';
      rows.add(_EmojiRow(emoji: emoji, label: label, percent: value));
    });
    rows.sort((a, b) => b.percent.compareTo(a.percent));
    return rows;
  }

  Future<void> _generatePdf() async {
    try {
      final moodPerc = _computePercentages(moodEmoji);
      final sleepPerc = _computePercentages(sleepEmoji);
      final alimentacao = _extractTexts('Alimentação:');
      final crises = _extractTexts('Crise:');

      final period = _monthly ? 'Mês' : 'Semana';
      final now = DateTime.now();
      final from = _monthly
          ? now.subtract(const Duration(days: 30))
          : now.subtract(const Duration(days: 6));
      final periodText = _monthly
          ? '${from.day}/${from.month}/${from.year} - ${now.day}/${now.month}/${now.year}'
          : '${from.day}/${from.month}/${from.year} - ${now.day}/${now.month}/${now.year}';

      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          theme: pw.ThemeData.withFont(base: pw.Font.helvetica()),
          build: (pw.Context context) {
            // DETERMINAR O NOME DA PESSOA DO RELATÓRIO
            String? pessoaNome;
            if (widget.isProfissional && _selectedReportUserId != null) {
              // PARA PROFISSIONAL, BUSCAR O NOME DO USUÁRIO SELECIONADO
              if (_userInfoCache.containsKey(_selectedReportUserId)) {
                pessoaNome =
                    _userInfoCache[_selectedReportUserId]?['nome'] as String?;
              } else {
                // BUSCAR NOS SHARES
                for (final share in _shares) {
                  final ownerId = share['owner_id'] as int?;
                  if (ownerId == _selectedReportUserId) {
                    pessoaNome = share['owner_nome'] as String?;
                    break;
                  }
                }
              }
              // SE AINDA NÃO ENCONTROU, TENTAR BUSCAR NOS ENTRIES
              if (pessoaNome == null) {
                for (final entry in _entries) {
                  final entryUserId = entry['user_id'] as int?;
                  if (entryUserId == _selectedReportUserId) {
                    pessoaNome = entry['user_name'] as String?;
                    break;
                  }
                }
              }
            } else if (_selectedPessoaTeaId != null && _careLinks.isNotEmpty) {
              // PARA CUIDADOR VENDO RELATÓRIO DA PESSOA COM TEA
              pessoaNome =
                  _careLinks.firstWhere(
                        (link) => link['pessoa_tea_id'] == _selectedPessoaTeaId,
                        orElse: () => {},
                      )['pessoa_tea_nome']
                      as String?;
            } else {
              // USUÁRIO NORMAL OU CUIDADOR VENDO PRÓPRIO RELATÓRIO
              pessoaNome = _currentUser?['nomeCompleto'] as String?;
            }

            return [
              pw.Header(
                level: 0,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Relatório de Registros',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'Período: $period ($periodText)',
                      style: pw.TextStyle(
                        fontSize: 14,
                        color: PdfColors.grey700,
                      ),
                    ),
                    if (pessoaNome != null) ...[
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Pessoa: $pessoaNome',
                        style: pw.TextStyle(
                          fontSize: 14,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                    pw.Divider(),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: _buildPdfMetricSection('Humor', moodPerc, moodEmoji),
                  ),
                  pw.SizedBox(width: 20),
                  pw.Expanded(
                    child: _buildPdfMetricSection(
                      'Sono',
                      sleepPerc,
                      sleepEmoji,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: _buildPdfListSection('Alimentação', alimentacao),
                  ),
                  pw.SizedBox(width: 20),
                  pw.Expanded(child: _buildPdfListSection('Crises', crises)),
                ],
              ),
            ];
          },
        ),
      );

      final pdfBytes = await pdf.save();
      final fileName =
          'relatorio_${_monthly ? 'mes' : 'semana'}_${DateTime.now().millisecondsSinceEpoch}.pdf';

      if (mounted) {
        if (kIsWeb) {
          // PARA WEB: DOWNLOAD DIRETO
          downloadFile(pdfBytes, fileName);

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PDF baixado com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          // PARA MOBILE/DESKTOP: USAR SHARE_PLUS PARA SALVAR
          try {
            await Share.shareXFiles([
              XFile.fromData(
                pdfBytes,
                mimeType: 'application/pdf',
                name: fileName,
              ),
            ], text: 'Relatório de Registros - $period');
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Erro ao salvar PDF: ${e.toString()}')),
              );
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao gerar PDF: ${e.toString()}')),
        );
      }
    }
  }

  pw.Widget _buildPdfMetricSection(
    String title,
    Map<String, double> perc,
    Map<String, String> emojiMap,
  ) {
    final items = <pw.Widget>[
      pw.Text(
        title,
        style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 8),
    ];

    if (perc.isEmpty) {
      items.add(
        pw.Text(
          'Sem dados no período',
          style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
        ),
      );
    } else {
      final sorted = perc.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      for (final entry in sorted) {
        items.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 6),
            child: pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Text(
                    entry.key,
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.Text(
                  '${entry.value.toStringAsFixed(0)}%',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: items,
      ),
    );
  }

  pw.Widget _buildPdfListSection(String title, List<String> items) {
    final widgets = <pw.Widget>[
      pw.Text(
        title,
        style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 8),
    ];

    if (items.isEmpty) {
      widgets.add(
        pw.Text(
          'Sem dados no período',
          style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
        ),
      );
    } else {
      for (int i = 0; i < items.length; i++) {
        widgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 6),
            child: pw.Text(
              '${i + 1}. ${items[i]}',
              style: const pw.TextStyle(fontSize: 12),
            ),
          ),
        );
      }
    }

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: widgets,
      ),
    );
  }
}

class _PeriodButton extends StatelessWidget {
  const _PeriodButton({
    required this.selected,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 40,
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF5C6EF8) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : const Color(0xFF2F2F2F),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.iconColor,
    required this.items,
  });

  final String title;
  final Color iconColor;
  final List<_EmojiRow> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.circle, size: 10, color: iconColor),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color:
                      Theme.of(context).textTheme.titleLarge?.color ??
                      (Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : const Color(0xFF2F2F2F)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Text(
                      'Sem dados no período',
                      style: TextStyle(
                        color:
                            Theme.of(context).textTheme.bodyMedium?.color ??
                            (Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFFB0B4C1)
                                : const Color(0xFF9CA3AF)),
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final r = items[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              alignment: Alignment.center,
                              child: Text(
                                r.emoji,
                                style: const TextStyle(
                                  fontSize: 26,
                                  height: 1.0,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    r.label,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color:
                                          Theme.of(
                                            context,
                                          ).textTheme.titleLarge?.color ??
                                          (Theme.of(context).brightness ==
                                                  Brightness.dark
                                              ? Colors.white
                                              : const Color(0xFF2F2F2F)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${r.percent.toStringAsFixed(0)}%',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color:
                                    Theme.of(
                                      context,
                                    ).textTheme.titleLarge?.color ??
                                    (Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.white
                                        : const Color(0xFF2F2F2F)),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ListCard extends StatelessWidget {
  const _ListCard({
    required this.title,
    required this.iconColor,
    required this.items,
  });

  final String title;
  final Color iconColor;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.circle, size: 10, color: iconColor),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color:
                      Theme.of(context).textTheme.titleLarge?.color ??
                      (Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : const Color(0xFF2F2F2F)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Text(
                      'Sem dados no período',
                      style: TextStyle(
                        color:
                            Theme.of(context).textTheme.bodyMedium?.color ??
                            (Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFFB0B4C1)
                                : const Color(0xFF9CA3AF)),
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(height: 10),
                    itemBuilder: (context, index) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 4, right: 8),
                            child: Icon(
                              Icons.circle,
                              size: 6,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              items[index],
                              style: TextStyle(
                                fontSize: 13,
                                color:
                                    Theme.of(
                                      context,
                                    ).textTheme.titleLarge?.color ??
                                    (Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.white
                                        : const Color(0xFF2F2F2F)),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _EmojiRow {
  _EmojiRow({required this.emoji, required this.label, required this.percent});
  final String emoji;
  final String label;
  final double percent;
}

class _ReportsNoLinkView extends StatelessWidget {
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
              color:
                  Theme.of(context).textTheme.titleLarge?.color ??
                  (Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : const Color(0xFF1E1E1E)),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Você precisa estar vinculado a uma conta de Pessoa com TEA ou Cuidador para visualizar relatórios.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color:
                    Theme.of(context).textTheme.bodyMedium?.color ??
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

class _ReportsNoPatientSelectedView extends StatelessWidget {
  const _ReportsNoPatientSelectedView();

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
              color:
                  Theme.of(context).textTheme.bodyMedium?.color ??
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
                color:
                    Theme.of(context).textTheme.titleLarge?.color ??
                    (Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : const Color(0xFF1E1E1E)),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Selecione um paciente na tela de perfil para visualizar os relatórios.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color:
                      Theme.of(context).textTheme.bodyMedium?.color ??
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
