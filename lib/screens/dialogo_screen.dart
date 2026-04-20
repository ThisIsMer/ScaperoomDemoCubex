import 'package:flutter/material.dart';

class _DialogEntry {
  final String texto;
  final String? hablante;
  final String? nuevoFondo;
  const _DialogEntry(this.texto, {this.hablante, this.nuevoFondo});
}

const _dialogo = [
  _DialogEntry(
    'Despiertas en una oscuridad espesa, solo, con la sensación de que este lugar no se parece a nada que recuerdes.',
    nuevoFondo: 'assets/images/PortadaSinTexto.png',
  ),
  _DialogEntry('No sabes cómo has llegado aquí, ni siquiera podrías decir si estás bajo tierra, en un edificio abandonado o en algún lugar completamente distinto.'),
  _DialogEntry('A tu alrededor apenas distingues tres cosas: unos monitores parpadeando al fondo, un trozo de papel sobre la mesa con un lápiz al lado y varias puertas que parecen ser la única salida de la habitación.'),
  
  _DialogEntry(
    'Te acercas a los monitores y, al encenderlos, aparece ante ti la interfaz de lo que parecen ser cámaras de vigilancia repartidas por distintas salas.',
    nuevoFondo: 'assets/images/FondoCamaras.png',
  ),
  _DialogEntry('Si prestas atención, quizá esas imágenes puedan servirte para orientarte o para anticipar lo que te espera ahí fuera.'),

  _DialogEntry(
    'Aprovechas la hoja de papel y el lápiz que encuentras junto a ella para empezar a dibujar un pequeño mapa de lo que alcanzas a ver.',
    nuevoFondo: 'assets/images/MapaTuto.png',
  ),
  _DialogEntry('Todavía no sabes qué se oculta más allá de estas cuatro paredes, pero conforme vayas descubriendo nuevos rincones podrás ir añadiéndolos a tu improvisado croquis.'),

  _DialogEntry('De pronto, un ruido lejano, metálico y arrastrado, resuena en el silencio; sea lo que sea, se acerca, y más vale que te des prisa.',
    nuevoFondo: 'assets/images/PortadaSinTexto.png',
  ),
  _DialogEntry('No tienes tiempo que perder: en cuanto salgas de la sala de control no podrás volver, así que lo que no recuerdes ahora se perderá contigo ahí fuera.')
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
      duration: const Duration(milliseconds: 600),
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
              left: 32, right: 32, bottom: 40,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.75),
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
                          color: Colors.white, fontSize: 20, height: 1.5),
                    ),
                    const SizedBox(height: 12),
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