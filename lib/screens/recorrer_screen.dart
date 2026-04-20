import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/game_controller.dart';

class RecorrerScreen extends StatefulWidget {
  const RecorrerScreen({super.key});

  @override
  State<RecorrerScreen> createState() => _RecorrerScreenState();
}

class _RecorrerScreenState extends State<RecorrerScreen> {
  String? _mensajePrincipal;
  String? _mensajeCreatura;
  late bool _mostrandoIntro;
  bool _fadeToBlack = false;
  bool _expulsado   = false;
  Timer? _mensajeTimer;
  late String _fondoActual;

  static const _intro = [
    'Mientras avanzas por la habitación, un eco distante, como de algo arrastrándose, te acompaña de fondo; sea lo que sea, no parece muy lejos.',
    'La sensación de que no estás solo se hace cada vez más fuerte, y una parte de ti sabe que será mejor no entretenerse demasiado aquí.',
  ];
  int _introIdx = 0;

  static const _mensajesCreatura = [
    'En algún lugar de la habitación, algo acaba de moverse.',
    'Los pasos se acercan. Hay algo en esta planta contigo.',
    'Puedes escuchar su respiración. No estás solo aquí dentro.',
    'Una sombra cruza el fondo de la habitación. Sabe dónde estás.',
    'Lo tienes a unos metros. El siguiente error no te dará tiempo a reaccionar.',
  ];

  @override
  void initState() {
    super.initState();
    final gc = context.read<GameController>();
    _mostrandoIntro = !gc.introMostrada;
    _fondoActual    = gc.tablero[gc.posAct[0]][gc.posAct[1]].fondo;
  }

  @override
  void dispose() {
    _mensajeTimer?.cancel();
    super.dispose();
  }

  void _avanzarIntro() {
    if (_introIdx < _intro.length - 1) {
      setState(() => _introIdx++);
    } else {
      context.read<GameController>().introMostrada = true;
      setState(() => _mostrandoIntro = false);
    }
  }

  void _moverse(BuildContext context, int dir) async {
    // ── Bloqueo: no procesar input durante fade o expulsión ──
    if (_expulsado || _fadeToBlack) return;

    final gc        = context.read<GameController>();
    final resultado = gc.moverHacia(dir);

    // ── Llegó a la salida ─────────────────────────────────
    if (resultado == 'salida') {
      setState(() => _fadeToBlack = true);
      await Future.delayed(const Duration(milliseconds: 1200));
      if (mounted) Navigator.pushReplacementNamed(context, '/salida');
      return;
    }

    // ── Movimiento válido ─────────────────────────────────
    if (resultado == 'avanzar') {
      _mensajeTimer?.cancel();
      setState(() {
        _fondoActual      = gc.tablero[gc.posAct[0]][gc.posAct[1]].fondo;
        _mensajePrincipal = 'Avanzas hacia la siguiente sala.';
        _mensajeCreatura  = null;
      });
      _mensajeTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() {
          _mensajePrincipal = null;
          _mensajeCreatura  = null;
        });
      });
      return;
    }

    // ── Confusión (pared o bloqueada) ─────────────────────
    final errores = gc.erroresRonda;

    if (errores > GameController.maxErrores) {
      _mensajeTimer?.cancel();
      setState(() {
        _mensajePrincipal = null;
        _mensajeCreatura  = null;
        _expulsado        = true;
      });
      await Future.delayed(const Duration(seconds: 5));
      if (mounted) {
        gc.resetRecorrido();
        Navigator.pop(context);
      }
      return;
    }

    final textoMovimiento = resultado == 'pared'
        ? 'Es una pared. No puedes pasar por ahí.'
        : 'Esa puerta está bloqueada.';
    final idx = (errores - 1).clamp(0, _mensajesCreatura.length - 1);

    _mensajeTimer?.cancel();
    setState(() {
      _mensajePrincipal = textoMovimiento;
      _mensajeCreatura  = _mensajesCreatura[idx];
    });
    _mensajeTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() {
        _mensajePrincipal = null;
        _mensajeCreatura  = null;
      });
    });
  }

  Future<bool> _onWillPop(BuildContext context) async {
    if (_expulsado || _fadeToBlack) return false;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('¿Volver?',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'Si regresas a este lugar, no habrá atajos: '
              'tendrás que recorrerlo otra vez desde el comienzo.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Volver',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmar == true) context.read<GameController>().resetRecorrido();
    return confirmar ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final gc = context.watch<GameController>();

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final salir = await _onWillPop(context);
        if (salir && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [

            // ── Fondo con crossfade ──────────────────────────
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              transitionBuilder: (child, animation) =>
                  FadeTransition(opacity: animation, child: child),
              child: SizedBox.expand(
                key: ValueKey(_fondoActual),
                child: Image.asset(
                  _fondoActual.isNotEmpty
                      ? _fondoActual
                      : 'assets/images/PortadaSinTexto.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),

            Column(
              children: [
                // ── Barra superior ──────────────────────────
                Container(
                  color: Colors.black54,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      TextButton.icon(
                        onPressed: () async {
                          final salir = await _onWillPop(context);
                          if (salir && context.mounted) Navigator.pop(context);
                        },
                        icon: const Icon(Icons.arrow_back,
                            color: Colors.white70),
                        label: const Text('VOLVER',
                            style: TextStyle(
                                color: Colors.white70, letterSpacing: 2)),
                      ),
                      const Spacer(),
                      _ErrorIndicator(
                        errores:    gc.erroresRonda,
                        maxErrores: GameController.maxErrores,
                      ),
                      const SizedBox(width: 12),
                    ],
                  ),
                ),

                Expanded(
                  child: _mostrandoIntro
                      ? _IntroDialog(texto: _intro[_introIdx])
                      : _PanelMovimiento(
                    mensajePrincipal: _mensajePrincipal,
                    mensajeCreatura:  _mensajeCreatura,
                    onDireccion:      (d) => _moverse(context, d),
                  ),
                ),
              ],
            ),

            // ── Detector global solo durante intro ────────────
            if (_mostrandoIntro)
              Positioned.fill(
                child: GestureDetector(
                  onTap: _avanzarIntro,
                  behavior: HitTestBehavior.opaque,
                  child: Container(color: Colors.transparent),
                ),
              ),

            // ── Fade negro al llegar a la salida ─────────────
            IgnorePointer(
              child: AnimatedOpacity(
                opacity: _fadeToBlack ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 1200),
                child: Container(color: Colors.black),
              ),
            ),

            // ── Overlay de expulsión — estética Airlock ───────
            if (_expulsado)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.96),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 48),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Línea decorativa superior
                          Container(
                            width: 48,
                            height: 2,
                            color: Colors.white24,
                            margin: const EdgeInsets.only(bottom: 32),
                          ),

                          // Título principal — Airlock grande
                          const Text(
                            'SALISTE\nCORRIENDO.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Airlock',
                              color: Colors.white,
                              fontSize: 52,
                              height: 1.1,
                              letterSpacing: 2,
                            ),
                          ),

                          const SizedBox(height: 32),

                          // Texto narrativo
                          Text(
                            'Lo que fuera que te estaba siguiendo\n'
                                'se acercó demasiado.\n\n'
                                'No hubo tiempo para pensar: echaste a correr\n'
                                'y no paraste hasta encontrar una puerta\n'
                                'que pudiste cerrar a tu espalda.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.55),
                              fontSize: 15,
                              height: 1.8,
                              letterSpacing: 0.5,
                            ),
                          ),

                          const SizedBox(height: 48),

                          // Línea decorativa + estado
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                  width: 24, height: 1,
                                  color: Colors.white12),
                              const SizedBox(width: 12),
                              Text(
                                'VOLVIENDO A LA SALA DE CONTROL',
                                style: TextStyle(
                                  fontFamily: 'Airlock',
                                  color: Colors.white.withOpacity(0.28),
                                  fontSize: 11,
                                  letterSpacing: 4,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                  width: 24, height: 1,
                                  color: Colors.white12),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Indicador de errores ─────────────────────────────────────

class _ErrorIndicator extends StatelessWidget {
  final int errores;
  final int maxErrores;

  const _ErrorIndicator({required this.errores, required this.maxErrores});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(maxErrores, (i) {
        final usado   = i < errores;
        final critico = errores >= maxErrores && i == maxErrores - 1;
        return Container(
          width: 10,
          height: 10,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: usado
                ? Colors.red.withOpacity(critico ? 1.0 : 0.75)
                : Colors.white24,
            boxShadow: usado && critico
                ? [BoxShadow(
                color: Colors.red.withOpacity(0.6), blurRadius: 6)]
                : null,
          ),
        );
      }),
    );
  }
}

// ── Botón de dirección ───────────────────────────────────────

class _DirButton extends StatelessWidget {
  final int direccion;
  final VoidCallback onPressed;

  const _DirButton({required this.direccion, required this.onPressed});

  static const _datos = {1: '○', 2: '□', 3: '△', 4: '✕'};

  @override
  Widget build(BuildContext context) {
    final simbolo = _datos[direccion] ?? '?';
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 84,
        height: 84,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black54, width: 1.5),
          color: Colors.black.withOpacity(0.90),
        ),
        child: Center(
          child: Text(simbolo,
              style: const TextStyle(color: Colors.white, fontSize: 30)),
        ),
      ),
    );
  }
}

class _Leg extends StatelessWidget {
  final Color color;
  final String label;
  const _Leg(this.color, this.label);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 2),
        Text(label,
            style: const TextStyle(color: Colors.white38, fontSize: 7)),
      ],
    );
  }
}

// ── Pantalla intro ───────────────────────────────────────────

class _IntroDialog extends StatelessWidget {
  final String texto;
  const _IntroDialog({required this.texto});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        margin: const EdgeInsets.fromLTRB(32, 0, 32, 16),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(texto,
                style: const TextStyle(
                    color: Colors.white, fontSize: 18, height: 1.5)),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

// ── Panel de movimiento ──────────────────────────────────────

class _PanelMovimiento extends StatelessWidget {
  final String? mensajePrincipal;
  final String? mensajeCreatura;
  final void Function(int) onDireccion;

  const _PanelMovimiento({
    this.mensajePrincipal,
    this.mensajeCreatura,
    required this.onDireccion,
  });

  static const double _btnSize = 84;

  @override
  Widget build(BuildContext context) {
    final hayMensaje = mensajePrincipal != null;

    return Stack(
      children: [
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '¿Hacia dónde quieres ir?',
                style: TextStyle(
                    color: Colors.white70, fontSize: 20, letterSpacing: 2),
              ),
              const SizedBox(height: 24),
              _DirButton(direccion: 1, onPressed: () => onDireccion(1)),
              const SizedBox(height: _btnSize),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _DirButton(direccion: 3, onPressed: () => onDireccion(3)),
                  const SizedBox(width: _btnSize * 2),
                  _DirButton(direccion: 4, onPressed: () => onDireccion(4)),
                ],
              ),
              const SizedBox(height: _btnSize),
              _DirButton(direccion: 2, onPressed: () => onDireccion(2)),
            ],
          ),
        ),

        Positioned(
          left: 40,
          right: 40,
          bottom: 16,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: hayMensaje
                ? Container(
              key: ValueKey('$mensajePrincipal$mensajeCreatura'),
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.82),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mensajePrincipal!,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        height: 1.4),
                  ),
                  if (mensajeCreatura != null) ...[
                    const SizedBox(height: 10),
                    const Divider(color: Colors.white12, height: 1),
                    const SizedBox(height: 10),
                    Text(
                      mensajeCreatura!,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        height: 1.5,
                      ),
                    ),
                  ],
                ],
              ),
            )
                : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }
}