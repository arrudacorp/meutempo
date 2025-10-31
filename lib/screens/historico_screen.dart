import 'package:flutter/material.dart';
import 'package:meutempo/models/auth_service.dart';
import 'package:meutempo/models/tempo_gasto_dao.dart';
import 'package:meutempo/models/projeto_dao.dart';
import 'package:meutempo/models/tempo_gasto.dart';
import 'package:meutempo/models/projeto.dart';

class HistoricoScreen extends StatefulWidget {
  const HistoricoScreen({Key? key}) : super(key: key);

  @override
  State<HistoricoScreen> createState() => _HistoricoScreenState();
}

class _HistoricoScreenState extends State<HistoricoScreen> {
  final TempoGastoDao _tempoGastoDao = TempoGastoDao();
  final ProjetoDao _projetoDao = ProjetoDao();

  List<TempoGasto> _registros = [];
  List<Projeto> _projetos = [];
  bool _carregando = true;
  //int _usuarioLogadoId = 1; // TODO: Pegar do usuário logado

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  int get _usuarioLogadoId {
    final usuario = AuthService.getUsuarioLogado();
    return usuario?.id ?? 1; // Fallback para teste
  }

  Future<void> _carregarDados() async {
    try {
      final registros = await _tempoGastoDao.getTempoGastoByUsuario(
        _usuarioLogadoId,
      );
      final projetos = await _projetoDao.getAllProjetos();

      setState(() {
        _registros = registros;
        _projetos = projetos;
        _carregando = false;
      });
    } catch (e) {
      print('Erro ao carregar dados: $e');
      setState(() {
        _carregando = false;
      });
    }
  }

  String _formatarData(DateTime data) {
    return '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year} ${data.hour.toString().padLeft(2, '0')}:${data.minute.toString().padLeft(2, '0')}';
  }

  String _calcularDuracao(DateTime inicio, DateTime? fim) {
    if (fim == null) return 'Em andamento';

    final duracao = fim.difference(inicio);
    final horas = duracao.inHours;
    final minutos = duracao.inMinutes.remainder(60);

    return '${horas}h ${minutos}m';
  }

  String _getNomeProjeto(int idProjeto) {
    try {
      final projeto = _projetos.firstWhere((p) => p.id == idProjeto);
      return projeto.nomeProjeto;
    } catch (e) {
      return 'Projeto não encontrado';
    }
  }

  Future<void> _finalizarRegistro(int id) async {
    try {
      await _tempoGastoDao.finalizarRegistro(id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registro finalizado com sucesso!')),
      );
      await _carregarDados(); // Recarregar a lista
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao finalizar registro: $e')));
    }
  }

  void _editarRegistro(TempoGasto registro) {
    _mostrarDialogoEdicao(registro);
  }

  Future<void> _mostrarDialogoEdicao(TempoGasto registro) async {
    final observacaoController = TextEditingController(
      text: registro.observacao,
    );
    DateTime? dataHoraIni = registro.dataHoraIni;
    DateTime? dataHoraFim = registro.dataHoraFim;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar Registro'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text('Projeto: ${_getNomeProjeto(registro.idProjeto)}'),
              ),
              ListTile(
                title: const Text('Data/Hora Início'),
                subtitle: Text(_formatarData(registro.dataHoraIni)),
              ),
              if (registro.dataHoraFim != null)
                ListTile(
                  title: const Text('Data/Hora Fim'),
                  subtitle: Text(_formatarData(registro.dataHoraFim!)),
                ),
              TextField(
                controller: observacaoController,
                decoration: const InputDecoration(
                  labelText: 'Observação',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final registroAtualizado = TempoGasto(
                  id: registro.id,
                  idProjeto: registro.idProjeto,
                  idUsuario: registro.idUsuario,
                  dataHoraIni: registro.dataHoraIni,
                  dataHoraFim: registro.dataHoraFim,
                  observacao: observacaoController.text.isEmpty
                      ? null
                      : observacaoController.text,
                );

                await _tempoGastoDao.updateTempoGasto(registroAtualizado);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Registro atualizado com sucesso!'),
                  ),
                );
                await _carregarDados();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Erro ao atualizar registro: $e')),
                );
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  Widget _buildItemRegistro(TempoGasto registro) {
    final bool finalizado = registro.dataHoraFim != null;
    final String duracao = _calcularDuracao(
      registro.dataHoraIni,
      registro.dataHoraFim,
    );
    final String nomeProjeto = _getNomeProjeto(registro.idProjeto);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    nomeProjeto,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: finalizado
                        ? Colors.green.shade50
                        : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    finalizado ? 'Finalizado' : 'Em Andamento',
                    style: TextStyle(
                      color: finalizado ? Colors.green : Colors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Início: ${_formatarData(registro.dataHoraIni)}',
              style: const TextStyle(fontSize: 14),
            ),
            if (finalizado) ...[
              Text(
                'Fim: ${_formatarData(registro.dataHoraFim!)}',
                style: const TextStyle(fontSize: 14),
              ),
              Text(
                'Duração: $duracao',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
            if (registro.observacao != null &&
                registro.observacao!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Observação: ${registro.observacao}',
                style: const TextStyle(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                if (!finalizado)
                  ElevatedButton(
                    onPressed: () => _finalizarRegistro(registro.id!),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: const Text(
                      'Finalizar',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  onPressed: () => _editarRegistro(registro),
                  tooltip: 'Editar',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Histórico de Registros',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (_carregando)
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Carregando registros...'),
                    ],
                  ),
                ),
              )
            else if (_registros.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.history,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Nenhum registro encontrado',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Comece criando seu primeiro registro',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _carregarDados,
                  child: ListView.builder(
                    itemCount: _registros.length,
                    itemBuilder: (context, index) {
                      final registro = _registros[index];
                      return _buildItemRegistro(registro);
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _carregarDados,
        child: const Icon(Icons.refresh),
      ),
    );
  }
}
