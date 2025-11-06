import 'package:flutter/material.dart';
import 'package:meutempo/models/projeto_dao.dart';
import 'package:meutempo/models/projeto.dart';

class GerenciarProjetosScreen extends StatefulWidget {
  const GerenciarProjetosScreen({Key? key}) : super(key: key);

  @override
  State<GerenciarProjetosScreen> createState() =>
      _GerenciarProjetosScreenState();
}

class _GerenciarProjetosScreenState extends State<GerenciarProjetosScreen> {
  final ProjetoDao _projetoDao = ProjetoDao();
  List<Projeto> _projetos = [];
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregarProjetos();
  }

  Future<void> _carregarProjetos() async {
    try {
      final projetos = await _projetoDao.getAllProjetos();
      setState(() {
        _projetos = projetos;
        _carregando = false;
      });
    } catch (e) {
      print('Erro ao carregar projetos: $e');
      setState(() {
        _carregando = false;
      });
    }
  }

  void _mostrarDialogoProjeto([Projeto? projeto]) {
    final nomeController = TextEditingController(
      text: projeto?.nomeProjeto ?? '',
    );
    bool ativo = projeto?.ativo ?? true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // ← IMPORTANTE para teclado
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(
            context,
          ).viewInsets.bottom, // ← AJUSTA para teclado
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                projeto == null ? 'Novo Projeto' : 'Editar Projeto',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),

              TextField(
                controller: nomeController,
                decoration: const InputDecoration(
                  labelText: 'Nome do Projeto *',
                  border: OutlineInputBorder(),
                  hintText: 'Ex: Desenvolvimento App',
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                maxLength: 50,
                autofocus: true,
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Checkbox(
                    value: ativo,
                    onChanged: (value) {
                      setState(() {
                        ativo = value ?? true;
                      });
                    },
                  ),
                  const Text('Projeto Ativo'),
                  const SizedBox(width: 8),
                  const Tooltip(
                    message: 'Projetos inativos não aparecem para seleção',
                    child: Icon(
                      Icons.info_outline,
                      color: Colors.grey,
                      size: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        if (nomeController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Digite um nome para o projeto'),
                            ),
                          );
                          return;
                        }

                        try {
                          if (projeto == null) {
                            final novoProjeto = Projeto(
                              nomeProjeto: nomeController.text.trim(),
                              ativo: ativo,
                            );
                            await _projetoDao.insertProjeto(novoProjeto);
                          } else {
                            final projetoEditado = Projeto(
                              id: projeto.id,
                              nomeProjeto: nomeController.text.trim(),
                              ativo: ativo,
                            );
                            await _projetoDao.updateProjeto(projetoEditado);
                          }

                          Navigator.pop(context);
                          await _carregarProjetos();

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                projeto == null
                                    ? 'Projeto criado com sucesso!'
                                    : 'Projeto atualizado com sucesso!',
                              ),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Erro ao salvar projeto: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Salvar'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10), // Espaço extra para teclado
            ],
          ),
        ),
      ),
    );
  }

  void _confirmarExclusao(Projeto projeto) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: Text(
          'Tem certeza que deseja excluir o projeto "${projeto.nomeProjeto}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _projetoDao.deleteProjeto(projeto.id!);
                Navigator.pop(context);
                await _carregarProjetos();

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Projeto excluído com sucesso'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Erro ao excluir projeto: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }

  Widget _buildItemProjeto(Projeto projeto) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          projeto.ativo ? Icons.folder : Icons.folder_off,
          color: projeto.ativo ? Colors.blue : Colors.grey,
        ),
        title: Text(
          projeto.nomeProjeto,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: projeto.ativo ? Colors.black : Colors.grey,
          ),
        ),
        subtitle: Text(
          projeto.ativo ? 'Ativo' : 'Inativo',
          style: TextStyle(color: projeto.ativo ? Colors.green : Colors.grey),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, size: 20),
              onPressed: () => _mostrarDialogoProjeto(projeto),
              tooltip: 'Editar',
            ),
            IconButton(
              icon: const Icon(Icons.delete, size: 20),
              onPressed: () => _confirmarExclusao(projeto),
              tooltip: 'Excluir',
              color: Colors.red,
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
        title: const Text('Gerenciar Projetos'),
        backgroundColor: Colors.blue.shade50,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _carregarProjetos,
            tooltip: 'Atualizar',
          ),
        ],
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Card de informações
                  Card(
                    color: Colors.blue.shade50,
                    child: const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Projetos inativos não aparecem para seleção '
                              'em novos registros, mas mantêm os registros históricos.',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Lista de projetos
                  Expanded(
                    child: _projetos.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.folder_open,
                                  size: 64,
                                  color: Colors.grey,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'Nenhum projeto cadastrado',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Clique no botão + para criar seu primeiro projeto',
                                  style: TextStyle(color: Colors.grey),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: _projetos.length,
                            itemBuilder: (context, index) {
                              return _buildItemProjeto(_projetos[index]);
                            },
                          ),
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _mostrarDialogoProjeto(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
