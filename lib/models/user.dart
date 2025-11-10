class User {
  final int? id;
  final String nomeCompleto;
  final String email;
  final String senha;
  final String? quemE;
  final String? preferenciasSensoriais;

  User({
    this.id,
    required this.nomeCompleto,
    required this.email,
    required this.senha,
    this.quemE,
    this.preferenciasSensoriais,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nomeCompleto': nomeCompleto,
      'email': email,
      'senha': senha,
      'quemE': quemE,
      'preferenciasSensoriais': preferenciasSensoriais,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] as int?,
      nomeCompleto: map['nomeCompleto'] as String,
      email: map['email'] as String,
      senha: map['senha'] as String,
      quemE: map['quemE'] as String?,
      preferenciasSensoriais: map['preferenciasSensoriais'] as String?,
    );
  }
}

