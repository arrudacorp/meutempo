import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'controle_tempo.db');
    return await openDatabase(path, version: 1, onCreate: _createDatabase);
  }

  Future<void> _createDatabase(Database db, int version) async {
    // Tabela usuário
    await db.execute('''
      CREATE TABLE usuario(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nome TEXT NOT NULL,
        usuario TEXT NOT NULL UNIQUE,
        senha TEXT NOT NULL
      )
    ''');

    // Tabela projeto
    await db.execute('''
      CREATE TABLE projeto(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nome_projeto TEXT NOT NULL,
        ativo INTEGER NOT NULL DEFAULT 1
      )
    ''');

    // Tabela tempo_gasto
    await db.execute('''
      CREATE TABLE tempo_gasto(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        id_projeto INTEGER NOT NULL,
        id_usuario INTEGER NOT NULL,
        data_hora_ini TEXT NOT NULL,
        data_hora_fim TEXT,
        observacao TEXT,
        FOREIGN KEY (id_projeto) REFERENCES projeto (id),
        FOREIGN KEY (id_usuario) REFERENCES usuario (id)
      )
    ''');

    // Inserir dados iniciais
    await _insertInitialData(db);
  }

  Future<void> _insertInitialData(Database db) async {
    // Inserir usuário padrão
    await db.insert('usuario', {
      'nome': 'Usuário Teste',
      'usuario': '1234',
      'senha': '1234',
    });

    // Inserir alguns projetos
    await db.insert('projeto', {'nome_projeto': 'Projeto Alpha', 'ativo': 1});
    await db.insert('projeto', {'nome_projeto': 'Projeto Beta', 'ativo': 1});
    await db.insert('projeto', {'nome_projeto': 'Projeto Gamma', 'ativo': 1});
  }
}
