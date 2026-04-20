import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/habitacion.dart';

class GameController extends ChangeNotifier {
  static const int filas      = 4;
  static const int cols       = 4;
  static const int maxErrores = 5; // ← intentos antes de la expulsión

  int  portadasCount  = 0;
  bool introMostrada  = false;
  int  erroresRonda   = 0; // ← contador de confusiones por intento

  List<int> posAct = [3, 0];
  late List<List<Habitacion>> tablero;
  bool tableroIniciado = false;

  void iniciarTablero() {
    portadasCount++;
    posAct       = [3, 0];
    erroresRonda = 0;
    tablero = List.generate(
      filas, (_) => List.generate(cols, (_) => Habitacion()),
    );
    _poblarTablero();
    _asignarFondos();
    tableroIniciado = true;
    notifyListeners();
  }

  void _asignarFondos() {
    final rng     = Random();
    final imagenes = List.generate(10, (i) => 'assets/images/Recorrido${i + 1}.png');

    for (int r = 0; r < filas; r++) {
      for (int c = 0; c < cols; c++) {
        if (r == 3 && c == 0) {
          tablero[r][c].fondo = 'assets/images/PortadaSinTexto.png';
          continue;
        }
        final usados = <String>{};
        if (r > 0) usados.add(tablero[r - 1][c].fondo);
        if (c > 0) usados.add(tablero[r][c - 1].fondo);
        final disponibles = imagenes.where((img) => !usados.contains(img)).toList()
          ..shuffle(rng);
        tablero[r][c].fondo = disponibles.first;
      }
    }
  }

  void _poblarTablero() {
    for (int f = 0; f < filas; f++) {
      for (int c = 0; c < cols; c++) {
        tablero[f][c] = Habitacion(posDir: []);
      }
    }

    final esImpar = portadasCount % 2 != 0;

    tablero[3][0] = Habitacion(posDir: [1], explorada: true);
    tablero[2][0] = Habitacion(posDir: [1, 4]);
    tablero[1][0] = Habitacion(posDir: [2]);

    tablero[2][1] = esImpar
        ? Habitacion(posDir: [3, 4])
        : Habitacion(posDir: [3, 1]);

    if (!esImpar) {
      tablero[1][1] = Habitacion(posDir: [1, 2]);
      tablero[0][1] = Habitacion(posDir: [2, 4]);
      tablero[0][2] = Habitacion(posDir: [3, 4]);
    } else {
      tablero[2][2] = Habitacion(posDir: [3, 2]);
      tablero[3][2] = Habitacion(posDir: [1, 4]);
      tablero[3][3] = Habitacion(posDir: [3, 1]);
      tablero[2][3] = Habitacion(posDir: [2, 1]);
      tablero[1][3] = Habitacion(posDir: [2, 1]);
    }

    tablero[0][3] = Habitacion(posDir: []);
  }

  /// Devuelve: 'pared' | 'bloqueada' | 'avanzar' | 'salida'
  String moverHacia(int direccion) {
    const deltas = {1: [-1, 0], 2: [1, 0], 3: [0, -1], 4: [0, 1]};
    final d = deltas[direccion];
    if (d == null) return 'bloqueada';

    final nFila = posAct[0] + d[0];
    final nCol  = posAct[1] + d[1];

    if (nFila < 0 || nFila >= filas || nCol < 0 || nCol >= cols) {
      erroresRonda++; // ← cuenta como confusión
      notifyListeners();
      return 'pared';
    }

    final habitActual = tablero[posAct[0]][posAct[1]];
    if (!habitActual.posDir.contains(direccion)) {
      if (!habitActual.bloqsF.contains(direccion) && habitActual.bloqsF.length < 2) {
        habitActual.bloqsF.add(direccion);
      }
      erroresRonda++; // ← cuenta como confusión
      notifyListeners();
      return 'bloqueada';
    }

    posAct = [nFila, nCol];
    tablero[nFila][nCol].explorada = true;
    notifyListeners();

    if (nFila == 0 && nCol == 3) return 'salida';
    return 'avanzar';
  }

  /// Reinicia posición y errores pero MANTIENE habitaciones exploradas
  void resetRecorrido() {
    posAct       = [3, 0];
    erroresRonda = 0;
    notifyListeners();
  }

  void resetJuego() {
    posAct          = [3, 0];
    erroresRonda    = 0;
    tableroIniciado = false;
    introMostrada   = false;
    notifyListeners();
  }

  String get posActTexto => '(${posAct[0] + 1}, ${posAct[1] + 1})';
  bool get enSalidaCamara => posAct[0] == 1 && posAct[1] == 0;
}