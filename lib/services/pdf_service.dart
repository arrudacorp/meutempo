import 'dart:io';
import 'package:meutempo/models/projeto.dart';
import 'package:meutempo/models/tempo_gasto.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class PeriodoPDF {
  final DateTime inicio;
  final DateTime fim;

  PeriodoPDF({required this.inicio, required this.fim});
}

class PdfService {
  static Future<pw.Document> generateRelatorioPDF({
    required Map<String, double> tempoPorProjeto,
    required Map<String, double> tempoPorDia,
    required double totalHoras,
    required int totalRegistros,
    required String projetoMaisUsado,
    required double mediaDiaria,
    required PeriodoPDF periodo,
    required String nomeUsuario,
    required List<TempoGasto> registros,
    required List<Projeto> listaProjetos,
    String? projetoFiltro,
  }) async {
    final pdf = pw.Document();

    try {
      // FUNÇÃO DE SEGURANÇA - APENAS REMOVE O ESSENCIAL
      String safeText(String text) {
        if (text.isEmpty) return text;
        // Remove apenas o caractere problemático U+FE0F
        return text.replaceAll('️', '').trim();
      }

      // LIMITAR REGISTROS PARA EVITAR QUALQUER PROBLEMA
      final maxRegistrosExibidos = 50; // Máximo seguro
      final registrosExibidos = registros.length > maxRegistrosExibidos
          ? registros.sublist(0, maxRegistrosExibidos)
          : registros;

      final mostrarAviso = registros.length > maxRegistrosExibidos;

      final registrosPorPagina = 20; // Ajuste conforme necessidade
      final totalPaginas = (registrosExibidos.length / registrosPorPagina)
          .ceil();

      for (var pagina = 0; pagina < totalPaginas; pagina++) {
        final inicio = pagina * registrosPorPagina;
        final fim = (pagina + 1) * registrosPorPagina;
        final registrosDaPagina = registrosExibidos.sublist(
          inicio,
          fim > registrosExibidos.length ? registrosExibidos.length : fim,
        );

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(25),
            build: (context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // CABEÇALHO (igual ao original)
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'RELATÓRIO DE PRODUTIVIDADE',
                            style: pw.TextStyle(
                              fontSize: 18,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            'Usuário: ${safeText(nomeUsuario)}',
                            style: const pw.TextStyle(fontSize: 11),
                          ),
                          if (projetoFiltro != null)
                            pw.Text(
                              'Projeto: ${safeText(projetoFiltro)}',
                              style: const pw.TextStyle(fontSize: 11),
                            ),
                          pw.Text(
                            'Período: ${DateFormat('dd/MM/yyyy').format(periodo.inicio)} - ${DateFormat('dd/MM/yyyy').format(periodo.fim)}',
                            style: const pw.TextStyle(fontSize: 10),
                          ),
                          pw.Text(
                            'Gerado em: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                            style: const pw.TextStyle(fontSize: 9),
                          ),
                        ],
                      ),
                      // ÍCONE SIMPLES (sem emoji)
                      pw.Container(
                        width: 40,
                        height: 40,
                        decoration: const pw.BoxDecoration(
                          color: PdfColors.blue,
                          shape: pw.BoxShape.circle,
                        ),
                        child: pw.Center(
                          child: pw.Text(
                            'A',
                            style: pw.TextStyle(
                              fontSize: 16,
                              color: PdfColors.white,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  pw.Divider(height: 25),

                  // APENAS para a primeira página, mostrar estatísticas
                  if (pagina == 0) ...[
                    pw.Text(
                      'ESTATÍSTICAS GERAIS',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 25),

                    // Cards de estatísticas em linha
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        _buildCardEstatistica(
                          'Total Horas',
                          '${totalHoras.toStringAsFixed(1)}h',
                          PdfColors.blue50,
                        ),
                        _buildCardEstatistica(
                          'Total Registros',
                          totalRegistros.toString(),
                          PdfColors.green50,
                        ),
                        _buildCardEstatistica(
                          'Média Diária',
                          '${mediaDiaria.toStringAsFixed(1)}h',
                          PdfColors.purple50,
                        ),
                      ],
                    ),
                  ],

                  pw.SizedBox(height: 25),

                  // TÍTULO DA TABELA
                  pw.Text(
                    'REGISTROS DETALHADOS',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),

                  /*pw.Text(
                    'Página ${pagina + 1}/$totalPaginas | Total: ${registrosExibidos.length} registros',
                    style: const pw.TextStyle(fontSize: 11),
                  ),*/
                  pw.SizedBox(height: 15),

                  // TABELA APENAS COM OS REGISTROS DESTA PÁGINA
                  if (registrosDaPagina.isNotEmpty)
                    _buildTabelaRegistrosSimples(
                      registros: registrosDaPagina,
                      projetos: listaProjetos,
                    ),
                ],
              );
            },
          ),
        );
      }

      return pdf;
    } catch (e, stack) {
      print('Erro crítico ao gerar PDF: $e');
      print(stack);

      // FALLBACK ABSOLUTO
      return _gerarPDFMinimo(
        totalHoras: totalHoras,
        totalRegistros: totalRegistros,
        periodo: periodo,
        nomeUsuario: nomeUsuario,
      );
    }
  }

  // ========== COMPONENTES AUXILIARES ==========

  static pw.Widget _buildCardEstatistica(
    String titulo,
    String valor,
    PdfColor corFundo,
  ) {
    return pw.Container(
      width: 100,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: corFundo,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            titulo,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey700,
            ),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            valor,
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildTabelaRegistrosSimples({
    required List<TempoGasto> registros,
    required List<Projeto> projetos,
  }) {
    // Ordenar por data (mais recente primeiro)
    final registrosOrdenados = List<TempoGasto>.from(registros)
      ..sort((a, b) => b.dataHoraIni.compareTo(a.dataHoraIni));

    return pw.Container(
      height: 550,
      child: pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
        columnWidths: {
          0: const pw.FlexColumnWidth(1.2), // Data
          1: const pw.FlexColumnWidth(1.8), // Projeto
          2: const pw.FlexColumnWidth(1), // Início
          3: const pw.FlexColumnWidth(1), // Fim
          4: const pw.FlexColumnWidth(1), // Duração
          5: const pw.FlexColumnWidth(2), // Observação
        },
        children: [
          // CABEÇALHO
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.grey200),
            children: [
              _celulaTabela('Data', isHeader: true),
              _celulaTabela('Projeto', isHeader: true),
              _celulaTabela('Início', isHeader: true),
              _celulaTabela('Fim', isHeader: true),
              _celulaTabela('Duração', isHeader: true),
              _celulaTabela('Observação', isHeader: true),
            ],
          ),

          // DADOS
          for (var i = 0; i < registrosOrdenados.length; i++)
            pw.TableRow(
              decoration: pw.BoxDecoration(
                color: i.isEven ? PdfColors.white : PdfColors.grey50,
              ),
              children: [
                _celulaTabela(
                  DateFormat(
                    'dd/MM/yy',
                  ).format(registrosOrdenados[i].dataHoraIni),
                ),
                _celulaTabela(
                  _getNomeProjetoSeguro(
                    registrosOrdenados[i].idProjeto,
                    projetos,
                  ),
                  maxLines: 2,
                ),
                _celulaTabela(
                  DateFormat('HH:mm').format(registrosOrdenados[i].dataHoraIni),
                ),
                _celulaTabela(
                  registrosOrdenados[i].dataHoraFim != null
                      ? DateFormat(
                          'HH:mm',
                        ).format(registrosOrdenados[i].dataHoraFim!)
                      : 'Em andamento',
                  color: registrosOrdenados[i].dataHoraFim != null
                      ? null
                      : PdfColors.orange,
                ),
                _celulaTabela(_calcularDuracaoSegura(registrosOrdenados[i])),
                _celulaTabela(
                  registrosOrdenados[i].observacao ?? '-',
                  maxLines: 2,
                ),
              ],
            ),
        ],
      ),
    );
  }

  static pw.Widget _celulaTabela(
    String texto, {
    bool isHeader = false,
    PdfColor? color,
    int maxLines = 1,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        texto,
        style: pw.TextStyle(
          fontSize: isHeader ? 9 : 8,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color,
        ),
        maxLines: maxLines,
      ),
    );
  }

  static String _getNomeProjetoSeguro(int idProjeto, List<Projeto> projetos) {
    try {
      final projeto = projetos.firstWhere((p) => p.id == idProjeto);
      // Limitar tamanho para não quebrar layout
      if (projeto.nomeProjeto.length > 25) {
        return '${projeto.nomeProjeto.substring(0, 22)}...';
      }
      return projeto.nomeProjeto;
    } catch (e) {
      return 'Projeto $idProjeto';
    }
  }

  static String _calcularDuracaoSegura(TempoGasto registro) {
    if (registro.dataHoraFim == null) return '-';

    final duracao = registro.dataHoraFim!.difference(registro.dataHoraIni);
    final horas = duracao.inHours;
    final minutos = duracao.inMinutes.remainder(60);

    if (horas == 0) return '${minutos}m';
    if (minutos == 0) return '${horas}h';
    return '${horas}h ${minutos}m';
  }

  // FALLBACK ABSOLUTO
  static Future<pw.Document> _gerarPDFMinimo({
    required double totalHoras,
    required int totalRegistros,
    required PeriodoPDF periodo,
    required String nomeUsuario,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (context) {
          return pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(
                  'RELATÓRIO RESUMIDO',
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 30),
                pw.Text(
                  'Usuário: $nomeUsuario',
                  style: const pw.TextStyle(fontSize: 14),
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  'Período: ${DateFormat('dd/MM/yyyy').format(periodo.inicio)} a ${DateFormat('dd/MM/yyyy').format(periodo.fim)}',
                  style: const pw.TextStyle(fontSize: 14),
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  'Total de Horas: ${totalHoras.toStringAsFixed(1)}h',
                  style: const pw.TextStyle(fontSize: 16),
                ),
                pw.Text(
                  'Total de Registros: $totalRegistros',
                  style: const pw.TextStyle(fontSize: 16),
                ),
                pw.SizedBox(height: 30),
                pw.Text(
                  'Gerado em: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                  style: const pw.TextStyle(fontSize: 12),
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf;
  }

  static Future<File> savePdf(pw.Document pdf, String fileName) async {
    final bytes = await pdf.save();
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes);
    return file;
  }
}
