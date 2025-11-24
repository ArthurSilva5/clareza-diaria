import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';
import '../services/local_storage_service.dart';

class SyncService {
  static bool _isSyncing = false;

  /// VERIFICAR SE ESTÁ ONLINE
  static Future<bool> isOnline() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  /// SINCRONIZAR ENTRIES PENDENTES
  static Future<void> syncPendingEntries() async {
    if (_isSyncing) return;
    
    final isOnline = await SyncService.isOnline();
    if (!isOnline) return;

    if (ApiService.accessToken == null) return;

    _isSyncing = true;

    try {
      final pending = LocalStorageService.getPendingSync();
      
      for (final entry in pending) {
        try {
          final response = await http.post(
            Uri.parse('${ApiService.baseUrl}/api/entries'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${ApiService.accessToken}',
            },
            body: json.encode({
              'tipo': entry.tipo,
              'texto': entry.texto,
              'tags': entry.tags,
              'timestamp': entry.timestamp.toIso8601String(),
            }),
          );

          if (response.statusCode == 201) {
            final data = json.decode(response.body);
            final serverId = data['id']?.toString();
            
            if (serverId != null) {
              await LocalStorageService.markAsSynced(
                entry.id!,
                serverId,
              );
            }
          } else if (response.statusCode == 401) {
            // TOKEN EXPIRADO, PARAR SINCRONIZAÇÃO
            break;
          }
        } catch (e) {
          // FALHOU ESTE ENTRY, CONTINUAR COM OS PRÓXIMOS
          print('Erro ao sincronizar entry ${entry.id}: $e');
          continue;
        }
      }
    } finally {
      _isSyncing = false;
    }
  }

  /// SINCRONIZAR ROTINAS PENDENTES (SE NECESSÁRIO NO FUTURO)
  static Future<void> syncPendingRoutines() async {
    // IMPLEMENTAR QUANDO NECESSÁRIO
  }
}

