import 'package:flutter/material.dart';

class _DialogEntry {
  final String texto;
  final String? hablante;
  final String? nuevoFondo;
  const _DialogEntry(this.texto, {this.hablante, this.nuevoFondo});
}

const _dialogo = [
  _DialogEntry(
    'Despiertas solo en una sala oscura.',
    nuevoFondo: 'assets/images/PortadaSinTexto.png',
  ),
  _DialogEntry(
    'Ves monitores, una hoja y varias puertas.',
  ),
  _DialogEntry(
    'Las cámaras enseñan otras salas. Te servirán para orientarte.',
    nuevoFondo: 'assets/images/FondoCamaras.png',
  ),
  _DialogEntry(
    'Con el papel puedes ir trazando un mapa.',
    nuevoFondo: 'assets/images/MapaTuto.png',
  ),
  _DialogEntry(
    'A lo lejos se oye algo arrastrarse.',
    nuevoFondo: 'assets/images/PortadaSinTexto.png',
  ),
  _DialogEntry(
    'Cuando salgas de la sala de control, ya no podrás volver. Memoriza lo necesario y muévete.',
  ),
];

class DialogoScreen extends StatefulWidget {
  const DialogoScreen({super.key});

  @override
  State<DialogoScreen> createState() => _DialogoScreenState();
}

class _DialogoScreenState extends State<DialogoScreen>
    with SingleTickerProviderStateMixin {
  int _idx = 0;
  String? _fondoActual;
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
      value: 1.0,
    );
    _fadeAnim = _fadeCtrl.drive(Tween(begin: 0.0, end: 1.0));
    _fondoActual = _dialogo[0].nuevoFondo;
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _avanzar() {
    if (_idx >= _dialogo.length - 1) {
      Navigator.pushReplacementNamed(context, '/menu');
      return;
    }

    final siguiente = _dialogo[_idx + 1];

    if (siguiente.nuevoFondo != null) {
      _fadeCtrl.reverse().then((_) {
        if (!mounted) return;
        setState(() {
          _idx++;
          _fondoActual = siguiente.nuevoFondo;
        });
        _fadeCtrl.forward();
      });
    } else {
      setState(() => _idx++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final entrada = _dialogo[_idx];

    return Scaffold(
      body: GestureDetector(
        onTap: _avanzar,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          fit: StackFit.expand,
          children: [
            FadeTransition(
              opacity: _fadeAnim,
              child: _fondoActual != null
                  ? Image.asset(_fondoActual!, fit: BoxFit.cover)
                  : Container(color: Colors.black87),
            ),
            Positioned(
              left: 28,
              right: 28,
              bottom: 34,
              child: Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.78),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (entrada.hablante != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          entrada.hablante!,
                          style: const TextStyle(
                            color: Colors.amberAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            letterSpacing: 3,
                          ),
                        ),
                      ),
                    Text(
                      entrada.texto,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}