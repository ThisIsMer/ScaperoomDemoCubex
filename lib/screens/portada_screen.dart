import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/game_controller.dart';

class PortadaScreen extends StatefulWidget {
  const PortadaScreen({super.key});

  @override
  State<PortadaScreen> createState() => _PortadaScreenState();
}

class _PortadaScreenState extends State<PortadaScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entradaCtrl;
  late final Animation<double> _entradaFade;

  late final AnimationController _salidaCtrl;
  late final Animation<double> _salidaFade;

  bool _tapped = false;

  @override
  void initState() {
    super.initState();

    _entradaCtrl = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _entradaFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _entradaCtrl, curve: Curves.easeOut),
    );

    _salidaCtrl = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _salidaFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _salidaCtrl, curve: Curves.easeIn),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GameController>().iniciarTablero();
      _entradaCtrl.forward();
    });
  }

  @override
  void dispose() {
    _entradaCtrl.dispose();
    _salidaCtrl.dispose();
    super.dispose();
  }

  void _onTap() {
    if (_tapped) return;
    _tapped = true;
    _salidaCtrl.forward().then((_) {
      if (mounted) Navigator.pushReplacementNamed(context, '/dialogo');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onTap: _onTap,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Imagen de fondo ──────────────────────────
            Image.asset(
              'assets/images/Portada.jpg',
              fit: BoxFit.cover,
            ),

            // ── Texto encima de la imagen ────────────────
            // Alignment(horizontal, vertical): -1.0=arriba/izq  1.0=abajo/der
            // Cambia el segundo valor para subir (-) o bajar (+)
            Align(
              alignment: const Alignment(0, 0.6),  // ← ajusta este valor
              child: Text(
                '— Pulsa para comenzar —',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 18,
                  shadows: [
                    Shadow(
                      color: Colors.black,
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ),

            // ── Fade de entrada: negro → transparente ────
            IgnorePointer(
              child: AnimatedBuilder(
                animation: _entradaFade,
                builder: (_, __) => Container(
                  color: Colors.black.withOpacity(_entradaFade.value),
                ),
              ),
            ),

            // ── Fade de salida: transparente → negro ─────
            IgnorePointer(
              child: AnimatedBuilder(
                animation: _salidaFade,
                builder: (_, __) => Container(
                  color: Colors.black.withOpacity(_salidaFade.value),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}