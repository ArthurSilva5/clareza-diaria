import 'package:hive/hive.dart';

part 'local_entry.g.dart';

@HiveType(typeId: 0)
class LocalEntry extends HiveObject {
  @HiveField(0)
  String? id; // NULL SE AINDA NÃO FOI SINCRONIZADO

  @HiveField(1)
  String tipo;

  @HiveField(2)
  String texto;

  @HiveField(3)
  List<String> tags;

  @HiveField(4)
  DateTime timestamp;

  @HiveField(5)
  bool synced; // TRUE SE JÁ FOI ENVIADO PARA API

  @HiveField(6)
  DateTime createdAt;

  @HiveField(7)
  int? userId; // ID DO USUÁRIO QUE CRIOU O ENTRY

  LocalEntry({
    this.id,
    required this.tipo,
    required this.texto,
    required this.tags,
    required this.timestamp,
    this.synced = false,
    required this.createdAt,
    this.userId,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tipo': tipo,
      'texto': texto,
      'tags': tags,
      'timestamp': timestamp.toIso8601String(),
      'synced': synced,
      'createdAt': createdAt.toIso8601String(),
      'user_id': userId,
    };
  }

  factory LocalEntry.fromJson(Map<String, dynamic> json) {
    return LocalEntry(
      id: json['id']?.toString(),
      tipo: json['tipo'] as String,
      texto: json['texto'] as String,
      tags: List<String>.from(json['tags'] ?? []),
      timestamp: DateTime.parse(json['timestamp'] as String),
      synced: json['synced'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      userId: json['user_id'] as int?,
    );
  }
}

