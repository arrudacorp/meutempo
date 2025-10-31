import 'package:flutter/material.dart';
import 'package:meutempo/models/usuario_dao.dart';
import 'package:meutempo/models/usuario.dart';

class CadastroScreen extends StatefulWidget {
  const CadastroScreen({Key? key}) : super(key: key);

  @override
  State<CadastroScreen> createState() => _CadastroScreenState();
}

class _CadastroScreenState extends State<CadastroScreen> {
  final UsuarioDao _usuarioDao = UsuarioDao();
  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _usuarioController = TextEditingController();
  final TextEditingController _senhaController = TextEditingController();
  final TextEditingController _confirmarSenhaController =
      TextEditingController();

  bool _carregando = false;
  bool _senhaOculta = true;
  bool _confirmarSenhaOculta = true;

  Future<void> _cadastrar() async {
    if (_nomeController.text.isEmpty ||
        _usuarioController.text.isEmpty ||
        _senhaController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha todos os campos obrigatórios')),
      );
      return;
    }

    if (_senhaController.text != _confirmarSenhaController.text) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('As senhas não coincidem')));
      return;
    }

    if (_senhaController.text.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A senha deve ter pelo menos 4 caracteres'),
        ),
      );
      return;
    }

    setState(() {
      _carregando = true;
    });

    try {
      // Verificar se usuário já existe
      final usuarioExistente = await _usuarioDao.getUsuarioByPin(
        _usuarioController.text,
      );
      if (usuarioExistente != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Este PIN já está em uso')),
        );
        return;
      }

      // Criar novo usuário
      final novoUsuario = Usuario(
        nome: _nomeController.text,
        usuario: _usuarioController.text,
        senha: _senhaController.text,
      );

      await _usuarioDao.insertUsuario(novoUsuario);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cadastro realizado com sucesso!'),
          backgroundColor: Colors.green,
        ),
      );

      // Voltar para a tela inicial após 1 segundo
      await Future.delayed(const Duration(seconds: 1));
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao cadastrar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _carregando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cadastro'),
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
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              const Icon(Icons.person_add, size: 80, color: Colors.blue),
              const SizedBox(height: 20),
              const Text(
                'Criar Nova Conta',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              TextField(
                controller: _nomeController,
                decoration: const InputDecoration(
                  labelText: 'Nome Completo *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _usuarioController,
                decoration: const InputDecoration(
                  labelText: 'PIN (4 dígitos) *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.pin),
                  hintText: 'Ex: 1234',
                ),
                keyboardType: TextInputType.number,
                maxLength: 4,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _senhaController,
                decoration: InputDecoration(
                  labelText: 'Senha *',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _senhaOculta ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _senhaOculta = !_senhaOculta;
                      });
                    },
                  ),
                ),
                obscureText: _senhaOculta,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _confirmarSenhaController,
                decoration: InputDecoration(
                  labelText: 'Confirmar Senha *',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _confirmarSenhaOculta
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _confirmarSenhaOculta = !_confirmarSenhaOculta;
                      });
                    },
                  ),
                ),
                obscureText: _confirmarSenhaOculta,
              ),
              const SizedBox(height: 30),
              _carregando
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _cadastrar,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.green,
                      ),
                      child: const Text(
                        'CADASTRAR',
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
                    ),
              const SizedBox(height: 20),
              Card(
                color: Colors.blue.shade50,
                child: const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Informações:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text('• PIN: Use 4 dígitos fáceis de lembrar'),
                      Text('• Senha: Mínimo 4 caracteres'),
                      Text(
                        '• Você usará o PIN para iniciar trabalhos rapidamente',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
