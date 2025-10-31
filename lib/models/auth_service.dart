import 'usuario.dart';

class AuthService {
  static Usuario? _usuarioLogado;

  static void setUsuarioLogado(Usuario usuario) {
    _usuarioLogado = usuario;
  }

  static Usuario? getUsuarioLogado() {
    return _usuarioLogado;
  }

  static void logout() {
    _usuarioLogado = null;
  }

  static bool isLoggedIn() {
    return _usuarioLogado != null;
  }
}
