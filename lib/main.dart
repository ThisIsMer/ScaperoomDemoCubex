import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'controllers/game_controller.dart';
import 'screens/portada_screen.dart';
import 'screens/dialogo_screen.dart';
import 'screens/menu_screen.dart';
import 'screens/camaras_screen.dart';
import 'screens/mapa_screen.dart';
import 'screens/recorrer_screen.dart';
import 'screens/salida_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(
    ChangeNotifierProvider(
      create: (_) => GameController(),
      child: const EscapeRoomApp(),
    ),
  );
}

class EscapeRoomApp extends StatelessWidget {
  const EscapeRoomApp({super.key});

  Route<dynamic> _fadeRoute(RouteSettings settings, Widget page) {
    return PageRouteBuilder(
      settings: settings,
      transitionDuration: const Duration(milliseconds: 900),
      reverseTransitionDuration: const Duration(milliseconds: 900),
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOut,
          ),
          child: child,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Escape Room',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
      ),
      initialRoute: '/portada',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/portada':
            return _fadeRoute(settings, const PortadaScreen());
          case '/dialogo':
            return _fadeRoute(settings, const DialogoScreen());
          case '/menu':
            return _fadeRoute(settings, const MenuScreen());
          case '/camaras':
            return _fadeRoute(settings, const CamarasScreen());
          case '/mapa':
            return _fadeRoute(settings, const MapaScreen());
          case '/recorrer':
            return _fadeRoute(settings, const RecorrerScreen());
          case '/salida':
            return _fadeRoute(settings, const SalidaScreen());
          default:
            return _fadeRoute(settings, const PortadaScreen());
        }
      },
    );
  }
}