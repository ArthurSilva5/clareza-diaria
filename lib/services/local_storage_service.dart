import 'package:hive_flutter/hive_flutter.dart';
import '../models/local_entry.dart';

class LocalStorageService {
  static Box<LocalEntry>? _entriesBox;
  static bool _initialized = false;

  /// INICIALIZAR HIVE E ABRIR BOXES
  static Future<void> init() async {
    if (_initialized) return;

    await Hive.initFlutter();
    
    // REGISTRAR ADAPTER (SERÁ GERADO PELO BUILD_RUNNER)
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(LocalEntryAdapter());
    }

    _entriesBox = await Hive.openBox<LocalEntry>('entries');
    _initialized = true;
  }

  /// SALVAR ENTRY LOCALMENTE
  static Future<void> saveEntry(LocalEntry entry) async {
    await init();
    
    final key = entry.id ?? 
        'local_${entry.createdAt.millisecondsSinceEpoch}';
    
    entry.id = key;
    await _entriesBox!.put(key, entry);
  }

  /// BUSCAR TODOS OS ENTRIES LOCAIS
  static List<LocalEntry> getLocalEntries() {
    if (!_initialized || _entriesBox == null) return [];
    return _entriesBox!.values.toList();
  }

  /// BUSCAR ENTRIES PENDENTES DE SINCRONIZAÇÃO
  static List<LocalEntry> getPendingSync() {
    if (!_initialized || _entriesBox == null) return [];
    return _entriesBox!.values.where((e) => !e.synced).toList();
  }

  /// MARCAR ENTRY COMO SINCRONIZADO
  static Future<void> markAsSynced(String entryId, String serverId) async {
    await init();
    
    final entry = _entriesBox!.get(entryId);
    if (entry != null) {
      entry.id = serverId;
      entry.synced = true;
      await _entriesBox!.put(serverId, entry);
      
      // REMOVER ENTRADA ANTIGA SE A CHAVE MUDOU
      if (entryId != serverId && entryId.startsWith('local_')) {
        await _entriesBox!.delete(entryId);
      }
    }
  }

  /// REMOVER ENTRY LOCAL
  static Future<void> deleteEntry(String entryId) async {
    await init();
    await _entriesBox!.delete(entryId);
  }

  /// LIMPAR TODOS OS ENTRIES LOCAIS (ÚTIL PARA TESTES)
  static Future<void> clearAll() async {
    await init();
    await _entriesBox!.clear();
  }

  /// BUSCAR ENTRY POR ID
  static LocalEntry? getEntry(String entryId) {
    if (!_initialized || _entriesBox == null) return null;
    return _entriesBox!.get(entryId);
  }
}

