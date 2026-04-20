import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/game_controller.dart';

class SalidaScreen extends StatefulWidget {
  const SalidaScreen({super.key});

  @override
  State<SalidaScreen> createState() => _SalidaScreenState();
}

class _SalidaScreenState extends State<SalidaScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeCtrl;
  late final Animation<double> _overlayOpacity;
  late final bool _esImpar;

  int _dialogIdx = 0;
  bool _mostrarPista = false;

  static const _mensajes = [
    'Empiezas a oír pasos desacompasados y golpes que se aproximan cada vez más rápido por la habitación que acabas de dejar atrás.',
    'Cierras la puerta con torpeza, la atrancas con lo primero que encuentras y escuchas, al otro lado, una serie de arañazos desesperados que parecen durar una eternidad antes de desvanecerse por completo.',
    'Respiras hondo y, todavía con las manos temblando, echas un vistazo a la sala: hay algo en ella que la hace distinta a todas las que has atravesado hasta ahora.',
    'Sobre la mesa, cuidadosamente colocado, descubres un nuevo trozo de papel con las siguientes palabras escritas en él.',
  ];

  @override
  void initState() {
    super.initState();
    _esImpar = context.read<GameController>().portadasCount % 2 != 0;
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _overlayOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut),
    );
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _avanzarDialogo() {
    if (_dialogIdx < _mensajes.length - 1) {
      setState(() => _dialogIdx++);
    } else {
      setState(() => _mostrarPista = true);
    }
  }

  void _continuar(BuildContext context) {
    context.read<GameController>().resetJuego();
    Navigator.pushReplacementNamed(context, '/portada');
  }

  @override
  Widget build(BuildContext context) {
    final imagenPista = _esImpar
        ? 'assets/images/pista1.png'
        : 'assets/images/pista2.png';

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Imagen de fondo al 60% ───────────────────────
          Opacity(
            opacity: 0.60,
            child: Image.asset(
              'assets/images/FondoFinal.png',
              fit: BoxFit.cover,
            ),
          ),

          // ── Contenido ────────────────────────────────────
          if (!_mostrarPista)
            Positioned(
              left: 32,
              right: 32,
              bottom: 40,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _mensajes[_dialogIdx],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            )
          else
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ── Pista: 80% del alto, sin contorno ───────
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.80,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        imagenPista,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),

                // ── Aviso antes del botón ────────────────────
                const Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: 32, vertical: 10),
                  child: Text(
                    'Una vez le des a continuar no podrás volver, '
                        'asegúrate de recordar bien la pista (o saca una foto)',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 20,
                      height: 1.5,
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 32),
                  child: ElevatedButton(
                    onPressed: () => _continuar(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white10,
                      foregroundColor: Colors.white,
                      side: const BorderSide(
                          color: Colors.white54, width: 1),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 56, vertical: 18),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text(
                      'CONTINUAR',
                      style: TextStyle(letterSpacing: 4, fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),

          // ── GestureDetector SOLO durante el diálogo ──────
          if (!_mostrarPista)
            Positioned.fill(
              child: GestureDetector(
                onTap: _avanzarDialogo,
                behavior: HitTestBehavior.opaque,
                child: Container(color: Colors.transparent),
              ),
            ),

          // ── Fade de entrada ───────────────────────────────
          IgnorePointer(
            child: AnimatedBuilder(
              animation: _overlayOpacity,
              builder: (_, __) => Container(
                color: Colors.black.withOpacity(_overlayOpacity.value),
              ),
            ),
          ),
        ],
      ),
    );
  }
}