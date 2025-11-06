import 'package:flutter/material.dart';
import 'historico_screen.dart';
import 'novo_registro_screen.dart';
import 'relatorios_screen.dart';
import 'home_screen.dart';
import 'gerenciar_projetos_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HistoricoScreen(), // Tela de histórico quando logado
    const NovoRegistroScreen(),
    const GerenciarProjetosScreen(),
    const RelatoriosScreen(),
  ];

  void _logout() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const HomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meu Controle'),
        backgroundColor: Colors.blue.shade50,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.blue.shade50, // Fundo da barra
        selectedItemColor: Colors.blue.shade800, // Ícone selecionado
        unselectedItemColor: Colors.grey.shade600, // Ícone não selecionado
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'Histórico',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.add), label: 'Novo'),
          BottomNavigationBarItem(icon: Icon(Icons.folder), label: 'Projetos'),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Relatórios',
          ),
        ],
      ),
    );
  }
}
