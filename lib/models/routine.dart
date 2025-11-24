class RoutineModel {
  RoutineModel({
    required this.id,
    required this.titulo,
    this.lembrete,
    this.userId,
    this.userName,
    List<RoutineStepModel>? passos,
  }) : passos = passos ?? <RoutineStepModel>[];

  final int id;
  String titulo;
  String? lembrete;
  int? userId;
  String? userName;
  final List<RoutineStepModel> passos;

  factory RoutineModel.fromJson(Map<String, dynamic> json) {
    final stepsJson = json['steps'];
    return RoutineModel(
      id: json['id'] as int,
      titulo: (json['titulo'] ?? '').toString(),
      lembrete: json['lembrete']?.toString(),
      userId: json['user_id'] as int?,
      userName: json['user_name']?.toString(),
      passos: stepsJson is List
          ? stepsJson
              .whereType<Map<String, dynamic>>()
              .map(RoutineStepModel.fromJson)
              .toList()
          : <RoutineStepModel>[],
    );
  }

  RoutineModel copy() => RoutineModel(
        id: id,
        titulo: titulo,
        lembrete: lembrete,
        passos: passos.map((e) => e.copy()).toList(),
      );

  int get totalPassos => passos.length;
}

class RoutineStepModel {
  RoutineStepModel({
    required this.id,
    required this.descricao,
    this.duracao,
    this.ordem = 0,
    this.concluido = false,
  });

  final int id;
  String descricao;
  int? duracao;
  int ordem;
  bool concluido;

  factory RoutineStepModel.fromJson(Map<String, dynamic> json) {
    return RoutineStepModel(
      id: json['id'] as int,
      descricao: (json['descricao'] ?? '').toString(),
      duracao: json['duracao'] is int ? json['duracao'] as int : (json['duracao'] is String ? int.tryParse(json['duracao']) : null),
      ordem: json['ordem'] is int ? json['ordem'] as int : (json['ordem'] is String ? int.tryParse(json['ordem']) ?? 0 : 0),
    );
  }

  RoutineStepModel copy() => RoutineStepModel(
        id: id,
        descricao: descricao,
        duracao: duracao,
        ordem: ordem,
        concluido: concluido,
      );
}









