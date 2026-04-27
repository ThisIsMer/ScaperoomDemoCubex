import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/habitacion.dart';

class MovimientoResultado {
  final String tipo; // pared | bloqueada | avanzar | salida | encuentro_monstruo
  final bool monstruoCerca;
  final bool encuentroMonstruo;
  final bool puertaForzada;
  final int? probabilidad;
  final int? tirada;

  const MovimientoResultado({
    required this.tipo,
    this.monstruoCerca = false,
    this.encuentroMonstruo = false,
    this.puertaForzada = false,
    this.probabilidad,
    this.tirada,
  });
}

class GameController extends ChangeNotifier {
  static const int filas = 4;
  static const int cols = 4;
  static const int maxErrores = 5;
  static const int maxIntentosForzar = 3;

  final Random _rng = Random();

  int portadasCount = 0;
  bool introMostrada = false;
  int erroresRonda = 0;
  int intentosForzar = 0;
  bool puertaForzadaEnIntento = false;

  List<int> posAct = [3, 0];
  List<int> posMonstruo = [0, 0];

  late List<List<Habitacion>> tablero;
  bool tableroIniciado = false;

  int get intentosForzarRestantes => maxIntentosForzar - intentosForzar;

  int get probabilidadActualForzar {
    final valor = 25 - (erroresRonda * 5) + (intentosForzar * 20);
    if (valor < 0) return 0;
    if (valor > 100) return 100;
    return valor;
  }

  void iniciarTablero() {
    portadasCount++;
    posAct = [3, 0];
    posMonstruo = [0, 0];
    erroresRonda = 0;
    intentosForzar = 0;
    puertaForzadaEnIntento = false;

    tablero = List.generate(
      filas,
          (_) => List.generate(cols, (_) => Habitacion()),
    );

    _poblarTablero();
    _asignarFondos();
    tableroIniciado = true;
    notifyListeners();
  }

  void _asignarFondos() {
    final imagenes = List.generate(
      10,
          (i) => 'assets/images/Recorrido${i + 1}.png',
    );

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
          ..shuffle(_rng);

        tablero[r][c].fondo = disponibles.first;
      }
    }
  }

  void _poblarTablero() {
    for (int f = 0; f < filas; f++) {
      for (int c = 0; c < cols; c++) {
        tablero[f][c] = Habitacion(
          posDir: [],
          puertasBloqueadas: [],
        );
      }
    }

    tablero[3][0] = Habitacion(posDir: [1, 2], explorada: true);
    tablero[2][0] = Habitacion(posDir: [1, 2, 4]);
    tablero[1][0] = Habitacion(posDir: [2]);

    tablero[2][1] = Habitacion(
      posDir: [3],
      puertasBloqueadas: [1, 4],
    );

    tablero[1][1] = Habitacion(posDir: [1, 2]);
    tablero[0][1] = Habitacion(posDir: [2, 4]);
    tablero[0][2] = Habitacion(posDir: [3, 4]);

    tablero[2][2] = Habitacion(posDir: [3, 2]);
    tablero[3][2] = Habitacion(posDir: [1, 4]);
    tablero[3][3] = Habitacion(posDir: [3, 1]);
    tablero[2][3] = Habitacion(posDir: [2, 1]);
    tablero[1][3] = Habitacion(posDir: [2, 1]);

    tablero[0][3] = Habitacion(posDir: []);
  }

  String clasificarDireccion(int direccion) {
    const deltas = {
      1: [-1, 0],
      2: [1, 0],
      3: [0, -1],
      4: [0, 1],
    };

    final d = deltas[direccion];
    if (d == null) return 'pared';

    final nFila = posAct[0] + d[0];
    final nCol = posAct[1] + d[1];

    if (nFila < 0 || nFila >= filas || nCol < 0 || nCol >= cols) {
      return 'pared';
    }

    final habitActual = tablero[posAct[0]][posAct[1]];

    if (habitActual.posDir.contains(direccion)) return 'abierta';
    if (habitActual.puertasBloqueadas.contains(direccion)) return 'puerta_bloqueada';
    return 'pared';
  }

  MovimientoResultado moverHacia(int direccion) {
    final tipo = clasificarDireccion(direccion);

    if (tipo == 'pared') {
      erroresRonda++;
      notifyListeners();
      return const MovimientoResultado(tipo: 'pared');
    }

    if (tipo == 'puerta_bloqueada') {
      return const MovimientoResultado(tipo: 'bloqueada');
    }

    return _completarMovimiento(direccion);
  }

  MovimientoResultado rechazarPuerta(int direccion) {
    final habitActual = tablero[posAct[0]][posAct[1]];

    if (!habitActual.bloqsF.contains(direccion)) {
      habitActual.bloqsF.add(direccion);
    }

    erroresRonda++;
    _desbloquearRutaRescateSiHaceFalta();
    notifyListeners();

    return const MovimientoResultado(tipo: 'bloqueada');
  }

  MovimientoResultado intentarForzarPuerta(int direccion) {
    if (clasificarDireccion(direccion) != 'puerta_bloqueada') {
      return moverHacia(direccion);
    }

    final habitActual = tablero[posAct[0]][posAct[1]];

    if (intentosForzar >= maxIntentosForzar) {
      return rechazarPuerta(direccion);
    }

    final probabilidad = probabilidadActualForzar;
    intentosForzar++;

    final tirada = _rng.nextInt(100) + 1;
    final exito = tirada <= probabilidad;

    if (exito) {
      habitActual.puertasBloqueadas.remove(direccion);
      if (!habitActual.posDir.contains(direccion)) {
        habitActual.posDir.add(direccion);
      }
      puertaForzadaEnIntento = true;
      return _completarMovimiento(
        direccion,
        puertaForzada: true,
        probabilidad: probabilidad,
        tirada: tirada,
      );
    }

    if (!habitActual.bloqsF.contains(direccion)) {
      habitActual.bloqsF.add(direccion);
    }

    erroresRonda++;
    _desbloquearRutaRescateSiHaceFalta();
    notifyListeners();

    return MovimientoResultado(
      tipo: 'bloqueada',
      probabilidad: probabilidad,
      tirada: tirada,
    );
  }

  MovimientoResultado _completarMovimiento(
      int direccion, {
        bool puertaForzada = false,
        int? probabilidad,
        int? tirada,
      }) {
    const deltas = {
      1: [-1, 0],
      2: [1, 0],
      3: [0, -1],
      4: [0, 1],
    };

    final d = deltas[direccion]!;
    final nFila = posAct[0] + d[0];
    final nCol = posAct[1] + d[1];

    posAct = [nFila, nCol];
    tablero[nFila][nCol].explorada = true;

    _moverMonstruo();

    final encuentro = posAct[0] == posMonstruo[0] && posAct[1] == posMonstruo[1];
    final cerca = _esAdyacente(posAct, posMonstruo);

    notifyListeners();

    if (encuentro) {
      return MovimientoResultado(
        tipo: 'encuentro_monstruo',
        encuentroMonstruo: true,
        puertaForzada: puertaForzada,
        probabilidad: probabilidad,
        tirada: tirada,
      );
    }

    if (nFila == 0 && nCol == 3) {
      return MovimientoResultado(
        tipo: 'salida',
        puertaForzada: puertaForzada,
        probabilidad: probabilidad,
        tirada: tirada,
      );
    }

    return MovimientoResultado(
      tipo: 'avanzar',
      monstruoCerca: cerca,
      puertaForzada: puertaForzada,
      probabilidad: probabilidad,
      tirada: tirada,
    );
  }

  void _moverMonstruo() {
    const opciones = {
      1: [-1, 0],
      2: [1, 0],
      3: [0, -1],
      4: [0, 1],
    };

    final movimientosValidos = <List<int>>[];

    for (final delta in opciones.values) {
      final nf = posMonstruo[0] + delta[0];
      final nc = posMonstruo[1] + delta[1];

      if (nf >= 0 && nf < filas && nc >= 0 && nc < cols) {
        movimientosValidos.add([nf, nc]);
      }
    }

    if (movimientosValidos.isEmpty) return;

    posMonstruo = movimientosValidos[_rng.nextInt(movimientosValidos.length)];
  }

  bool _esAdyacente(List<int> a, List<int> b) {
    final dr = (a[0] - b[0]).abs();
    final dc = (a[1] - b[1]).abs();
    return dr + dc == 1;
  }

  void ahuyentarMonstruo() {
    final seguras = <List<int>>[];
    final validas = <List<int>>[];

    for (int r = 0; r < filas; r++) {
      for (int c = 0; c < cols; c++) {
        if (r == posAct[0] && c == posAct[1]) continue;

        final celda = [r, c];
        validas.add(celda);

        if (!_esAdyacente(celda, posAct)) {
          seguras.add(celda);
        }
      }
    }

    final pool = seguras.isNotEmpty ? seguras : validas;
    posMonstruo = pool[_rng.nextInt(pool.length)];
    notifyListeners();
  }

  void _desbloquearRutaRescateSiHaceFalta() {
    if (intentosForzar < maxIntentosForzar) return;
    if (puertaForzadaEnIntento) return;

    final habitCambio = tablero[2][1];
    final direccionRescate = portadasCount.isOdd ? 4 : 1;

    habitCambio.puertasBloqueadas.remove(direccionRescate);
    if (!habitCambio.posDir.contains(direccionRescate)) {
      habitCambio.posDir.add(direccionRescate);
    }
  }

  void resetRecorrido() {
    posAct = [3, 0];
    posMonstruo = [0, 0];
    erroresRonda = 0;
    intentosForzar = 0;
    puertaForzadaEnIntento = false;
    notifyListeners();
  }

  void resetJuego() {
    posAct = [3, 0];
    posMonstruo = [0, 0];
    erroresRonda = 0;
    intentosForzar = 0;
    puertaForzadaEnIntento = false;
    tableroIniciado = false;
    introMostrada = false;
    notifyListeners();
  }

  String get posActTexto => '(${posAct[0] + 1}, ${posAct[1] + 1})';
  bool get enSalidaCamara => posAct[0] == 1 && posAct[1] == 0;
}