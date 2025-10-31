class TempoGasto {
  int? id;
  int idProjeto;
  int idUsuario;
  DateTime dataHoraIni;
  DateTime? dataHoraFim;
  String? observacao;

  TempoGasto({
    this.id,
    required this.idProjeto,
    required this.idUsuario,
    required this.dataHoraIni,
    this.dataHoraFim,
    this.observacao,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'id_projeto': idProjeto,
      'id_usuario': idUsuario,
      'data_hora_ini': dataHoraIni.toIso8601String(),
      'data_hora_fim': dataHoraFim?.toIso8601String(),
      'observacao': observacao,
    };
  }

  factory TempoGasto.fromMap(Map<String, dynamic> map) {
    return TempoGasto(
      id: map['id'],
      idProjeto: map['id_projeto'],
      idUsuario: map['id_usuario'],
      dataHoraIni: DateTime.parse(map['data_hora_ini']),
      dataHoraFim: map['data_hora_fim'] != null
          ? DateTime.parse(map['data_hora_fim'])
          : null,
      observacao: map['observacao'],
    );
  }
}
