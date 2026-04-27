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
    final estado = gc.clasificarDireccion(dir);

    if (estado == 'puerta_bloqueada') {
      await _gestionarPuertaBloqueada(context, dir);
      return;
    }

    final resultado = gc.moverHacia(dir);
    await _procesarResultado(context, resultado);
  }

  Future<void> _gestionarPuertaBloqueada(BuildContext context, int dir) async {
    final gc = context.read<GameController>();

    if (gc.intentosForzarRestantes <= 0) {
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text(
            'Puerta bloqueada',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'No te quedan intentos para forzar cerraduras.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Seguir'),
            ),
          ],
        ),
      );

      if (!mounted) return;
      final resultado = gc.rechazarPuerta(dir);
      await _procesarResultado(context, resultado);
      return;
    }

    final usarFuerza = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Puerta bloqueada',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          '¿Quieres intentar forzarla?\n\n'
              'Probabilidad actual: ${gc.probabilidadActualForzar}%\n'
              'Intentos restantes: ${gc.intentosForzarRestantes}',
          style: const TextStyle(color: Colors.white70, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Sí',
              style: TextStyle(color: Colors.amberAccent),
            ),
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (usarFuerza != true) {
      final resultado = gc.rechazarPuerta(dir);
      await _procesarResultado(context, resultado);
      return;
    }

    final resultado = gc.intentarForzarPuerta(dir);

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ForzarDialog(resultado: resultado),
    );

    if (!mounted) return;
    await _procesarResultado(context, resultado);
  }

  Future<void> _procesarResultado(
      BuildContext context,
      MovimientoResultado resultado,
      ) async {
    final gc = context.read<GameController>();

    if (resultado.tipo == 'salida') {
      setState(() {
        _fondoActual = gc.tablero[gc.posAct[0]][gc.posAct[1]].fondo;
        _fadeToBlack = true;
      });

      await Future.delayed(const Duration(milliseconds: 1200));
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/salida');
      }
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
        creatura: resultado.monstruoCerca
            ? 'Algo se siente amenazadoramente cerca.'
            : null,
      );
      return;
    }

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
        ? 'Es una pared.'
        : 'La puerta no cede.';

    final idx = (errores - 1).clamp(0, _mensajesCreatura.length - 1);

    _mostrarMensajeTemporal(
      textoMovimiento,
      creatura: _mensajesCreatura[idx],
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
      'Consigues apartarlo a tiempo.',
      creatura: null,
      segundos: 2,
    );
  }

  Future<bool> _onWillPop(BuildContext context) async {
    if (_bloqueado) return false;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          '¿Volver?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Tendrás que recorrerlo otra vez desde el inicio.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Volver',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      context.read<GameController>().resetRecorrido();
    }

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
                Container(
                  color: Colors.black54,
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      TextButton.icon(
                        onPressed: () async {
                          final salir = await _onWillPop(context);
                          if (salir && context.mounted) Navigator.pop(context);
                        },
                        icon: const Icon(
                          Icons.arrow_back,
                          color: Colors.white70,
                        ),
                        label: const Text(
                          'VOLVER',
                          style: TextStyle(
                            color: Colors.white70,
                            letterSpacing: 2,
                          ),
                        ),
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

class _ForceIndicator extends StatelessWidget {
  final int usados;
  final int maximos;

  const _ForceIndicator({
    required this.usados,
    required this.maximos,
  });

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
            color: usado ? Colors.amber.withOpacity(0.85) : Colors.white24,
          ),
        );
      }),
    );
  }
}

class _ErrorIndicator extends StatelessWidget {
  final int errores;
  final int maxErrores;

  const _ErrorIndicator({
    required this.errores,
    required this.maxErrores,
  });

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
                blurRadius: 6,
              ),
            ]
                : null,
          ),
        );
      }),
    );
  }
}

class _DirButton extends StatelessWidget {
  final int direccion;
  final VoidCallback onPressed;

  const _DirButton({
    required this.direccion,
    required this.onPressed,
  });

  static const _datos = {
    1: '○',
    2: '□',
    3: '△',
    4: '✕',
  };

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
          child: Text(
            simbolo,
            style: const TextStyle(color: Colors.white, fontSize: 30),
          ),
        ),
      ),
    );
  }
}

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
        child: Text(
          texto,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            height: 1.45,
          ),
        ),
      ),
    );
  }
}

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
                  letterSpacing: 2,
                ),
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
                horizontal: 20,
                vertical: 14,
              ),
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
                      height: 1.4,
                    ),
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

class _ForzarDialog extends StatefulWidget {
  final MovimientoResultado resultado;

  const _ForzarDialog({required this.resultado});

  @override
  State<_ForzarDialog> createState() => _ForzarDialogState();
}

class _ForzarDialogState extends State<_ForzarDialog> {
  bool _mostrarNumero = false;
  bool _mostrarBoton = false;

  @override
  void initState() {
    super.initState();

    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      setState(() => _mostrarNumero = true);
    });

    Future.delayed(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      setState(() => _mostrarBoton = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final exito = widget.resultado.puertaForzada;
    final prob = widget.resultado.probabilidad ?? 0;
    final tirada = widget.resultado.tirada ?? 0;

    return AlertDialog(
      backgroundColor: Colors.grey[900],
      title: Text(
        exito ? 'La cerradura cede' : 'La cerradura resiste',
        style: const TextStyle(color: Colors.white),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.casino, color: Colors.amberAccent, size: 42),
          const SizedBox(height: 12),
          Text(
            'Probabilidad: $prob%',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 8),
          AnimatedOpacity(
            opacity: _mostrarNumero ? 1 : 0,
            duration: const Duration(milliseconds: 250),
            child: Text(
              'Tirada: $tirada',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      actions: [
        if (_mostrarBoton)
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Continuar'),
          ),
      ],
    );
  }
}

class _MonsterSilhouette extends StatelessWidget {
  const _MonsterSilhouette();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 170,
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 150,
            height: 200,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.9),
              borderRadius: BorderRadius.circular(90),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.18),
                  blurRadius: 26,
                  spreadRadius: 6,
                ),
              ],
            ),
          ),
          Positioned(
            top: 78,
            left: 50,
            child: Container(
              width: 18,
              height: 10,
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.9),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          Positioned(
            top: 78,
            right: 50,
            child: Container(
              width: 18,
              height: 10,
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.9),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          Positioned(
            bottom: 8,
            child: Text(
              'TÓCALO',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                letterSpacing: 3,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
                    Container(width: 24, height: 1, color: Colors.white12),
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
                    Container(width: 24, height: 1, color: Colors.white12),
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