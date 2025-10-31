import 'package:flutter/material.dart';
import 'package:meutempo/models/projeto.dart';
import 'package:meutempo/models/projeto_dao.dart';
import 'package:meutempo/models/tempo_gasto.dart';
import 'package:meutempo/models/tempo_gasto_dao.dart';
import 'package:meutempo/models/usuario_dao.dart';
import 'package:meutempo/screens/cadastro_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _pinController = TextEditingController();
  final UsuarioDao _usuarioDao = UsuarioDao();
  final ProjetoDao _projetoDao = ProjetoDao();
  final TempoGastoDao _tempoGastoDao = TempoGastoDao();

  int? _projetoSelecionado;
  List<Projeto> _projetos = [];
  TempoGasto? _registroEmAndamento;

  @override
  void initState() {
    super.initState();
    _carregarProjetos();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _verificarNotificacoes();
    });
  }

  Future<void> _verificarNotificacoes() async {
    try {
      // Verificar se há registros em andamento para notificar
      // Isso pode ser expandido para verificar todos os usuários
      final usuario = await _usuarioDao.getUsuarioByPin('1234'); // Exemplo
      if (usuario != null) {
        final registro = await _tempoGastoDao.getRegistroEmAndamento(
          usuario.id!,
        );
        if (registro != null) {
          // await NotificationService().showRegistroEmAndamentoNotification();
        }
      }
    } catch (e) {
      print('Erro ao verificar notificações: $e');
    }
  }

  Future<void> _carregarProjetos() async {
    try {
      final projetos = await _projetoDao.getProjetosAtivos();
      setState(() {
        _projetos = projetos;
      });
    } catch (e) {
      print('Erro ao carregar projetos: $e');
    }
  }

  Future<void> _verificarRegistroEmAndamento(String pin) async {
    try {
      final usuario = await _usuarioDao.getUsuarioByPin(pin);
      if (usuario != null) {
        final registro = await _tempoGastoDao.getRegistroEmAndamento(
          usuario.id!,
        );
        setState(() {
          _registroEmAndamento = registro;
        });
      }
    } catch (e) {
      print('Erro ao verificar registro em andamento: $e');
    }
  }

  Future<void> _iniciarTrabalho() async {
    if (_pinController.text.isEmpty || _projetoSelecionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha o PIN e selecione um projeto')),
      );
      return;
    }

    try {
      final usuario = await _usuarioDao.getUsuarioByPin(_pinController.text);
      if (usuario == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('PIN inválido')));
        return;
      }

      // Verificar se já existe um registro em andamento
      final registroExistente = await _tempoGastoDao.getRegistroEmAndamento(
        usuario.id!,
      );
      if (registroExistente != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Já existe um registro em andamento. Finalize-o primeiro.',
            ),
          ),
        );
        return;
      }

      // Criar novo registro
      final novoTempoGasto = TempoGasto(
        idProjeto: _projetoSelecionado!,
        idUsuario: usuario.id!,
        dataHoraIni: DateTime.now(),
        observacao: null,
      );

      await _tempoGastoDao.insertTempoGasto(novoTempoGasto);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trabalho iniciado com sucesso!')),
      );

      // Limpar campos
      _pinController.clear();
      setState(() {
        _projetoSelecionado = null;
        _registroEmAndamento = novoTempoGasto;
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao iniciar trabalho: $e')));
    }
  }

  Future<void> _finalizarTrabalho() async {
    if (_registroEmAndamento == null) return;

    try {
      await _tempoGastoDao.finalizarRegistro(_registroEmAndamento!.id!);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trabalho finalizado com sucesso!')),
      );

      setState(() {
        _registroEmAndamento = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao finalizar trabalho: $e')));
    }
  }

  Widget _buildRegistroEmAndamento() {
    if (_registroEmAndamento == null) return const SizedBox();

    final projeto = _projetos.firstWhere(
      (p) => p.id == _registroEmAndamento!.idProjeto,
      orElse: () => Projeto(id: 0, nomeProjeto: 'Desconhecido', ativo: true),
    );

    return Card(
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Registro em Andamento',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 10),
            Text('Projeto: ${projeto.nomeProjeto}'),
            Text('Início: ${_registroEmAndamento!.dataHoraIni.toString()}'),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _finalizarTrabalho,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('FINALIZAR TRABALHO'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meu Tempo'),
        backgroundColor: Colors.blue.shade50,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CadastroScreen()),
              );
            },
            tooltip: 'Cadastrar',
          ),
          IconButton(
            icon: const Icon(Icons.login),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            const Text(
              'Iniciar Trabalho',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),

            // Registro em andamento
            _buildRegistroEmAndamento(),
            if (_registroEmAndamento != null) const SizedBox(height: 20),

            TextField(
              controller: _pinController,
              decoration: const InputDecoration(
                labelText: 'PIN',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.pin),
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                if (value.length == 4) {
                  _verificarRegistroEmAndamento(value);
                }
              },
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<int>(
              value: _projetoSelecionado,
              decoration: const InputDecoration(
                labelText: 'Projeto',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.work),
              ),
              items: _projetos.map((projeto) {
                return DropdownMenuItem<int>(
                  value: projeto.id,
                  child: Text(projeto.nomeProjeto),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _projetoSelecionado = value;
                });
              },
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _iniciarTrabalho,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.blue,
              ),
              child: const Text(
                'INICIAR TRABALHO',
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
