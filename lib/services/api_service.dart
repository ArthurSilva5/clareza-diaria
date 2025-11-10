import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Substitua pela URL do seu servidor no PythonAnywhere
  static const String baseUrl = 'https://ArthurVargas223.pythonanywhere.com';

  static Future<Map<String, dynamic>> login(String email, String senha) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email, 'senha': senha}),
      );

      // Verificar se a resposta é JSON
      final contentType = response.headers['content-type'];
      if (contentType != null && !contentType.contains('application/json')) {
        return {
          'success': false,
          'message':
              'O servidor retornou uma resposta inválida. Verifique se o endpoint /api/login está configurado corretamente no servidor Flask.',
        };
      }

      if (response.statusCode == 200) {
        try {
          final data = json.decode(response.body);
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
          // Se não conseguir decodificar JSON, usar a resposta como está (pode ser HTML)
          if (response.body.contains('<html>') ||
              response.body.contains('<!DOCTYPE')) {
            errorMessage =
                'O servidor retornou uma página HTML em vez de JSON. Verifique se o endpoint /api/login está configurado corretamente. Status: ${response.statusCode}';
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
            'O servidor retornou uma resposta inválida (HTML em vez de JSON). Verifique se o endpoint /api/login está configurado corretamente no Flask.';
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
        Uri.parse('$baseUrl/api/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'nomeCompleto': nomeCompleto,
          'email': email,
          'senha': senha,
          'quemE': normalizedQuemE,
          'preferenciasSensoriais': normalizedPreferencias,
        }),
      );

      // Verificar se a resposta é JSON
      final contentType = response.headers['content-type'];
      if (contentType != null && !contentType.contains('application/json')) {
        return {
          'success': false,
          'message':
              'O servidor retornou uma resposta inválida. Verifique se o endpoint /api/register está configurado corretamente no servidor Flask.',
        };
      }

      if (response.statusCode == 201 || response.statusCode == 200) {
        try {
          final data = json.decode(response.body);
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
          // Se não conseguir decodificar JSON, usar a resposta como está (pode ser HTML)
          if (response.body.contains('<html>') ||
              response.body.contains('<!DOCTYPE')) {
            errorMessage =
                'O servidor retornou uma página HTML em vez de JSON. Verifique se o endpoint /api/register está configurado corretamente. Status: ${response.statusCode}';
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
            'O servidor retornou uma resposta inválida (HTML em vez de JSON). Verifique se o endpoint /api/register está configurado corretamente no Flask.';
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
}
