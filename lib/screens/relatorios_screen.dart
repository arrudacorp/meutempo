import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:meutempo/models/tempo_gasto_dao.dart';
import 'package:meutempo/models/projeto_dao.dart';
import 'package:meutempo/models/tempo_gasto.dart';
import 'package:meutempo/models/projeto.dart';
import 'package:meutempo/models/auth_service.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
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

  @override
  void initState() {
    super.initState();
    _carregarDados();
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

  Future<void> _carregarDados() async {
    try {
      final usuario = AuthService.getUsuarioLogado();
      if (usuario != null) {
        final registros = await _tempoGastoDao.getTempoGastoByUsuario(
          usuario.id!,
        );
        final projetos = await _projetoDao.getAllProjetos();

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
      return registro.dataHoraIni.isAfter(_periodoSelecionado.start) &&
          registro.dataHoraIni.isBefore(
            _periodoSelecionado.end.add(const Duration(days: 1)),
          );
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
      return _buildPlaceholder('Nenhum dado disponível para o período');
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
                            '${entry.value.toStringAsFixed(1)}h',
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
                        height: altura.toDouble(),
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
                  subtitle: Text('${projeto.value.toStringAsFixed(1)} horas'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Relatórios'),
        backgroundColor: Colors.blue.shade50,
        elevation: 0,
        actions: [
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
                  // Cabeçalho com período
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, color: Colors.blue),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Período Selecionado',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                Text(
                                  '${DateFormat('dd/MM/yyyy').format(_periodoSelecionado.start)} - ${DateFormat('dd/MM/yyyy').format(_periodoSelecionado.end)}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.filter_list),
                            label: const Text('Filtrar'),
                            onPressed: _selecionarPeriodo,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Estatísticas rápidas
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 1.5,
                    children: [
                      _buildCardEstatistica(
                        'Total Horas',
                        _calcularTotalHoras().toStringAsFixed(1),
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
                            ? (_calcularTotalHoras() /
                                      _periodoSelecionado.duration.inDays)
                                  .toStringAsFixed(1)
                            : '0.0',
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
