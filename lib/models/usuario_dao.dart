import 'package:sqflite/sqflite.dart';
import 'database.dart';
import 'usuario.dart';

class UsuarioDao {
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  Future<Usuario?> login(String usuario, String senha) async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'usuario',
      where: 'usuario = ? AND senha = ?',
      whereArgs: [usuario, senha],
    );

    if (maps.isNotEmpty) {
      return Usuario.fromMap(maps.first);
    }
    return null;
  }

  Future<Usuario?> getUsuarioByPin(String pin) async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'usuario',
      where: 'usuario = ?',
      whereArgs: [pin],
    );

    if (maps.isNotEmpty) {
      return Usuario.fromMap(maps.first);
    }
    return null;
  }

  Future<List<Usuario>> getAllUsuarios() async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('usuario');
    return List.generate(maps.length, (i) {
      return Usuario.fromMap(maps[i]);
    });
  }

  Future<int> insertUsuario(Usuario usuario) async {
    final db = await _databaseHelper.database;
    return await db.insert('usuario', usuario.toMap());
  }
}
