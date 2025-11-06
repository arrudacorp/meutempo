import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:meutempo/models/tempo_gasto_dao.dart';
import 'package:meutempo/models/projeto_dao.dart';
import 'package:meutempo/models/tempo_gasto.dart';
import 'package:meutempo/models/projeto.dart';
import 'package:meutempo/models/auth_service.dart';
import 'package:meutempo/services/pdf_service.dart';

class RelatoriosScreen extends StatefulWidget {
  const RelatoriosScreen({Key? key}) : super(key: key);

  @override
  State<RelatoriosScreen> createState() => _RelatoriosScreenState();
}

class _RelatoriosScreenState extends State<RelatoriosScreen> {
  final TempoGastoDao _tempoGastoDao = TempoGastoDao();
  final ProjetoDao _projetoDao = ProjetoDao();

  List<TempoGasto> _registros = [];
  List<Projeto> _projetos = [];
  bool _carregando = true;
  DateTimeRange _periodoSelecionado = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now(),
  );
  int? _projetoFiltro; // null = todos os projetos
  bool _mostrarFiltros = false;

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    try {
      final usuario = AuthService.getUsuarioLogado();
      if (usuario != null) {
        final registros = await _tempoGastoDao.getTempoGastoByUsuario(
          usuario.id!,
        );
        final projetos = await _projetoDao.getProjetosAtivos();

        setState(() {
          _registros = registros;
          _projetos = projetos;
          _carregando = false;
        });
      }
    } catch (e) {
      print('Erro ao carregar dados: $e');
      setState(() {
        _carregando = false;
      });
    }
  }

  Future<void> _selecionarPeriodo() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _periodoSelecionado,
    );

    if (picked != null) {
      setState(() {
        _periodoSelecionado = picked;
      });
    }
  }

  List<TempoGasto> _getRegistrosFiltrados() {
    return _registros.where((registro) {
      final dentroPeriodo =
          registro.dataHoraIni.isAfter(_periodoSelecionado.start) &&
          registro.dataHoraIni.isBefore(
            _periodoSelecionado.end.add(const Duration(days: 1)),
          );

      final projetoCorreto =
          _projetoFiltro == null || registro.idProjeto == _projetoFiltro;

      return dentroPeriodo && projetoCorreto;
    }).toList();
  }

  Map<String, double> _calcularTempoPorProjeto() {
    final registrosFiltrados = _getRegistrosFiltrados();
    final Map<String, double> tempoPorProjeto = {};

    for (final registro in registrosFiltrados) {
      if (registro.dataHoraFim != null) {
        final projeto = _projetos.firstWhere(
          (p) => p.id == registro.idProjeto,
          orElse: () =>
              Projeto(id: 0, nomeProjeto: 'Desconhecido', ativo: true),
        );

        final duracao =
            registro.dataHoraFim!.difference(registro.dataHoraIni).inMinutes /
            60.0;
        final nomeProjeto = projeto.nomeProjeto;

        tempoPorProjeto[nomeProjeto] =
            (tempoPorProjeto[nomeProjeto] ?? 0) + duracao;
      }
    }

    return tempoPorProjeto;
  }

  Map<String, double> _calcularTempoPorDia() {
    final registrosFiltrados = _getRegistrosFiltrados();
    final Map<String, double> tempoPorDia = {};

    for (final registro in registrosFiltrados) {
      if (registro.dataHoraFim != null) {
        final data = DateFormat('dd/MM').format(registro.dataHoraIni);
        final duracao =
            registro.dataHoraFim!.difference(registro.dataHoraIni).inMinutes /
            60.0;

        tempoPorDia[data] = (tempoPorDia[data] ?? 0) + duracao;
      }
    }

    return tempoPorDia;
  }

  double _calcularTotalHoras() {
    final tempoPorProjeto = _calcularTempoPorProjeto();
    return tempoPorProjeto.values.fold(0.0, (sum, horas) => sum + horas);
  }

  int _calcularTotalRegistros() {
    return _getRegistrosFiltrados().where((r) => r.dataHoraFim != null).length;
  }

  String _getProjetoMaisUsado() {
    final tempoPorProjeto = _calcularTempoPorProjeto();
    if (tempoPorProjeto.isEmpty) return 'Nenhum';

    final entry = tempoPorProjeto.entries.reduce(
      (a, b) => a.value > b.value ? a : b,
    );
    return entry.key;
  }

  String _getNomeProjetoFiltro() {
    if (_projetoFiltro == null) return 'Todos os Projetos';
    final projeto = _projetos.firstWhere(
      (p) => p.id == _projetoFiltro,
      orElse: () => Projeto(id: 0, nomeProjeto: 'Desconhecido', ativo: true),
    );
    return projeto.nomeProjeto;
  }

  Widget _buildCardEstatistica(
    String titulo,
    String valor,
    IconData icone,
    Color cor,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icone, size: 30, color: cor),
            const SizedBox(height: 8),
            Text(
              titulo,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            Text(
              valor,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGraficoBarrasHorizontais() {
    final tempoPorProjeto = _calcularTempoPorProjeto();

    if (tempoPorProjeto.isEmpty) {
      return _buildPlaceholder(
        'Nenhum dado disponível para o período e filtros selecionados',
      );
    }

    final dados = tempoPorProjeto.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final maxHoras = dados.map((e) => e.value).reduce((a, b) => a > b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tempo por Projeto',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Column(
              children: dados.map((entry) {
                final porcentagem = entry.value / maxHoras;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              entry.key,
                              style: const TextStyle(fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            _formatarDuracao(entry.value),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Container(
                        height: 20,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: Colors.grey[200],
                        ),
                        child: Stack(
                          children: [
                            Container(
                              height: 20,
                              width:
                                  MediaQuery.of(context).size.width *
                                  porcentagem *
                                  0.7,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.blue.shade400,
                                    Colors.blue.shade600,
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGraficoBarrasVerticais() {
    final tempoPorDia = _calcularTempoPorDia();

    if (tempoPorDia.isEmpty) {
      return const SizedBox();
    }

    final dados = tempoPorDia.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    // Pegar apenas os últimos 7 dias para não ficar poluído
    final dadosRecentes = dados.length > 7
        ? dados.sublist(dados.length - 7)
        : dados;
    final maxHoras = dadosRecentes
        .map((e) => e.value)
        .reduce((a, b) => a > b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tempo por Dia (Últimos 7 dias)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: dadosRecentes.map((entry) {
                  final altura = maxHoras > 0
                      ? (entry.value / maxHoras) * 150
                      : 0;
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        width: 30,
                        height: double.parse(altura.toString()),
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(4),
                            topRight: Radius.circular(4),
                          ),
                          gradient: LinearGradient(
                            colors: [
                              Colors.green.shade400,
                              Colors.green.shade600,
                            ],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            entry.value.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(entry.key, style: const TextStyle(fontSize: 10)),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDistribuicaoTempo() {
    final tempoPorProjeto = _calcularTempoPorProjeto();

    if (tempoPorProjeto.isEmpty) {
      return const SizedBox();
    }

    final totalHoras = _calcularTotalHoras();
    final cores = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.amber,
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Distribuição do Tempo',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Column(
              children: tempoPorProjeto.entries.toList().asMap().entries.map((
                entry,
              ) {
                final index = entry.key;
                final projeto = entry.value;
                final porcentagem = (projeto.value / totalHoras * 100);
                final cor = cores[index % cores.length];

                return ListTile(
                  leading: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: cor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  title: Text(projeto.key),
                  trailing: Text(
                    '${porcentagem.toStringAsFixed(1)}%',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(_formatarDuracao(projeto.value)),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder(String mensagem) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          children: [
            Icon(Icons.bar_chart, size: 50, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              mensagem,
              style: TextStyle(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFiltros() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filtros',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Filtro de Projeto
            DropdownButtonFormField<int>(
              value: _projetoFiltro,
              decoration: const InputDecoration(
                labelText: 'Projeto',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.filter_list),
              ),
              items: [
                const DropdownMenuItem<int>(
                  value: null,
                  child: Text('Todos os Projetos'),
                ),
                ..._projetos.map((projeto) {
                  return DropdownMenuItem<int>(
                    value: projeto.id,
                    child: Text(projeto.nomeProjeto),
                  );
                }).toList(),
              ],
              onChanged: (value) {
                setState(() {
                  _projetoFiltro = value;
                });
              },
            ),

            const SizedBox(height: 16),

            // Período
            InkWell(
              onTap: _selecionarPeriodo,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, color: Colors.blue),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Período',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          Text(
                            '${DateFormat('dd/MM/yyyy').format(_periodoSelecionado.start)} - ${DateFormat('dd/MM/yyyy').format(_periodoSelecionado.end)}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down, color: Colors.grey),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatarDuracao(double horasDecimais) {
    if (horasDecimais == 0) return '0h';

    final horas = horasDecimais.floor();
    final minutos = ((horasDecimais - horas) * 60).round();

    // Ajuste para casos como 1.99 horas que dariam 1h 60m
    final minutosAjustados = minutos >= 60 ? 0 : minutos;
    final horasAjustadas = minutos >= 60 ? horas + 1 : horas;

    if (horasAjustadas == 0) {
      return '${minutosAjustados}m';
    } else if (minutosAjustados == 0) {
      return '${horasAjustadas}h';
    } else {
      return '${horasAjustadas}h ${minutosAjustados}m';
    }
  }

  Future<void> _exportarPDF() async {
    try {
      final tempoPorProjeto = _calcularTempoPorProjeto();
      final tempoPorDia = _calcularTempoPorDia();
      final totalHoras = _calcularTotalHoras();
      final totalRegistros = _calcularTotalRegistros();
      final projetoMaisUsado = _getProjetoMaisUsado();
      final mediaDiaria = _calcularTotalHoras() > 0
          ? (_calcularTotalHoras() / _periodoSelecionado.duration.inDays)
          : 0.0;

      // Obter nome do usuário logado
      final usuario = AuthService.getUsuarioLogado();
      final nomeUsuario = usuario?.nome ?? 'Usuário';

      final periodoPDF = PeriodoPDF(
        inicio: _periodoSelecionado.start,
        fim: _periodoSelecionado.end,
      );

      final pdf = await PdfService.generateRelatorioPDF(
        tempoPorProjeto: tempoPorProjeto,
        tempoPorDia: tempoPorDia,
        totalHoras: totalHoras,
        totalRegistros: totalRegistros,
        projetoMaisUsado: projetoMaisUsado,
        mediaDiaria: mediaDiaria,
        periodo: periodoPDF,
        nomeUsuario: nomeUsuario,
        projetoFiltro: _projetoFiltro != null
            ? _getNomeProjetoFiltro()
            : null, // NOVO PARÂMETRO
      );

      // Mostrar preview e opções de compartilhamento
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao gerar PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Relatórios'),
        backgroundColor: Colors.blue.shade50,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              setState(() {
                _mostrarFiltros = !_mostrarFiltros;
              });
            },
            tooltip: 'Filtros',
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _exportarPDF,
            tooltip: 'Exportar PDF',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _carregarDados,
            tooltip: 'Atualizar',
          ),
        ],
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Informações do filtro atual
                  if (_projetoFiltro != null || _mostrarFiltros)
                    Card(
                      color: Colors.blue.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.info_outline,
                              color: Colors.blue,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _projetoFiltro == null
                                    ? 'Mostrando todos os projetos'
                                    : 'Filtrado por: ${_getNomeProjetoFiltro()}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 8),

                  // Filtros (expandível)
                  if (_mostrarFiltros) _buildFiltros(),

                  if (_mostrarFiltros) const SizedBox(height: 16),

                  // Estatísticas rápidas
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 1.5,
                    children: [
                      _buildCardEstatistica(
                        'Total Horas',
                        _formatarDuracao(_calcularTotalHoras()),
                        Icons.access_time,
                        Colors.blue,
                      ),
                      _buildCardEstatistica(
                        'Total Registros',
                        _calcularTotalRegistros().toString(),
                        Icons.list_alt,
                        Colors.green,
                      ),
                      _buildCardEstatistica(
                        'Projeto Mais Usado',
                        _getProjetoMaisUsado(),
                        Icons.star,
                        Colors.orange,
                      ),
                      _buildCardEstatistica(
                        'Média Diária',
                        _calcularTotalHoras() > 0
                            ? _formatarDuracao(
                                _calcularTotalHoras() /
                                    _periodoSelecionado.duration.inDays,
                              )
                            : '0h',
                        Icons.timeline,
                        Colors.purple,
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Gráficos
                  Expanded(
                    child: ListView(
                      children: [
                        _buildGraficoBarrasHorizontais(),
                        const SizedBox(height: 16),
                        _buildGraficoBarrasVerticais(),
                        const SizedBox(height: 16),
                        _buildDistribuicaoTempo(),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
