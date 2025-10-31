import 'dart:io';
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
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (pw.Context context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 20),
            child: pw.Row(
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
                        color: PdfColors.blue800,
                      ),
                    ),
                    pw.SizedBox(height: 4),
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
                pw.Container(
                  width: 40,
                  height: 40,
                  decoration: pw.BoxDecoration(
                    color: PdfColors.blue,
                    shape: pw.BoxShape.circle,
                  ),
                  child: pw.Center(
                    child: pw.Text('⏱️', style: pw.TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
          );
        },
        footer: (pw.Context context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(top: 20),
            child: pw.Column(
              children: [
                pw.Divider(thickness: 1, color: PdfColors.grey300),
                pw.SizedBox(height: 10),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'MeuTempo - Sistema de Controle de Horas',
                      style: pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey600,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      'Desenvolvido por ArrudaCorp',
                      style: pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey600,
                        fontStyle: pw.FontStyle.italic,
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 5),
                pw.Text(
                  'Página ${context.pageNumber} de ${context.pagesCount}',
                  style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
                ),
              ],
            ),
          );
        },
        build: (pw.Context context) => [
          pw.SizedBox(height: 10),

          // Estatísticas Principais
          pw.Text(
            'ESTATÍSTICAS GERAIS',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue600,
            ),
          ),
          pw.SizedBox(height: 15),

          pw.Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildStatCard(
                'Total de Horas',
                '${totalHoras.toStringAsFixed(1)}h',
                _lightBlue,
              ),
              _buildStatCard(
                'Total Registros',
                totalRegistros.toString(),
                _lightGreen,
              ),
              _buildStatCard(
                'Projeto Mais Usado',
                _truncateText(projetoMaisUsado, 12),
                _lightOrange,
              ),
              _buildStatCard(
                'Média Diária',
                '${mediaDiaria.toStringAsFixed(1)}h',
                _lightPurple,
              ),
            ],
          ),

          pw.SizedBox(height: 25),

          // Tempo por Projeto
          pw.Text(
            'DISTRIBUIÇÃO POR PROJETO',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue600,
            ),
          ),
          pw.SizedBox(height: 15),

          _buildTabelaProjetos(tempoPorProjeto, totalHoras),

          pw.SizedBox(height: 25),

          // Gráfico de Barras Simples
          if (tempoPorProjeto.isNotEmpty) _buildGraficoBarras(tempoPorProjeto),

          pw.SizedBox(height: 25),

          // Detalhamento por Dia
          if (tempoPorDia.isNotEmpty) ...[
            pw.Text(
              'DETALHAMENTO POR DIA',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue600,
              ),
            ),
            pw.SizedBox(height: 15),
            _buildTabelaDias(tempoPorDia),
            pw.SizedBox(height: 25),
          ],

          // Resumo
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(15),
            decoration: pw.BoxDecoration(
              color: _lightBlue,
              borderRadius: pw.BorderRadius.circular(8),
              border: pw.Border.all(color: PdfColors.blue, width: 1),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'RESUMO EXECUTIVO',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue800,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'No período analisado, foram registradas ${totalHoras.toStringAsFixed(1)} horas '
                  'em $totalRegistros atividades. ${_getTextoResumo(projetoMaisUsado, totalHoras, mediaDiaria)}',
                  style: const pw.TextStyle(fontSize: 11),
                  textAlign: pw.TextAlign.justify,
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return pdf;
  }

  // Cores pré-definidas para evitar erros
  static final _lightBlue = PdfColor.fromInt(0xFFE3F2FD);
  static final _lightGreen = PdfColor.fromInt(0xFFE8F5E8);
  static final _lightOrange = PdfColor.fromInt(0xFFFFF3E0);
  static final _lightPurple = PdfColor.fromInt(0xFFF3E5F5);
  static final _blueDark = PdfColor.fromInt(0xFF1976D2);
  static final _greenDark = PdfColor.fromInt(0xFF388E3C);
  static final _orangeDark = PdfColor.fromInt(0xFFF57C00);
  static final _purpleDark = PdfColor.fromInt(0xFF7B1FA2);

  static pw.Widget _buildStatCard(
    String titulo,
    String valor,
    PdfColor corFundo,
  ) {
    // Determina a cor do texto baseado na cor de fundo
    final corTexto = _getCorTexto(corFundo);
    final corBorda = _getCorBorda(corFundo);

    return pw.Container(
      width: 110,
      height: 75,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: corFundo,
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: corBorda, width: 1.5),
      ),
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Text(
            titulo,
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: corTexto,
            ),
            textAlign: pw.TextAlign.center,
            maxLines: 2,
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            valor,
            style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.black,
            ),
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
    );
  }

  static PdfColor _getCorTexto(PdfColor corFundo) {
    if (corFundo == _lightBlue) return _blueDark;
    if (corFundo == _lightGreen) return _greenDark;
    if (corFundo == _lightOrange) return _orangeDark;
    if (corFundo == _lightPurple) return _purpleDark;
    return PdfColors.black;
  }

  static PdfColor _getCorBorda(PdfColor corFundo) {
    if (corFundo == _lightBlue) return PdfColors.blue;
    if (corFundo == _lightGreen) return PdfColors.green;
    if (corFundo == _lightOrange) return PdfColors.orange;
    if (corFundo == _lightPurple) return PdfColors.purple;
    return PdfColors.grey;
  }

  static pw.Widget _buildTabelaProjetos(
    Map<String, double> tempoPorProjeto,
    double totalHoras,
  ) {
    final projetos = tempoPorProjeto.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final tabelaDados = <List<String>>[
      <String>['Projeto', 'Horas', 'Percentual', 'Visual'],
    ];

    for (final projeto in projetos) {
      final percentual = (projeto.value / totalHoras * 100);
      final barras = (percentual ~/ 5); // Cada 5% = uma barra
      tabelaDados.add(<String>[
        _truncateText(projeto.key, 25),
        projeto.value.toStringAsFixed(1),
        '${percentual.toStringAsFixed(1)}%',
        '█' * barras,
      ]);
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(2.5),
        1: const pw.FlexColumnWidth(1),
        2: const pw.FlexColumnWidth(1),
        3: const pw.FlexColumnWidth(1.5),
      },
      children: [
        // Cabeçalho
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColors.blue700),
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(10),
              child: pw.Text(
                'PROJETO',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(10),
              child: pw.Text(
                'HORAS',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(10),
              child: pw.Text(
                '%',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(10),
              child: pw.Text(
                'VISUAL',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
              ),
            ),
          ],
        ),
        // Dados
        for (final linha in tabelaDados.skip(1))
          pw.TableRow(
            decoration: pw.BoxDecoration(
              color: linha == tabelaDados.skip(1).first
                  ? PdfColors.grey50
                  : PdfColors.white,
            ),
            children: [
              for (int i = 0; i < linha.length; i++)
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text(
                    linha[i],
                    style: pw.TextStyle(
                      fontSize: 9,
                      color: i == 0 ? _blueDark : PdfColors.black,
                      fontWeight: i == 0
                          ? pw.FontWeight.bold
                          : pw.FontWeight.normal,
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  static pw.Widget _buildTabelaDias(Map<String, double> tempoPorDia) {
    final dias = tempoPorDia.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(2),
        1: const pw.FlexColumnWidth(1),
      },
      children: [
        // Cabeçalho
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColors.green700),
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(10),
              child: pw.Text(
                'DATA',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(10),
              child: pw.Text(
                'HORAS',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
              ),
            ),
          ],
        ),
        // Dados
        for (var i = 0; i < dias.length; i++)
          pw.TableRow(
            decoration: pw.BoxDecoration(
              color: i.isEven ? PdfColors.grey50 : PdfColors.white,
            ),
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text(
                  dias[i].key,
                  style: const pw.TextStyle(fontSize: 9),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text(
                  dias[i].value.toStringAsFixed(1),
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: _greenDark,
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  static pw.Widget _buildGraficoBarras(Map<String, double> tempoPorProjeto) {
    final projetos = tempoPorProjeto.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final maxHoras = projetos.isNotEmpty
        ? projetos.map((e) => e.value).reduce((a, b) => a > b ? a : b)
        : 1.0;

    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey50,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColors.grey300, width: 1),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'GRÁFICO - DISTRIBUIÇÃO DE HORAS',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue800,
            ),
          ),
          pw.SizedBox(height: 12),
          ...projetos.map((projeto) {
            final larguraBarra = (projeto.value / maxHoras) * 200;
            final percentual = (projeto.value / maxHoras * 100);
            return pw.Column(
              children: [
                pw.Row(
                  children: [
                    pw.Container(
                      width: 100,
                      child: pw.Text(
                        _truncateText(projeto.key, 20),
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: _blueDark,
                        ),
                      ),
                    ),
                    pw.SizedBox(width: 8),
                    pw.Expanded(
                      child: pw.Container(
                        height: 20,
                        decoration: pw.BoxDecoration(
                          color: _lightBlue,
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                        child: pw.Stack(
                          children: [
                            pw.Container(
                              width: larguraBarra,
                              decoration: pw.BoxDecoration(
                                color: _getBarColor(percentual),
                                borderRadius: pw.BorderRadius.circular(4),
                              ),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              child: pw.Align(
                                alignment: pw.Alignment.centerRight,
                                child: pw.Text(
                                  '${projeto.value.toStringAsFixed(1)}h',
                                  style: pw.TextStyle(
                                    fontSize: 8,
                                    color: PdfColors.white,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    pw.SizedBox(width: 8),
                    pw.Container(
                      width: 35,
                      child: pw.Text(
                        '${percentual.toStringAsFixed(0)}%',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey700,
                        ),
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 6),
              ],
            );
          }).toList(),
        ],
      ),
    );
  }

  static PdfColor _getBarColor(double percentual) {
    if (percentual > 70) return PdfColors.red;
    if (percentual > 40) return PdfColors.orange;
    return PdfColors.blue;
  }

  static String _truncateText(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength - 3)}...';
  }

  static String _getTextoResumo(
    String projetoMaisUsado,
    double totalHoras,
    double mediaDiaria,
  ) {
    if (totalHoras == 0) {
      return 'Não foram registradas horas trabalhadas neste período.';
    }

    return 'O projeto "$projetoMaisUsado" foi o que demandou mais tempo, '
        'com uma média diária de ${mediaDiaria.toStringAsFixed(1)} horas trabalhadas.';
  }

  static Future<File> savePdf(pw.Document pdf, String fileName) async {
    final bytes = await pdf.save();
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes);
    return file;
  }
}
