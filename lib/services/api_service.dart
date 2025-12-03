import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/local_entry.dart';
import '../services/local_storage_service.dart';

class ApiService {
  // SUBSTITUA PELA URL DO SEU SERVIDOR NO PYTHONANYWHERE
  static const String baseUrl = 'http://127.0.0.1:5000';

  static String? _accessToken;
  static int? _currentUserId;

  static String? get accessToken => _accessToken;
  static int? get currentUserId => _currentUserId;

  static void clearTokens() {
    _accessToken = null;
    _currentUserId = null;
  }

  static void _storeTokens(Map<String, dynamic> payload) {
    _accessToken = payload['access_token'] as String?;
    // EXTRAIR USERID DO PAYLOAD SE DISPONÍVEL
    if (payload['user'] != null && payload['user'] is Map) {
      final user = payload['user'] as Map<String, dynamic>;
      _currentUserId = user['id'] as int?;
    }
  }

  static void setCurrentUserId(int? userId) {
    _currentUserId = userId;
  }

  static Future<Map<String, dynamic>> login(String email, String senha) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email, 'senha': senha}),
      );

      // VERIFICAR SE A RESPOSTA É JSON
      final contentType = response.headers['content-type'];
      if (contentType != null && !contentType.contains('application/json')) {
        return {
          'success': false,
          'message':
              'O servidor retornou uma resposta inválida. Verifique se o endpoint /api/auth/login está configurado corretamente no servidor Flask.',
        };
      }

      if (response.statusCode == 200) {
        try {
          final data = json.decode(response.body);
          if (data is Map<String, dynamic>) {
            _storeTokens(data);
          }
          return {'success': true, 'data': data};
        } catch (e) {
          return {
            'success': false,
            'message':
                'Erro ao processar resposta do servidor. Resposta recebida: ${response.body.substring(0, response.body.length > 100 ? 100 : response.body.length)}',
          };
        }
      } else {
        String errorMessage = 'Erro ao fazer login';
        try {
          final errorData = json.decode(response.body);
          errorMessage =
              errorData['message'] ?? errorData['error'] ?? errorMessage;
        } catch (e) {
          // SE NÃO CONSEGUIR DECODIFICAR JSON, USAR A RESPOSTA COMO ESTÁ (PODE SER HTML)
          if (response.body.contains('<html>') ||
              response.body.contains('<!DOCTYPE')) {
            errorMessage =
                'O servidor retornou uma página HTML em vez de JSON. Verifique se o endpoint /api/auth/login está configurado corretamente. Status: ${response.statusCode}';
          } else {
            errorMessage =
                'Erro ${response.statusCode}: ${response.body.substring(0, response.body.length > 100 ? 100 : response.body.length)}';
          }
        }

        return {'success': false, 'message': errorMessage};
      }
    } catch (e) {
      String errorMessage = 'Erro de conexão';

      if (e.toString().contains('FormatException')) {
        errorMessage =
            'O servidor retornou uma resposta inválida (HTML em vez de JSON). Verifique se o endpoint /api/auth/login está configurado corretamente no Flask.';
      } else if (e.toString().contains('Failed host lookup')) {
        errorMessage =
            'Não foi possível conectar ao servidor. Verifique sua conexão com a internet e se a URL da API está correta.';
      } else if (e.toString().contains('SocketException')) {
        errorMessage =
            'Erro de conexão com o servidor. Verifique se o servidor Flask está online e acessível.';
      } else {
        errorMessage = 'Erro de conexão: ${e.toString()}';
      }

      return {'success': false, 'message': errorMessage};
    }
  }

  static Future<Map<String, dynamic>> register({
    required String nomeCompleto,
    required String email,
    required String senha,
    String? quemE,
    String? preferenciasSensoriais,
  }) async {
    final normalizedPreferencias =
        (preferenciasSensoriais?.trim().isEmpty ?? true)
        ? null
        : preferenciasSensoriais;

    final normalizedQuemE = (quemE?.trim().isEmpty ?? true) ? null : quemE;

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/signup'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'nomeCompleto': nomeCompleto,
          'email': email,
          'senha': senha,
          'quemE': normalizedQuemE,
          'preferenciasSensoriais': normalizedPreferencias,
        }),
      );

      // VERIFICAR SE A RESPOSTA É JSON
      final contentType = response.headers['content-type'];
      if (contentType != null && !contentType.contains('application/json')) {
        return {
          'success': false,
          'message':
              'O servidor retornou uma resposta inválida. Verifique se o endpoint /api/auth/signup está configurado corretamente no servidor Flask.',
        };
      }

      if (response.statusCode == 201 || response.statusCode == 200) {
        try {
          final data = json.decode(response.body);
          if (data is Map<String, dynamic>) {
            _storeTokens(data);
          }
          return {'success': true, 'data': data};
        } catch (e) {
          return {
            'success': false,
            'message':
                'Erro ao processar resposta do servidor. Resposta recebida: ${response.body.substring(0, response.body.length > 100 ? 100 : response.body.length)}',
          };
        }
      } else {
        String errorMessage = 'Erro ao criar conta';
        try {
          final errorData = json.decode(response.body);
          errorMessage =
              errorData['message'] ?? errorData['error'] ?? errorMessage;
        } catch (e) {
          // SE NÃO CONSEGUIR DECODIFICAR JSON, USAR A RESPOSTA COMO ESTÁ (PODE SER HTML)
          if (response.body.contains('<html>') ||
              response.body.contains('<!DOCTYPE')) {
            errorMessage =
                'O servidor retornou uma página HTML em vez de JSON. Verifique se o endpoint /api/auth/signup está configurado corretamente. Status: ${response.statusCode}';
          } else {
            errorMessage =
                'Erro ${response.statusCode}: ${response.body.substring(0, response.body.length > 100 ? 100 : response.body.length)}';
          }
        }

        return {'success': false, 'message': errorMessage};
      }
    } catch (e) {
      String errorMessage = 'Erro de conexão';

      if (e.toString().contains('FormatException')) {
        errorMessage =
            'O servidor retornou uma resposta inválida (HTML em vez de JSON). Verifique se o endpoint /api/auth/signup está configurado corretamente no Flask.';
      } else if (e.toString().contains('Failed host lookup')) {
        errorMessage =
            'Não foi possível conectar ao servidor. Verifique sua conexão com a internet e se a URL da API está correta.';
      } else if (e.toString().contains('SocketException')) {
        errorMessage =
            'Erro de conexão com o servidor. Verifique se o servidor Flask está online e acessível.';
      } else {
        errorMessage = 'Erro de conexão: ${e.toString()}';
      }

      return {'success': false, 'message': errorMessage};
    }
  }

  static Future<Map<String, dynamic>> createDiaryEntry({
    required String tipo,
    required String texto,
    List<String>? tags,
    DateTime? timestamp,
    int? userId,
  }) async {
    // 1. SEMPRE SALVAR LOCALMENTE PRIMEIRO
    final now = DateTime.now();
    final localEntry = LocalEntry(
      id: null, // SERÁ GERADO QUANDO SALVAR
      tipo: tipo,
      texto: texto,
      tags: tags ?? [],
      timestamp: timestamp ?? now,
      synced: false,
      createdAt: now,
      userId: userId ?? _currentUserId,
    );

    await LocalStorageService.saveEntry(localEntry);

    // 2. TENTAR ENVIAR PARA API (SE ONLINE E AUTENTICADO)
    final token = _accessToken;
    if (token == null) {
      return {
        'success': true,
        'offline': true,
        'message': 'Salvo localmente. Será sincronizado quando houver conexão.',
      };
    }

    final isOnline = await Connectivity().checkConnectivity() != ConnectivityResult.none;
    if (!isOnline) {
      return {
        'success': true,
        'offline': true,
        'message': 'Salvo localmente. Será sincronizado quando houver conexão.',
      };
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/entries'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'tipo': tipo,
          'texto': texto,
          if (tags != null && tags.isNotEmpty) 'tags': tags,
          if (timestamp != null) 'timestamp': timestamp.toIso8601String(),
        }),
      );

      final contentType = response.headers['content-type'];
      if (contentType != null && !contentType.contains('application/json')) {
        // FALHOU, MAS JÁ ESTÁ SALVO LOCALMENTE
        return {
          'success': true,
          'offline': true,
          'message': 'Salvo localmente. Será sincronizado quando houver conexão.',
        };
      }

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = json.decode(response.body);
        final serverId = data['id']?.toString();
        
        // MARCAR COMO SINCRONIZADO
        if (serverId != null && localEntry.id != null) {
          await LocalStorageService.markAsSynced(localEntry.id!, serverId);
        }
        
        return {'success': true, 'data': data};
      } else {
        // FALHOU, MAS JÁ ESTÁ SALVO LOCALMENTE
        return {
          'success': true,
          'offline': true,
          'message': 'Salvo localmente. Será sincronizado quando houver conexão.',
        };
      }
    } catch (e) {
      // ERRO DE CONEXÃO, MAS JÁ ESTÁ SALVO LOCALMENTE
      return {
        'success': true,
        'offline': true,
        'message': 'Salvo localmente. Será sincronizado quando houver conexão.',
      };
    }
  }

  static Map<String, String> _authHeaders({Map<String, String>? extra}) {
    final token = _accessToken;
    if (token == null) {
      throw StateError('Usuário não autenticado.');
    }

    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
      if (extra != null) ...extra,
    };
  }

  static Future<Map<String, dynamic>> listBoards() async {
    if (_accessToken == null) {
      return {
        'success': false,
        'message': 'Usuário não autenticado. Faça login novamente.',
      };
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/boards'),
        headers: _authHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {'success': true, 'data': data};
      }

      return {
        'success': false,
        'message': 'Não foi possível carregar os quadros (${response.statusCode}).',
        'detail': response.body,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Erro de conexão ao carregar quadros: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> createBoard(String nome) async {
    if (_accessToken == null) {
      return {
        'success': false,
        'message': 'Usuário não autenticado. Faça login novamente.',
      };
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/boards'),
        headers: _authHeaders(),
        body: json.encode({'nome': nome}),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = json.decode(response.body);
        return {'success': true, 'data': data};
      }

      return {
        'success': false,
        'message': 'Não foi possível criar o quadro (${response.statusCode}).',
        'detail': response.body,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Erro de conexão ao criar quadro: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> createBoardItem({
    required int boardId,
    required String texto,
    String? emoji,
    String? categoria,
    String? imgUrl,
    String? audioUrl,
  }) async {
    if (_accessToken == null) {
      return {
        'success': false,
        'message': 'Usuário não autenticado. Faça login novamente.',
      };
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/boards/$boardId/items'),
        headers: _authHeaders(),
        body: json.encode({
          'texto': texto,
          if (emoji != null) 'emoji': emoji,
          if (categoria != null) 'categoria': categoria,
          if (imgUrl != null) 'img_url': imgUrl,
          if (audioUrl != null) 'audio_url': audioUrl,
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = json.decode(response.body);
        return {'success': true, 'data': data};
      }

      return {
        'success': false,
        'message': 'Não foi possível criar o cartão (${response.statusCode}).',
        'detail': response.body,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Erro de conexão ao criar o cartão: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> updateBoardItem({
    required int boardId,
    required int itemId,
    String? texto,
    String? emoji,
    String? categoria,
    String? imgUrl,
    String? audioUrl,
  }) async {
    if (_accessToken == null) {
      return {
        'success': false,
        'message': 'Usuário não autenticado. Faça login novamente.',
      };
    }

    try {
      final payload = <String, dynamic>{};
      if (texto != null) payload['texto'] = texto;
      if (emoji != null) payload['emoji'] = emoji;
      if (categoria != null) payload['categoria'] = categoria;
      if (imgUrl != null) payload['img_url'] = imgUrl;
      if (audioUrl != null) payload['audio_url'] = audioUrl;

      final response = await http.put(
        Uri.parse('$baseUrl/api/boards/$boardId/items/$itemId'),
        headers: _authHeaders(),
        body: json.encode(payload),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {'success': true, 'data': data};
      }

      return {
        'success': false,
        'message': 'Não foi possível atualizar o cartão (${response.statusCode}).',
        'detail': response.body,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Erro de conexão ao atualizar o cartão: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> deleteBoardItem({
    required int boardId,
    required int itemId,
  }) async {
    if (_accessToken == null) {
      return {
        'success': false,
        'message': 'Usuário não autenticado. Faça login novamente.',
      };
    }

    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/boards/$boardId/items/$itemId'),
        headers: _authHeaders(extra: {'Content-Type': 'application/json'}),
      );

      if (response.statusCode == 204) {
        return {'success': true};
      }

      return {
        'success': false,
        'message': 'Não foi possível remover o cartão (${response.statusCode}).',
        'detail': response.body,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Erro de conexão ao remover o cartão: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> listRoutines() async {
    if (_accessToken == null) {
      return {
        'success': false,
        'message': 'Usuário não autenticado. Faça login novamente.',
      };
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/routines'),
        headers: _authHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {'success': true, 'data': data};
      }

      return {
        'success': false,
        'message': 'Não foi possível carregar as rotinas (${response.statusCode}).',
        'detail': response.body,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Erro de conexão ao carregar rotinas: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> createRoutine({
    required String titulo,
    String? lembrete,
    int? pessoaTeaId,
  }) async {
    if (_accessToken == null) {
      return {
        'success': false,
        'message': 'Usuário não autenticado. Faça login novamente.',
      };
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/routines'),
        headers: _authHeaders(),
        body: json.encode({
          'titulo': titulo,
          if (lembrete != null && lembrete.isNotEmpty) 'lembrete': lembrete,
          if (pessoaTeaId != null) 'pessoa_tea_id': pessoaTeaId,
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = json.decode(response.body);
        return {'success': true, 'data': data};
      }

      return {
        'success': false,
        'message': 'Não foi possível criar a rotina (${response.statusCode}).',
        'detail': response.body,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Erro de conexão ao criar rotina: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> updateRoutine({
    required int routineId,
    String? titulo,
    String? lembrete,
  }) async {
    if (_accessToken == null) {
      return {
        'success': false,
        'message': 'Usuário não autenticado. Faça login novamente.',
      };
    }

    try {
      final payload = <String, dynamic>{};
      if (titulo != null) payload['titulo'] = titulo;
      if (lembrete != null) payload['lembrete'] = lembrete;

      final response = await http.put(
        Uri.parse('$baseUrl/api/routines/$routineId'),
        headers: _authHeaders(),
        body: json.encode(payload),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {'success': true, 'data': data};
      }

      return {
        'success': false,
        'message': 'Não foi possível atualizar a rotina (${response.statusCode}).',
        'detail': response.body,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Erro de conexão ao atualizar rotina: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> deleteRoutine(int routineId) async {
    if (_accessToken == null) {
      return {
        'success': false,
        'message': 'Usuário não autenticado. Faça login novamente.',
      };
    }

    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/routines/$routineId'),
        headers: _authHeaders(extra: {'Content-Type': 'application/json'}),
      );

      if (response.statusCode == 204) {
        return {'success': true};
      }

      return {
        'success': false,
        'message': 'Não foi possível excluir a rotina (${response.statusCode}).',
        'detail': response.body,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Erro de conexão ao excluir rotina: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> addRoutineStep({
    required int routineId,
    required String descricao,
    int? duracao,
    int? ordem,
  }) async {
    if (_accessToken == null) {
      return {
        'success': false,
        'message': 'Usuário não autenticado. Faça login novamente.',
      };
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/routines/$routineId/steps'),
        headers: _authHeaders(),
        body: json.encode({
          'descricao': descricao,
          if (duracao != null) 'duracao': duracao,
          if (ordem != null) 'ordem': ordem,
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = json.decode(response.body);
        return {'success': true, 'data': data};
      }

      return {
        'success': false,
        'message': 'Não foi possível adicionar o passo (${response.statusCode}).',
        'detail': response.body,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Erro de conexão ao adicionar passo: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> updateRoutineStep({
    required int routineId,
    required int stepId,
    String? descricao,
    int? duracao,
    int? ordem,
  }) async {
    if (_accessToken == null) {
      return {
        'success': false,
        'message': 'Usuário não autenticado. Faça login novamente.',
      };
    }

    try {
      final payload = <String, dynamic>{};
      if (descricao != null) payload['descricao'] = descricao;
      if (duracao != null) payload['duracao'] = duracao;
      if (ordem != null) payload['ordem'] = ordem;

      final response = await http.put(
        Uri.parse('$baseUrl/api/routines/$routineId/steps/$stepId'),
        headers: _authHeaders(),
        body: json.encode(payload),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {'success': true, 'data': data};
      }

      return {
        'success': false,
        'message': 'Não foi possível atualizar o passo (${response.statusCode}).',
        'detail': response.body,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Erro de conexão ao atualizar passo: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> deleteRoutineStep({
    required int routineId,
    required int stepId,
  }) async {
    if (_accessToken == null) {
      return {
        'success': false,
        'message': 'Usuário não autenticado. Faça login novamente.',
      };
    }

    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/routines/$routineId/steps/$stepId'),
        headers: _authHeaders(extra: {'Content-Type': 'application/json'}),
      );

      if (response.statusCode == 204) {
        return {'success': true};
      }

      return {
        'success': false,
        'message': 'Não foi possível excluir o passo (${response.statusCode}).',
        'detail': response.body,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Erro de conexão ao excluir passo: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> getWeeklyReport({
    DateTime? from,
    DateTime? to,
    int? pessoaTeaId,
  }) async {
    if (_accessToken == null) {
      return {
        'success': false,
        'message': 'Usuário não autenticado. Faça login novamente.',
      };
    }

    try {
      final query = <String, String>{};
      if (from != null) query['from'] = from.toIso8601String();
      if (to != null) query['to'] = to.toIso8601String();
      if (pessoaTeaId != null) query['pessoa_tea_id'] = pessoaTeaId.toString();

      final uri = Uri.parse('$baseUrl/api/reports/weekly').replace(queryParameters: query);
      final response = await http.get(uri, headers: _authHeaders());

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {'success': true, 'data': data};
      }

      return {
        'success': false,
        'message': 'Não foi possível carregar o relatório (${response.statusCode}).',
        'detail': response.body,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Erro de conexão ao carregar relatório: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> listEntries({
    String? tipo,
    DateTime? from,
    DateTime? to,
    int? pessoaTeaId,
  }) async {
    if (_accessToken == null) {
      return {
        'success': false,
        'message': 'Usuário não autenticado. Faça login novamente.',
      };
    }

    try {
      final query = <String, String>{};
      if (tipo != null) query['tipo'] = tipo;
      if (from != null) query['from'] = from.toIso8601String();
      if (to != null) query['to'] = to.toIso8601String();
      if (pessoaTeaId != null) query['pessoa_tea_id'] = pessoaTeaId.toString();

      final uri = Uri.parse('$baseUrl/api/entries').replace(queryParameters: query);
      final response = await http.get(uri, headers: _authHeaders());

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {'success': true, 'data': data};
      }

      return {
        'success': false,
        'message': 'Não foi possível carregar os registros (${response.statusCode}).',
        'detail': response.body,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Erro de conexão ao carregar registros: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (_accessToken == null) {
      return {
        'success': false,
        'message': 'Usuário não autenticado. Faça login novamente.',
      };
    }

    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/auth/change-password'),
        headers: _authHeaders(),
        body: json.encode({
          'senha_atual': currentPassword,
          'nova_senha': newPassword,
        }),
      );

      final contentType = response.headers['content-type'];
      if (contentType != null && !contentType.contains('application/json')) {
        return {
          'success': false,
          'message': 'O servidor retornou uma resposta inválida.',
        };
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {'success': true, 'data': data};
      } else {
        String errorMessage = 'Erro ao alterar senha';
        try {
          final errorData = json.decode(response.body);
          errorMessage =
              errorData['message'] ?? errorData['error'] ?? errorMessage;
        } catch (e) {
          errorMessage =
              'Erro ${response.statusCode}: ${response.body.substring(0, response.body.length > 100 ? 100 : response.body.length)}';
        }
        return {'success': false, 'message': errorMessage};
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Erro de conexão: ${e.toString()}',
      };
    }
  }

  // ========== VÍNCULO DE CUIDADO ==========

  static Future<Map<String, dynamic>> requestCareLink({
    required String pessoaTeaEmail,
  }) async {
    if (_accessToken == null) {
      return {
        'success': false,
        'message': 'Usuário não autenticado. Faça login novamente.',
      };
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/care-links/request'),
        headers: _authHeaders(),
        body: json.encode({
          'pessoa_tea_email': pessoaTeaEmail,
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = json.decode(response.body);
        return {'success': true, 'data': data};
      } else {
        String errorMessage = 'Erro ao solicitar vínculo';
        try {
          final errorData = json.decode(response.body);
          errorMessage =
              errorData['message'] ?? errorData['error'] ?? errorMessage;
        } catch (e) {
          errorMessage =
              'Erro ${response.statusCode}: ${response.body.substring(0, response.body.length > 100 ? 100 : response.body.length)}';
        }
        return {'success': false, 'message': errorMessage};
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Erro de conexão: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> respondCareLink({
    required int careLinkId,
    required bool accept,
  }) async {
    if (_accessToken == null) {
      return {
        'success': false,
        'message': 'Usuário não autenticado. Faça login novamente.',
      };
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/care-links/$careLinkId/respond'),
        headers: _authHeaders(),
        body: json.encode({
          'accept': accept,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {'success': true, 'data': data};
      } else {
        String errorMessage = 'Erro ao responder solicitação';
        try {
          final errorData = json.decode(response.body);
          errorMessage =
              errorData['message'] ?? errorData['error'] ?? errorMessage;
        } catch (e) {
          errorMessage =
              'Erro ${response.statusCode}: ${response.body.substring(0, response.body.length > 100 ? 100 : response.body.length)}';
        }
        return {'success': false, 'message': errorMessage};
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Erro de conexão: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> listCareLinks() async {
    if (_accessToken == null) {
      return {
        'success': false,
        'message': 'Usuário não autenticado. Faça login novamente.',
      };
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/care-links'),
        headers: _authHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {'success': true, 'data': data};
      }

      return {
        'success': false,
        'message': 'Não foi possível carregar os vínculos (${response.statusCode}).',
        'detail': response.body,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Erro de conexão ao carregar vínculos: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> deleteCareLink({required int careLinkId}) async {
    if (_accessToken == null) {
      return {
        'success': false,
        'message': 'Usuário não autenticado. Faça login novamente.',
      };
    }

    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/care-links/$careLinkId'),
        headers: _authHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {'success': true, 'data': data};
      }

      return {
        'success': false,
        'message': 'Não foi possível remover o vínculo (${response.statusCode}).',
        'detail': response.body,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Erro de conexão ao remover vínculo: ${e.toString()}',
      };
    }
  }

  // ========== COMPARTILHAMENTO (SHARES) ==========

  static Future<Map<String, dynamic>> requestShareAccess({required String ownerEmail}) async {
    if (_accessToken == null) {
      return {
        'success': false,
        'message': 'Usuário não autenticado. Faça login novamente.',
      };
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/shares/request'),
        headers: _authHeaders(),
        body: json.encode({
          'owner_email': ownerEmail.trim().toLowerCase(),
        }),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        return {'success': true, 'data': data};
      }

      final errorData = json.decode(response.body);
      return {
        'success': false,
        'message': errorData['message'] ?? 'Não foi possível solicitar acesso.',
        'detail': response.body,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Erro de conexão ao solicitar acesso: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> createShare({required String viewerEmail, String escopo = 'read'}) async {
    if (_accessToken == null) {
      return {
        'success': false,
        'message': 'Usuário não autenticado. Faça login novamente.',
      };
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/shares'),
        headers: _authHeaders(),
        body: json.encode({
          'viewer_email': viewerEmail.trim().toLowerCase(),
          'escopo': escopo,
        }),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        return {'success': true, 'data': data};
      }

      final errorData = json.decode(response.body);
      return {
        'success': false,
        'message': errorData['message'] ?? 'Não foi possível criar o compartilhamento.',
        'detail': response.body,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Erro de conexão ao criar compartilhamento: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> respondShare({
    required int shareId,
    required bool accept,
  }) async {
    if (_accessToken == null) {
      return {
        'success': false,
        'message': 'Usuário não autenticado. Faça login novamente.',
      };
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/shares/$shareId/respond'),
        headers: _authHeaders(),
        body: json.encode({
          'accept': accept,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {'success': true, 'data': data};
      }

      final errorData = json.decode(response.body);
      return {
        'success': false,
        'message': errorData['message'] ?? 'Não foi possível responder a solicitação.',
        'detail': response.body,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Erro de conexão ao responder solicitação: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> deleteShare({required int shareId}) async {
    if (_accessToken == null) {
      return {
        'success': false,
        'message': 'Usuário não autenticado. Faça login novamente.',
      };
    }

    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/shares/$shareId'),
        headers: _authHeaders(),
      );

      if (response.statusCode == 204) {
        return {'success': true};
      }

      return {
        'success': false,
        'message': 'Não foi possível remover o compartilhamento (${response.statusCode}).',
        'detail': response.body,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Erro de conexão ao remover compartilhamento: ${e.toString()}',
      };
    }
  }

  // ========== NOTIFICAÇÕES ==========

  static Future<Map<String, dynamic>> listNotifications() async {
    if (_accessToken == null) {
      return {
        'success': false,
        'message': 'Usuário não autenticado. Faça login novamente.',
      };
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/notifications'),
        headers: _authHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {'success': true, 'data': data};
      }

      return {
        'success': false,
        'message': 'Não foi possível carregar as notificações (${response.statusCode}).',
        'detail': response.body,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Erro de conexão ao carregar notificações: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> markNotificationRead({
    required int notificationId,
  }) async {
    if (_accessToken == null) {
      return {
        'success': false,
        'message': 'Usuário não autenticado. Faça login novamente.',
      };
    }

    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/notifications/$notificationId/read'),
        headers: _authHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {'success': true, 'data': data};
      }

      return {
        'success': false,
        'message': 'Não foi possível marcar notificação como lida (${response.statusCode}).',
        'detail': response.body,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Erro de conexão: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> listShares() async {
    if (_accessToken == null) {
      return {
        'success': false,
        'message': 'Usuário não autenticado. Faça login novamente.',
      };
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/shares'),
        headers: _authHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {'success': true, 'data': data};
      }

      return {
        'success': false,
        'message': 'Não foi possível carregar os compartilhamentos (${response.statusCode}).',
        'detail': response.body,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Erro de conexão ao carregar compartilhamentos: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> requestHelp({required int userId}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/help-request'),
        headers: {
          'Content-Type': 'application/json',
          if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
        },
        body: json.encode({'user_id': userId}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        return {'success': true, 'data': data};
      } else {
        final error = json.decode(response.body);
        return {
          'success': false,
          'message': error['message'] ?? 'Erro ao solicitar ajuda',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Erro de conexão: ${e.toString()}',
      };
    }
  }
}
