import 'dart:async';
import 'dart:math';
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
  bool _expulsado = false;
  bool _atacado = false;

  bool _encuentroMonstruo = false;
  double _monstruoOpacity = 0.0;
  Offset _monstruoPos = const Offset(0.5, 0.45);

  Timer? _mensajeTimer;
  Timer? _encuentroTimer;

  late String _fondoActual;

  static const _intro = [
    'Oyes algo moverse a lo lejos. Mejor no detenerse.',
    'Recuerda el mapa y sal cuanto antes.',
  ];

  int _introIdx = 0;

  static const _mensajesCreatura = [
    'Algo te sigue.',
    'Está más cerca.',
    'Lo oyes moverse.',
    'Ya casi lo tienes encima.',
    'Un error más y te alcanza.',
  ];

  @override
  void initState() {
    super.initState();
    final gc = context.read<GameController>();
    _mostrandoIntro = !gc.introMostrada;
    _fondoActual = gc.tablero[gc.posAct[0]][gc.posAct[1]].fondo;
  }

  @override
  void dispose() {
    _mensajeTimer?.cancel();
    _encuentroTimer?.cancel();
    super.dispose();
  }

  bool get _bloqueado =>
      _fadeToBlack || _expulsado || _atacado || _encuentroMonstruo;

  void _avanzarIntro() {
    if (_introIdx < _intro.length - 1) {
      setState(() => _introIdx++);
    } else {
      context.read<GameController>().introMostrada = true;
      setState(() => _mostrandoIntro = false);
    }
  }

  void _mostrarMensajeTemporal(
      String principal, {
        String? creatura,
        int segundos = 3,
      }) {
    _mensajeTimer?.cancel();
    setState(() {
      _mensajePrincipal = principal;
      _mensajeCreatura = creatura;
    });
    _mensajeTimer = Timer(Duration(seconds: segundos), () {
      if (!mounted) return;
      setState(() {
        _mensajePrincipal = null;
        _mensajeCreatura = null;
      });
    });
  }

  Future<void> _moverse(BuildContext context, int dir) async {
    if (_bloqueado || _mostrandoIntro) return;

    final gc = context.read<GameController>();

    final estadoDecision = gc.moverMonstruoDecision();

    if (estadoDecision == EstadoMonstruo.encuentro) {
      _activarEncuentroMonstruo();
      return;
    }

    final bool cercaDecision = estadoDecision == EstadoMonstruo.cerca;

    final estado = gc.clasificarDireccion(dir);

    if (estado == 'pared') {
      final resultado = gc.moverHacia(dir);
      await _procesarResultado(context, resultado,
          monstruoCercaExtra: cercaDecision);
      return;
    }

    if (estado == 'puerta_bloqueada') {
      await _gestionarPuertaBloqueada(context, dir,
          monstruoCercaExtra: cercaDecision);
      return;
    }

    final resultado = gc.moverHacia(dir);
    await _procesarResultado(context, resultado,
        monstruoCercaExtra: cercaDecision);
  }

  Future<void> _gestionarPuertaBloqueada(
      BuildContext context,
      int dir, {
        bool monstruoCercaExtra = false,
      }) async {
    final gc = context.read<GameController>();

    // ── Sin intentos restantes ───────────────────────────────
    if (gc.intentosForzarRestantes <= 0) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => _DialogJuego(
          titulo: 'PUERTA BLOQUEADA',
          cuerpo: 'No te quedan intentos\npara forzar cerraduras.',
          acciones: [
            _BotonDialog(
              texto: 'SEGUIR',
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      );
      if (!mounted) return;
      final resultado = gc.rechazarPuerta(dir);
      await _procesarResultado(context, resultado,
          monstruoCercaExtra: monstruoCercaExtra);
      return;
    }

    // ── Preguntar si forzar ──────────────────────────────────
    final usarFuerza = await showDialog<bool>(
      context: context,
      builder: (ctx) => _DialogJuego(
        titulo: 'PUERTA BLOQUEADA',
        cuerpo:
        '¿Intentas forzarla?\n\nProbabilidad: ${gc.probabilidadActualForzar}%\n'
            'Intentos restantes: ${gc.intentosForzarRestantes}',
        acciones: [
          _BotonDialog(
            texto: 'NO',
            onTap: () => Navigator.pop(ctx, false),
            tenue: true,
          ),
          _BotonDialog(
            texto: 'SÍ',
            onTap: () => Navigator.pop(ctx, true),
            destacado: true,
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (usarFuerza != true) {
      final resultado = gc.rechazarPuerta(dir);
      await _procesarResultado(context, resultado,
          monstruoCercaExtra: monstruoCercaExtra);
      return;
    }

    final resultado = gc.intentarForzarPuerta(dir);

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ForzarDialog(resultado: resultado),
    );

    if (!mounted) return;
    await _procesarResultado(context, resultado,
        monstruoCercaExtra: monstruoCercaExtra);
  }

  Future<void> _procesarResultado(
      BuildContext context,
      MovimientoResultado resultado, {
        bool monstruoCercaExtra = false,
      }) async {
    final gc = context.read<GameController>();

    if (resultado.tipo == 'salida') {
      setState(() => _fadeToBlack = true);
      await Future.delayed(const Duration(milliseconds: 1200));
      if (mounted) Navigator.pushReplacementNamed(context, '/salida');
      return;
    }

    if (resultado.tipo == 'encuentro_monstruo') {
      setState(() {
        _fondoActual = gc.tablero[gc.posAct[0]][gc.posAct[1]].fondo;
        _mensajePrincipal = null;
        _mensajeCreatura = null;
      });
      _activarEncuentroMonstruo();
      return;
    }

    if (resultado.tipo == 'avanzar') {
      setState(() {
        _fondoActual = gc.tablero[gc.posAct[0]][gc.posAct[1]].fondo;
      });
      _mostrarMensajeTemporal(
        resultado.puertaForzada
            ? 'La cerradura cede y entras.'
            : 'Avanzas a la siguiente sala.',
        creatura: (resultado.monstruoCerca || monstruoCercaExtra)
            ? 'Algo se siente amenazadoramente cerca.'
            : null,
      );
      return;
    }

    // ── Error ────────────────────────────────────────────────
    final errores = gc.erroresRonda;

    if (errores > GameController.maxErrores) {
      _mensajeTimer?.cancel();
      setState(() {
        _mensajePrincipal = null;
        _mensajeCreatura = null;
        _expulsado = true;
      });
      await Future.delayed(const Duration(seconds: 5));
      if (mounted) {
        gc.resetRecorrido();
        Navigator.pop(context);
      }
      return;
    }

    final textoMovimiento = resultado.tipo == 'pared'
        ? 'No hay paso: ahí termina el edificio.'
        : 'La puerta no cede.';

    final idx = (errores - 1).clamp(0, _mensajesCreatura.length - 1);

    _mostrarMensajeTemporal(
      textoMovimiento,
      creatura: monstruoCercaExtra
          ? 'Algo se siente amenazadoramente cerca.'
          : _mensajesCreatura[idx],
      segundos: 4,
    );
  }

  void _activarEncuentroMonstruo() {
    final rand = Random();

    _mensajeTimer?.cancel();
    _encuentroTimer?.cancel();

    setState(() {
      _encuentroMonstruo = true;
      _monstruoOpacity = 0.0;
      _monstruoPos = Offset(
        0.18 + rand.nextDouble() * 0.64,
        0.18 + rand.nextDouble() * 0.42,
      );
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _monstruoOpacity = 1.0);
    });

    _encuentroTimer = Timer(const Duration(seconds: 5), () async {
      if (!mounted) return;
      setState(() {
        _encuentroMonstruo = false;
        _atacado = true;
      });
      await Future.delayed(const Duration(seconds: 4));
      if (!mounted) return;
      context.read<GameController>().resetRecorrido();
      Navigator.pop(context);
    });
  }

  void _golpearMonstruo() {
    if (!_encuentroMonstruo) return;
    _encuentroTimer?.cancel();
    context.read<GameController>().ahuyentarMonstruo();
    setState(() {
      _encuentroMonstruo = false;
      _monstruoOpacity = 0.0;
    });
    _mostrarMensajeTemporal(
      'Consigues apartarlo. Tiene miedo ahora.',
      segundos: 2,
    );
  }

  Future<bool> _onWillPop(BuildContext context) async {
    if (_bloqueado) return false;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => _DialogJuego(
        titulo: '¿VOLVER?',
        cuerpo: 'Tendrás que recorrerlo\notra vez desde el inicio.',
        acciones: [
          _BotonDialog(
            texto: 'CANCELAR',
            onTap: () => Navigator.pop(ctx, false),
            tenue: true,
          ),
          _BotonDialog(
            texto: 'VOLVER',
            onTap: () => Navigator.pop(ctx, true),
            peligro: true,
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

                // ── Barra superior ───────────────────────────
                Container(
                  color: Colors.black54,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      TextButton.icon(
                        onPressed: () async {
                          final salir = await _onWillPop(context);
                          if (salir && context.mounted) {
                            Navigator.pop(context);
                          }
                        },
                        icon: const Icon(Icons.arrow_back,
                            color: Colors.white70),
                        label: const Text('VOLVER',
                            style: TextStyle(
                                color: Colors.white70, letterSpacing: 2)),
                      ),
                      TextButton.icon(
                        onPressed: () =>
                            Navigator.pushNamed(context, '/mapa'),
                        icon: const Icon(Icons.map_outlined,
                            color: Colors.white38, size: 18),
                        label: const Text('MAPA',
                            style: TextStyle(
                                color: Colors.white38,
                                letterSpacing: 2,
                                fontSize: 12)),
                      ),
                      const Spacer(),
                      _ForceIndicator(
                        usados: gc.intentosForzar,
                        maximos: GameController.maxIntentosForzar,
                      ),
                      const SizedBox(width: 14),
                      _ErrorIndicator(
                        errores: gc.erroresRonda,
                        maxErrores: GameController.maxErrores,
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),

                Expanded(
                  child: _mostrandoIntro
                      ? _IntroDialog(texto: _intro[_introIdx])
                      : _PanelMovimiento(
                    mensajePrincipal: _mensajePrincipal,
                    mensajeCreatura: _mensajeCreatura,
                    onDireccion: (d) => _moverse(context, d),
                  ),
                ),
              ],
            ),

            if (_mostrandoIntro)
              Positioned.fill(
                child: GestureDetector(
                  onTap: _avanzarIntro,
                  behavior: HitTestBehavior.opaque,
                  child: Container(color: Colors.transparent),
                ),
              ),

            // ── Encuentro con el monstruo ────────────────────
            if (_encuentroMonstruo)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.6),
                  child: Stack(
                    children: [
                      const Align(
                        alignment: Alignment(0, -0.86),
                        child: Text(
                          'TÓCALO ANTES DE QUE TE ALCANCE',
                          style: TextStyle(
                            color: Colors.white70,
                            letterSpacing: 3,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment(
                          (_monstruoPos.dx * 2) - 1,
                          (_monstruoPos.dy * 2) - 1,
                        ),
                        child: GestureDetector(
                          onTap: _golpearMonstruo,
                          child: AnimatedOpacity(
                            opacity: _monstruoOpacity,
                            duration: const Duration(seconds: 5),
                            curve: Curves.linear,
                            child: const _MonsterSilhouette(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ── Fade negro ───────────────────────────────────
            IgnorePointer(
              child: AnimatedOpacity(
                opacity: _fadeToBlack ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 1200),
                child: Container(color: Colors.black),
              ),
            ),

            if (_expulsado)
              const _HuidaOverlay(
                titulo: 'SALISTE\nCORRIENDO.',
                texto:
                'Te acercaste demasiado.\nNo intentaste entender qué era.\nSolo huiste de vuelta a la sala de control.',
                subtitulo: 'VOLVIENDO A LA SALA DE CONTROL',
              ),

            if (_atacado)
              const _HuidaOverlay(
                titulo: 'ALGO TE\nATACÓ.',
                texto:
                'No reaccionaste a tiempo.\nSolo recuerdas el golpe y la carrera de vuelta.',
                subtitulo: 'VOLVIENDO A LA SALA DE CONTROL',
              ),
          ],
        ),
      ),
    );
  }
}

// ── Dialog con estilo de juego ───────────────────────────────

class _DialogJuego extends StatelessWidget {
  final String titulo;
  final String cuerpo;
  final List<Widget> acciones;

  const _DialogJuego({
    required this.titulo,
    required this.cuerpo,
    required this.acciones,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.fromLTRB(28, 28, 28, 22),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.93),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                    width: 3,
                    height: 16,
                    color: Colors.white24,
                    margin: const EdgeInsets.only(right: 10)),
                Text(
                  titulo,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    letterSpacing: 3,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 18),
            Text(
              cuerpo,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 15,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: acciones
                  .expand((w) => [w, const SizedBox(width: 8)])
                  .toList()
                ..removeLast(),
            ),
          ],
        ),
      ),
    );
  }
}

class _BotonDialog extends StatelessWidget {
  final String texto;
  final VoidCallback onTap;
  final bool tenue;
  final bool destacado;
  final bool peligro;

  const _BotonDialog({
    required this.texto,
    required this.onTap,
    this.tenue = false,
    this.destacado = false,
    this.peligro = false,
  });

  @override
  Widget build(BuildContext context) {
    Color color = Colors.white;
    if (tenue) color = Colors.white38;
    if (destacado) color = Colors.amberAccent;
    if (peligro) color = Colors.redAccent;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(
            color: color.withOpacity(tenue ? 0.2 : 0.35),
          ),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          texto,
          style: TextStyle(
            color: color,
            fontSize: 12,
            letterSpacing: 2,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ── Indicador de intentos de forzar ─────────────────────────

class _ForceIndicator extends StatelessWidget {
  final int usados;
  final int maximos;

  const _ForceIndicator({required this.usados, required this.maximos});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(maximos, (i) {
        final usado = i < usados;
        return Container(
          width: 14,
          height: 14,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            color:
            usado ? Colors.amber.withOpacity(0.85) : Colors.white24,
          ),
        );
      }),
    );
  }
}

// ── Indicador de errores ─────────────────────────────────────

class _ErrorIndicator extends StatelessWidget {
  final int errores;
  final int maxErrores;

  const _ErrorIndicator(
      {required this.errores, required this.maxErrores});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(maxErrores, (i) {
        final usado = i < errores;
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
                ? [
              BoxShadow(
                  color: Colors.red.withOpacity(0.6),
                  blurRadius: 6)
            ]
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
              style:
              const TextStyle(color: Colors.white, fontSize: 30)),
        ),
      ),
    );
  }
}

// ── Intro ────────────────────────────────────────────────────

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
        child: Text(texto,
            style: const TextStyle(
                color: Colors.white, fontSize: 17, height: 1.45)),
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
                    color: Colors.white70,
                    fontSize: 20,
                    letterSpacing: 2),
              ),
              const SizedBox(height: 24),
              _DirButton(
                  direccion: 1, onPressed: () => onDireccion(1)),
              const SizedBox(height: _btnSize),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _DirButton(
                      direccion: 3, onPressed: () => onDireccion(3)),
                  const SizedBox(width: _btnSize * 2),
                  _DirButton(
                      direccion: 4, onPressed: () => onDireccion(4)),
                ],
              ),
              const SizedBox(height: _btnSize),
              _DirButton(
                  direccion: 2, onPressed: () => onDireccion(2)),
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
              key: ValueKey(
                  '$mensajePrincipal$mensajeCreatura'),
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
                    const Divider(
                        color: Colors.white12, height: 1),
                    const SizedBox(height: 10),
                    Text(
                      mensajeCreatura!,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        height: 1.45,
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

// ── Animación de dado ────────────────────────────────────────

class _ForzarDialog extends StatefulWidget {
  final MovimientoResultado resultado;
  const _ForzarDialog({required this.resultado});

  @override
  State<_ForzarDialog> createState() => _ForzarDialogState();
}

class _ForzarDialogState extends State<_ForzarDialog> {
  Timer? _rollTimer;
  int _caraVisible = 1;
  bool _terminado = false;

  static const _caras = ['⚀', '⚁', '⚂', '⚃', '⚄', '⚅'];

  @override
  void initState() {
    super.initState();
    _iniciarAnimacion();
  }

  @override
  void dispose() {
    _rollTimer?.cancel();
    super.dispose();
  }

  void _iniciarAnimacion() {
    final inicio = DateTime.now();

    _rollTimer = Timer.periodic(
        const Duration(milliseconds: 110), (timer) {
      if (!mounted) return;

      final ms = DateTime.now().difference(inicio).inMilliseconds;
      if (ms >= 3000) {
        _mostrarResultadoFinal();
        return;
      }

      setState(() {
        _caraVisible =
            (DateTime.now().microsecondsSinceEpoch % 6) + 1;
      });
    });
  }

  void _mostrarResultadoFinal() {
    _rollTimer?.cancel();
    if (!mounted) return;

    final tirada = widget.resultado.tirada ?? 1;
    final caraFinal = ((tirada - 1) % 6) + 1;

    setState(() {
      _caraVisible = caraFinal;
      _terminado = true;
    });
  }

  void _saltar() {
    if (_terminado) return;
    _mostrarResultadoFinal();
  }

  @override
  Widget build(BuildContext context) {
    final exito = widget.resultado.puertaForzada;
    final prob = widget.resultado.probabilidad ?? 0;
    final tirada = widget.resultado.tirada ?? 0;
    final caraStr = _caras[(_caraVisible - 1).clamp(0, 5)];
    final colorResultado =
    exito ? Colors.greenAccent : Colors.redAccent;

    return GestureDetector(
      onTap: _saltar,
      child: Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 22),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.93),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                      width: 3,
                      height: 16,
                      color: _terminado
                          ? colorResultado.withOpacity(0.6)
                          : Colors.white24,
                      margin: const EdgeInsets.only(right: 10)),
                  Text(
                    _terminado
                        ? (exito
                        ? 'CERRADURA FORZADA'
                        : 'CERRADURA INTACTA')
                        : 'FORZANDO CERRADURA',
                    style: TextStyle(
                      color:
                      _terminado ? colorResultado : Colors.white,
                      fontSize: 13,
                      letterSpacing: 3,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Divider(color: Colors.white12, height: 1),
              const SizedBox(height: 24),
              AnimatedScale(
                scale: _terminado ? 1.0 : 1.06,
                duration: const Duration(milliseconds: 110),
                child: Text(
                  caraStr,
                  style: TextStyle(
                    fontSize: 72,
                    color: _terminado ? colorResultado : Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Probabilidad: $prob%',
                style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 12,
                    letterSpacing: 1),
              ),
              const SizedBox(height: 8),
              if (_terminado)
                Text(
                  '${exito ? "ÉXITO" : "FALLIDO"}',
                  style: TextStyle(
                    color: colorResultado,
                    fontSize: 14,
                    letterSpacing: 2,
                    fontWeight: FontWeight.bold,
                  ),
                )
              else
                const Text(
                  'TOCA PARA SALTAR',
                  style: TextStyle(
                      color: Colors.white24,
                      fontSize: 11,
                      letterSpacing: 2),
                ),
              const SizedBox(height: 24),
              if (_terminado)
                Align(
                  alignment: Alignment.centerRight,
                  child: _BotonDialog(
                    texto: 'CONTINUAR',
                    onTap: () => Navigator.pop(context),
                    destacado: exito,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Silueta del monstruo ─────────────────────────────────────

class _MonsterSilhouette extends StatelessWidget {
  const _MonsterSilhouette();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      height: 340,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Halo rojo difuso detrás
          Container(
            width: 220,
            height: 340,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black45.withOpacity(0.22),
                  blurRadius: 40,
                  spreadRadius: 10,
                ),
              ],
            ),
          ),

          // Imagen principal
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              'assets/images/chica_cubex.png',
              width: 220,
              height: 340,
              fit: BoxFit.cover,
            ),
          ),

          // Viñeta oscura en los bordes para integrarlo con el fondo
          Container(
            width: 220,
            height: 340,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.25),
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black.withOpacity(0.55),
                ],
                stops: const [0.0, 0.15, 0.7, 1.0],
              ),
            ),
          ),

          // Texto "AHUYENTAR" en la parte inferior
          Positioned(
            bottom: 10,
            child: Text(
              'AHUYENTAR',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                letterSpacing: 3,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                shadows: [
                  Shadow(
                    color: Colors.black.withOpacity(0.8),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Overlay de huida ─────────────────────────────────────────

class _HuidaOverlay extends StatelessWidget {
  final String titulo;
  final String texto;
  final String subtitulo;

  const _HuidaOverlay({
    required this.titulo,
    required this.texto,
    required this.subtitulo,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.96),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 2,
                  color: Colors.white24,
                  margin: const EdgeInsets.only(bottom: 28),
                ),
                Text(
                  titulo,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Airlock',
                    color: Colors.white,
                    fontSize: 48,
                    height: 1.08,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  texto,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.55),
                    fontSize: 15,
                    height: 1.75,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 42),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                        width: 24, height: 1, color: Colors.white12),
                    const SizedBox(width: 12),
                    Text(
                      subtitulo,
                      style: TextStyle(
                        fontFamily: 'Airlock',
                        color: Colors.white.withOpacity(0.28),
                        fontSize: 11,
                        letterSpacing: 4,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                        width: 24, height: 1, color: Colors.white12),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}