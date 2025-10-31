class Usuario {
  int? id;
  String nome;
  String usuario;
  String senha;

  Usuario({
    this.id,
    required this.nome,
    required this.usuario,
    required this.senha,
  });

  Map<String, dynamic> toMap() {
    return {'id': id, 'nome': nome, 'usuario': usuario, 'senha': senha};
  }

  factory Usuario.fromMap(Map<String, dynamic> map) {
    return Usuario(
      id: map['id'],
      nome: map['nome'],
      usuario: map['usuario'],
      senha: map['senha'],
    );
  }
}
