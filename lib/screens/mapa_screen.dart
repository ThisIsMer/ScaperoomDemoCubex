import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/game_controller.dart';

class MapaScreen extends StatelessWidget {
  const MapaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/FondoMapa.png', fit: BoxFit.cover),

          Column(
            children: [
              Container(
                color: Colors.black54,
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    TextButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back,
                          color: Colors.white70),
                      label: const Text('VOLVER',
                          style: TextStyle(
                              color: Colors.white70, letterSpacing: 2)),
                    ),
                    const SizedBox(width: 24),
                    const Text('MAPA',
                        style: TextStyle(
                            color: Colors.white70, letterSpacing: 4)),
                  ],
                ),
              ),

              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final cellW =
                        constraints.maxWidth * 0.90 / GameController.cols;

                    const imageRatio = 0.75;
                    final cellH = cellW * imageRatio;

                    final maxHFromScreen =
                        constraints.maxHeight * 0.85 / GameController.filas;
                    final finalH =
                    cellH < maxHFromScreen ? cellH : maxHFromScreen;
                    final finalW = finalH / imageRatio;

                    return Center(
                      child: Consumer<GameController>(
                        builder: (_, gc, __) => Transform.translate(
                          offset: const Offset(0, -25), // ← sube 25 unidades
                          child: _MapGrid(
                            gc:    gc,
                            cellW: finalW,
                            cellH: finalH,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  GRID
// ═══════════════════════════════════════════════════════════

class _MapGrid extends StatelessWidget {
  final GameController gc;
  final double cellW;
  final double cellH;

  const _MapGrid({
    required this.gc,
    required this.cellW,
    required this.cellH,
  });

  static String _imagenCasilla(int r, int c) {
    final idx = (r * GameController.cols + c) % 4 + 1;
    return 'assets/images/casilla$idx.png';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(GameController.filas, (r) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(GameController.cols, (c) {
            final hab         = gc.tablero[r][c];
            final esPosActual = gc.posAct[0] == r && gc.posAct[1] == c;
            final esOrigen    = r == 3 && c == 0;
            final esSalida    = r == 0 && c == 3;
            final visible     = hab.explorada || esOrigen;

            return visible
                ? _Celda(
              r:           r,
              c:           c,
              cellW:       cellW,
              cellH:       cellH,
              imgCasilla:  _imagenCasilla(r, c),
              esPosActual: esPosActual,
              esOrigen:    esOrigen,
              esSalida:    esSalida,
              bloqs:       hab.bloqsF,
            )
                : SizedBox(width: cellW, height: cellH);
          }),
        );
      }),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  CELDA VISIBLE
// ═══════════════════════════════════════════════════════════

class _Celda extends StatelessWidget {
  final int r, c;
  final double cellW;
  final double cellH;
  final String imgCasilla;
  final bool esPosActual;
  final bool esOrigen;
  final bool esSalida;
  final List<int> bloqs;

  const _Celda({
    required this.r,
    required this.c,
    required this.cellW,
    required this.cellH,
    required this.imgCasilla,
    required this.esPosActual,
    required this.esOrigen,
    required this.esSalida,
    required this.bloqs,
  });

  @override
  Widget build(BuildContext context) {
    final candadoSize = cellW * 0.40;
    final iconSize    = cellW * 0.55;

    return SizedBox(
      width:  cellW,
      height: cellH,
      child: Stack(
        clipBehavior: Clip.none,
        children: [

          // ── 1. Imagen de casilla escalada al 110% ──────
          Positioned.fill(
            child: Transform.scale(
              scale: 1.10,
              child: Image.asset(
                imgCasilla,
                fit: BoxFit.fill,
                errorBuilder: (_, __, ___) =>
                    Container(color: Colors.transparent),
              ),
            ),
          ),

          // ── 2. Icono de rol ────────────────────────────
          if (esPosActual)
            Positioned.fill(
              child: Center(
                child: Image.asset(
                  'assets/images/home.png',
                  width:  iconSize,
                  height: iconSize,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.person_pin,
                    color: Colors.lightBlueAccent,
                    size: iconSize,
                  ),
                ),
              ),
            )
          else if (esSalida)
            Positioned.fill(
              child: Center(
                child: Icon(Icons.exit_to_app,
                    color: Colors.white70, size: iconSize * 0.8),
              ),
            )
          else if (esOrigen)
              Positioned.fill(
                child: Center(
                  child: Icon(Icons.home,
                      color: Colors.greenAccent, size: iconSize * 0.8),
                ),
              ),

          // ── 3. Coordenada ──────────────────────────────
          Positioned(
            bottom: 2,
            right:  3,
            child: Text(
              '(${r + 1},${c + 1})',
              style: const TextStyle(
                  color: Colors.white38, fontSize: 8),
            ),
          ),

          // ── 4. Candados — capa superior ─────────────────
          ..._buildCandados(candadoSize),
        ],
      ),
    );
  }

  List<Widget> _buildCandados(double s) {
    final halfS = s / 2;

    Widget mk(double? top, double? bottom, double? left, double? right) {
      return Positioned(
        top: top, bottom: bottom, left: left, right: right,
        child: SizedBox(
          width: s, height: s,
          child: Image.asset(
            'assets/images/candado.png',
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) =>
                Icon(Icons.lock, color: Colors.redAccent, size: s * 0.8),
          ),
        ),
      );
    }

    return bloqs.map((dir) {
      switch (dir) {
        case 1: return mk(-halfS, null, cellW / 2 - halfS, null); // Arriba
        case 2: return mk(null, -halfS, cellW / 2 - halfS, null); // Abajo
        case 3: return mk(cellH / 2 - halfS, null, -halfS, null); // Izquierda
        case 4: return mk(cellH / 2 - halfS, null, null, -halfS); // Derecha
        default: return const SizedBox.shrink();
      }
    }).toList();
  }
}