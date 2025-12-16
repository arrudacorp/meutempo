import 'database.dart';
import 'projeto.dart';

class ProjetoDao {
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  Future<int> insertProjeto(Projeto projeto) async {
    final db = await _databaseHelper.database;
    return await db.insert('projeto', projeto.toMap());
  }

  Future<List<Projeto>> getProjetosAtivos() async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'projeto',
      where: 'ativo = ?',
      whereArgs: [1],
    );
    return List.generate(maps.length, (i) {
      return Projeto.fromMap(maps[i]);
    });
  }

  Future<List<Projeto>> getAllProjetos() async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('projeto');
    return List.generate(maps.length, (i) {
      return Projeto.fromMap(maps[i]);
    });
  }

  Future<void> updateProjeto(Projeto projeto) async {
    final db = await _databaseHelper.database;
    await db.update(
      'projeto',
      projeto.toMap(),
      where: 'id = ?',
      whereArgs: [projeto.id],
    );
  }

  Future<void> deleteProjeto(int id) async {
    final db = await _databaseHelper.database;
    await db.delete('projeto', where: 'id = ?', whereArgs: [id]);
  }

  Future<Projeto?> getProjetoById(int id) async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'projeto',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return Projeto.fromMap(maps.first);
    }
    return null;
  }
}
