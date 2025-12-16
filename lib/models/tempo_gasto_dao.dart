import 'database.dart';
import 'tempo_gasto.dart';

class TempoGastoDao {
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  Future<int> insertTempoGasto(TempoGasto tempoGasto) async {
    final db = await _databaseHelper.database;
    return await db.insert('tempo_gasto', tempoGasto.toMap());
  }

  Future<int> deleteTempoGasto(int id) async {
    final db = await _databaseHelper.database;
    return await db.delete('tempo_gasto', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<TempoGasto>> getTempoGastoByUsuario(int idUsuario) async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'tempo_gasto',
      where: 'id_usuario = ?',
      whereArgs: [idUsuario],
      orderBy: 'data_hora_ini DESC',
    );
    return List.generate(maps.length, (i) {
      return TempoGasto.fromMap(maps[i]);
    });
  }

  Future<TempoGasto?> getRegistroEmAndamento(int idUsuario) async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'tempo_gasto',
      where: 'id_usuario = ? AND data_hora_fim IS NULL',
      whereArgs: [idUsuario],
      orderBy: 'data_hora_ini DESC',
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return TempoGasto.fromMap(maps.first);
    }
    return null;
  }

  Future<List<TempoGasto>> getRegistrosComProjeto(int idUsuario) async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.rawQuery(
      '''
      SELECT tg.*, p.nome_projeto 
      FROM tempo_gasto tg
      INNER JOIN projeto p ON tg.id_projeto = p.id
      WHERE tg.id_usuario = ?
      ORDER BY tg.data_hora_ini DESC
    ''',
      [idUsuario],
    );

    return List.generate(maps.length, (i) {
      final tempoGasto = TempoGasto.fromMap(maps[i]);
      // Adiciona o nome do projeto ao objeto (não mapeado automaticamente)
      return tempoGasto;
    });
  }

  Future<void> updateTempoGasto(TempoGasto tempoGasto) async {
    final db = await _databaseHelper.database;
    await db.update(
      'tempo_gasto',
      tempoGasto.toMap(),
      where: 'id = ?',
      whereArgs: [tempoGasto.id],
    );
  }

  Future<void> finalizarRegistro(int id) async {
    final db = await _databaseHelper.database;
    await db.update(
      'tempo_gasto',
      {'data_hora_fim': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Adicione este método ao TempoGastoDao
  Future<List<Map<String, dynamic>>> getRegistrosComDetalhes(
    int idUsuario,
  ) async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.rawQuery(
      '''
    SELECT 
      tg.*, 
      p.nome_projeto,
      u.nome as nome_usuario
    FROM tempo_gasto tg
    INNER JOIN projeto p ON tg.id_projeto = p.id
    INNER JOIN usuario u ON tg.id_usuario = u.id
    WHERE tg.id_usuario = ?
    ORDER BY tg.data_hora_ini DESC
  ''',
      [idUsuario],
    );

    return maps;
  }
}
