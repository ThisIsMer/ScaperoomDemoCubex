import 'dart:async';
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────
// NOTA: Añade en pubspec.yaml bajo flutter > fonts:
//   - family: Airlock
//     fonts:
//       - asset: assets/fonts/Airlock.ttf
// ─────────────────────────────────────────────────────────────

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  int? _itemPresionado; // índice del item con press activo

  static const _items = [
    _MenuItem(label: 'CÁMARAS',  ruta: '/camaras'),
    _MenuItem(label: 'MAPA',     ruta: '/mapa'),
    _MenuItem(label: 'RECORRER', ruta: '/recorrer'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [

          // ── Fondo ──────────────────────────────────────────
          Image.asset(
            'assets/images/FondoSalaControl.png',
            fit: BoxFit.cover,
          ),
          // Oscurece ligeramente la mitad derecha para que el
          // texto de la izquierda destaque sobre la escena
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color(0xCC000000), // izquierda más oscura
                  Color(0x33000000), // derecha más transparente
                ],
                stops: [0.0, 1.0],
              ),
            ),
          ),

          // ── Contenido principal ────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(left: 40, top: 48, bottom: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── Reloj estilo vigilancia ─────────────────
                  const _ClockWidget(),
                  const SizedBox(height: 32),

                  // ── Título pequeño ──────────────────────────
                  const Text(
                    'SALA DE CONTROL',
                    style: TextStyle(
                      fontFamily: 'Airlock',
                      color: Colors.white38,
                      fontSize: 13,
                      letterSpacing: 6,
                    ),
                  ),
                  const SizedBox(height: 36),

                  // ── Items del menú ──────────────────────────
                  ...List.generate(_items.length, (i) {
                    final activo = _itemPresionado == i;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: GestureDetector(
                        onTapDown: (_) =>
                            setState(() => _itemPresionado = i),
                        onTapUp: (_) {
                          setState(() => _itemPresionado = null);
                          Navigator.pushNamed(
                              context, _items[i].ruta);
                        },
                        onTapCancel: () =>
                            setState(() => _itemPresionado = null),
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 100),
                          style: TextStyle(
                            fontFamily: 'Airlock',
                            fontSize: activo ? 54 : 58,
                            letterSpacing: 2,
                            height: 1.15,
                            color: activo
                                ? const Color(0xFFFFD600) // amarillo
                                : Colors.white,
                            shadows: activo
                                ? [
                              Shadow(
                                color: const Color(0xFFFFD600)
                                    .withOpacity(0.35),
                                blurRadius: 18,
                              )
                            ]
                                : null,
                          ),
                          child: Text(_items[i].label),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Modelo de item ────────────────────────────────────────────

class _MenuItem {
  final String label;
  final String ruta;
  const _MenuItem({required this.label, required this.ruta});
}

// ── Reloj en tiempo real estilo CCTV ─────────────────────────

class _ClockWidget extends StatefulWidget {
  const _ClockWidget();

  @override
  State<_ClockWidget> createState() => _ClockWidgetState();
}

class _ClockWidgetState extends State<_ClockWidget> {
  late Timer _timer;
  late DateTime _now;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = _now.hour.toString().padLeft(2, '0');
    final m = _now.minute.toString().padLeft(2, '0');
    return Text(
      '$h:$m',
      style: const TextStyle(
        fontFamily: 'Airlock',
        color: Color(0xFF00FF41), // verde terminal
        fontSize: 22,
        letterSpacing: 4,
      ),
    );
  }
}