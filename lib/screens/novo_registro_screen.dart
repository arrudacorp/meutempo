import 'package:flutter/material.dart';
import 'package:meutempo/models/projeto.dart';
import 'package:meutempo/models/projeto_dao.dart';
import 'package:meutempo/models/tempo_gasto_dao.dart';
import 'package:meutempo/models/tempo_gasto.dart';
import 'package:meutempo/models/auth_service.dart';

class NovoRegistroScreen extends StatefulWidget {
  const NovoRegistroScreen({Key? key}) : super(key: key);

  @override
  State<NovoRegistroScreen> createState() => _NovoRegistroScreenState();
}

class _NovoRegistroScreenState extends State<NovoRegistroScreen> {
  final ProjetoDao _projetoDao = ProjetoDao();
  final TempoGastoDao _tempoGastoDao = TempoGastoDao();

  final TextEditingController _observacaoController = TextEditingController();
  final TextEditingController _dataHoraIniController = TextEditingController();
  final TextEditingController _dataHoraFimController = TextEditingController();

  int? _projetoSelecionado;
  List<Projeto> _projetos = [];
  bool _carregando = false;
  bool _registroManual = false;
  DateTime? _dataHoraIni;
  DateTime? _dataHoraFim;

  @override
  void initState() {
    super.initState();
    _carregarProjetos();
    _dataHoraIni = DateTime.now();
    _dataHoraIniController.text = _formatarDataHora(_dataHoraIni!);
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

  String _formatarDataHora(DateTime data) {
    return '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year} ${data.hour.toString().padLeft(2, '0')}:${data.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _selecionarDataHoraIni() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dataHoraIni ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      final TimeOfDay? time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_dataHoraIni ?? DateTime.now()),
      );

      if (time != null) {
        setState(() {
          _dataHoraIni = DateTime(
            picked.year,
            picked.month,
            picked.day,
            time.hour,
            time.minute,
          );
          _dataHoraIniController.text = _formatarDataHora(_dataHoraIni!);
        });
      }
    }
  }

  Future<void> _selecionarDataHoraFim() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dataHoraFim ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      final TimeOfDay? time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_dataHoraFim ?? DateTime.now()),
      );

      if (time != null) {
        setState(() {
          _dataHoraFim = DateTime(
            picked.year,
            picked.month,
            picked.day,
            time.hour,
            time.minute,
          );
          _dataHoraFimController.text = _formatarDataHora(_dataHoraFim!);
        });
      }
    }
  }

  Future<void> _iniciarRegistro() async {
    if (_projetoSelecionado == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Selecione um projeto')));
      return;
    }

    if (_registroManual && _dataHoraIni == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione a data/hora de início')),
      );
      return;
    }

    if (_registroManual &&
        _dataHoraFim != null &&
        _dataHoraFim!.isBefore(_dataHoraIni!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'A data/hora fim não pode ser anterior à data/hora início',
          ),
        ),
      );
      return;
    }

    setState(() {
      _carregando = true;
    });

    try {
      final usuario = AuthService.getUsuarioLogado();
      if (usuario == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Usuário não logado')));
        return;
      }

      // Verificar se já existe um registro em andamento (apenas para registro automático)
      if (!_registroManual) {
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
          setState(() {
            _carregando = false;
          });
          return;
        }
      }

      final novoTempoGasto = TempoGasto(
        idProjeto: _projetoSelecionado!,
        idUsuario: usuario.id!,
        dataHoraIni: _dataHoraIni!,
        dataHoraFim: _registroManual ? _dataHoraFim : null,
        observacao: _observacaoController.text.isEmpty
            ? null
            : _observacaoController.text,
      );

      await _tempoGastoDao.insertTempoGasto(novoTempoGasto);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _registroManual
                ? 'Registro salvo com sucesso!'
                : 'Trabalho iniciado com sucesso!',
          ),
          backgroundColor: Colors.green,
        ),
      );

      // CORREÇÃO: Navegação diferente para cada tipo de registro
      if (_registroManual) {
        // Para registro manual: limpar campos e permanecer na tela
        _limparCampos();
      } else {
        // Para registro automático: voltar para o histórico SEM fechar a tela atual
        // Usamos um delay pequeno para garantir que o SnackBar seja mostrado
        await Future.delayed(const Duration(milliseconds: 500));

        // Em vez de Navigator.pop, vamos resetar os campos e mostrar mensagem
        _limparCampos();

        // Mostrar mensagem adicional informando que pode finalizar no histórico
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Você pode finalizar este registro na aba Histórico'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao salvar registro: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _carregando = false;
      });
    }
  }

  void _limparCampos() {
    setState(() {
      _projetoSelecionado = null;
      _observacaoController.clear();
      _dataHoraIni = DateTime.now();
      _dataHoraFim = null;
      _dataHoraIniController.text = _formatarDataHora(_dataHoraIni!);
      _dataHoraFimController.clear();
    });
  }

  Widget _buildCampoDataHora({
    required String label,
    required String hintText,
    required VoidCallback onTap,
    required TextEditingController controller,
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hintText,
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: const Icon(Icons.calendar_today),
              onPressed: onTap,
            ),
            filled: !enabled,
            fillColor: Colors.grey.shade100,
          ),
          readOnly: true,
          onTap: onTap,
          enabled: enabled,
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Novo Registro'),
        backgroundColor: Colors.blue.shade50,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Switch entre registro automático e manual
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tipo de Registro',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ListTile(
                            title: const Text('Automático'),
                            subtitle: const Text('Inicia agora'),
                            leading: Radio<bool>(
                              value: false,
                              groupValue: _registroManual,
                              onChanged: (value) {
                                setState(() {
                                  _registroManual = value!;
                                  if (!_registroManual) {
                                    _dataHoraIni = DateTime.now();
                                    _dataHoraIniController.text =
                                        _formatarDataHora(_dataHoraIni!);
                                    _dataHoraFim = null;
                                    _dataHoraFimController.clear();
                                  }
                                });
                              },
                            ),
                          ),
                        ),
                        Expanded(
                          child: ListTile(
                            title: const Text('Manual'),
                            subtitle: const Text('Período passado'),
                            leading: Radio<bool>(
                              value: true,
                              groupValue: _registroManual,
                              onChanged: (value) {
                                setState(() {
                                  _registroManual = value!;
                                });
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Campos do formulário
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<int>(
                      value: _projetoSelecionado,
                      decoration: const InputDecoration(
                        labelText: 'Projeto *',
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

                    const SizedBox(height: 20),

                    // Data/Hora Início
                    _buildCampoDataHora(
                      label: 'Data/Hora Início *',
                      hintText: 'Selecione a data e hora de início',
                      onTap: _selecionarDataHoraIni,
                      controller: _dataHoraIniController,
                      enabled:
                          _registroManual, // Só permite editar se for manual
                    ),

                    // Data/Hora Fim (apenas para registro manual)
                    if (_registroManual)
                      _buildCampoDataHora(
                        label: 'Data/Hora Fim (Opcional)',
                        hintText: 'Selecione a data e hora de fim',
                        onTap: _selecionarDataHoraFim,
                        controller: _dataHoraFimController,
                        enabled: true,
                      ),

                    const SizedBox(height: 20),

                    TextField(
                      controller: _observacaoController,
                      decoration: const InputDecoration(
                        labelText: 'Observação (opcional)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.note),
                      ),
                      maxLines: 3,
                    ),

                    const SizedBox(height: 30),

                    // Botões de ação
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _limparCampos,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              side: BorderSide(color: Colors.grey.shade400),
                            ),
                            child: const Text(
                              'LIMPAR',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _carregando ? null : _iniciarRegistro,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: Colors.blue,
                              disabledBackgroundColor: Colors.grey.shade400,
                            ),
                            child: _carregando
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : Text(
                                    _registroManual ? 'SALVAR' : 'INICIAR',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Informações sobre os tipos de registro
                    Card(
                      color: Colors.blue.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _registroManual
                                  ? 'Registro Manual'
                                  : 'Registro Automático',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (!_registroManual) ...[
                              const Text(
                                '• Inicia um novo registro em andamento',
                              ),
                              const Text(
                                '• Data/hora início: agora (automático)',
                              ),
                              const Text(
                                '• Você pode finalizar depois no Histórico',
                              ),
                            ] else ...[
                              const Text('• Registra um período já finalizado'),
                              const Text('• Data/hora início: você seleciona'),
                              const Text('• Data/hora fim: opcional'),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
