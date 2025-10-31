class Projeto {
  int? id;
  String nomeProjeto;
  bool ativo;

  Projeto({this.id, required this.nomeProjeto, required this.ativo});

  Map<String, dynamic> toMap() {
    return {'id': id, 'nome_projeto': nomeProjeto, 'ativo': ativo ? 1 : 0};
  }

  factory Projeto.fromMap(Map<String, dynamic> map) {
    return Projeto(
      id: map['id'],
      nomeProjeto: map['nome_projeto'],
      ativo: map['ativo'] == 1,
    );
  }
}
